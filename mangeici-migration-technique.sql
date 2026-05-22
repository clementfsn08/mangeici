-- ================================================
-- MANGEICI — Migration complète volet technique
-- Exécuter dans Supabase > SQL Editor
-- ================================================

-- ══════════════════════════════════════════
-- 1. ACTIVER pg_cron (downgrade automatique)
-- ══════════════════════════════════════════
-- Active l'extension pg_cron (si pas encore fait)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Cron job : downgrade automatique chaque nuit à 2h UTC
SELECT cron.schedule(
  'mangeici-downgrade-check',
  '0 2 * * *',  -- chaque nuit à 2h UTC (3h heure Bénin)
  'SELECT check_expired_subscriptions();'
);

-- Cron job : rappel renouvellement chaque matin à 8h UTC
-- (liste les restos à rappeler — tu traites côté email)
SELECT cron.schedule(
  'mangeici-rappel-renouvellement',
  '0 8 * * *',
  $$
  UPDATE restaurants
  SET rappel_envoye = true
  WHERE id IN (
    SELECT id FROM get_restaurants_to_remind()
  );
  $$
);

-- ══════════════════════════════════════════
-- 2. RECHERCHE TEXTUELLE (full-text search)
-- ══════════════════════════════════════════

-- Ajouter colonne de recherche dénormalisée
ALTER TABLE restaurants
ADD COLUMN IF NOT EXISTS search_vector TSVECTOR;

-- Fonction pour mettre à jour le vecteur de recherche
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
  NEW.search_vector = to_tsvector('french',
    coalesce(NEW.nom, '') || ' ' ||
    coalesce(NEW.zone, '') || ' ' ||
    coalesce(NEW.description, '') || ' ' ||
    coalesce(array_to_string(NEW.cuisine, ' '), '') || ' ' ||
    coalesce(array_to_string(NEW.ambiances, ' '), '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sur INSERT et UPDATE
DROP TRIGGER IF EXISTS trig_search_vector ON restaurants;
CREATE TRIGGER trig_search_vector
  BEFORE INSERT OR UPDATE ON restaurants
  FOR EACH ROW EXECUTE FUNCTION update_search_vector();

-- Index pour la recherche rapide
CREATE INDEX IF NOT EXISTS idx_restaurants_search
ON restaurants USING GIN(search_vector);

-- Mettre à jour tous les restos existants
UPDATE restaurants SET search_vector = to_tsvector('french',
  coalesce(nom, '') || ' ' ||
  coalesce(zone, '') || ' ' ||
  coalesce(description, '') || ' ' ||
  coalesce(array_to_string(cuisine, ' '), '') || ' ' ||
  coalesce(array_to_string(ambiances, ' '), '')
);

-- Fonction de recherche
CREATE OR REPLACE FUNCTION search_restaurants(query TEXT)
RETURNS SETOF restaurants AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM restaurants
  WHERE
    statut = 'actif'
    AND visible = true
    AND search_vector @@ plainto_tsquery('french', query)
  ORDER BY
    ts_rank(search_vector, plainto_tsquery('french', query)) DESC,
    (CASE plan WHEN 'premium' THEN 0 WHEN 'pro' THEN 1 WHEN 'starter' THEN 2 ELSE 3 END);
END;
$$ LANGUAGE plpgsql;

-- ══════════════════════════════════════════
-- 3. TABLE FAVORIS CLIENTS
-- ══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS favoris (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  client_id     UUID NOT NULL,    -- ID du compte client
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  UNIQUE(client_id, restaurant_id)
);
ALTER TABLE favoris DISABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════
-- 4. TABLE COMPTES CLIENTS (visiteurs)
-- ══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS clients (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  auth_user_id  UUID UNIQUE,
  prenom        TEXT,
  email         TEXT,
  nb_avis       INTEGER DEFAULT 0
);
ALTER TABLE clients DISABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════
-- 5. AMÉLIORER TABLE AVIS
--    (lier aux comptes clients + modération)
-- ══════════════════════════════════════════
ALTER TABLE avis
ADD COLUMN IF NOT EXISTS client_id UUID REFERENCES clients(id),
ADD COLUMN IF NOT EXISTS statut TEXT DEFAULT 'en_attente' CHECK (statut IN ('en_attente','approuve','rejete'));

-- Migrer les avis existants
UPDATE avis SET statut = 'approuve' WHERE approuve = true;
UPDATE avis SET statut = 'rejete'   WHERE approuve = false;

-- ══════════════════════════════════════════
-- 6. TABLE HORAIRES DÉTAILLÉS
-- ══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS horaires (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  jour          TEXT NOT NULL CHECK (jour IN ('Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi','Dimanche')),
  ouvert        BOOLEAN DEFAULT true,
  heure_ouv     TIME,
  heure_ferm    TIME,
  UNIQUE(restaurant_id, jour)
);
ALTER TABLE horaires DISABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════
-- 7. TABLE FACTURES / REÇUS
-- ══════════════════════════════════════════
CREATE TABLE IF NOT EXISTS factures (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  numero          TEXT UNIQUE,           -- ex: FAC-2025-001
  restaurant_id   UUID REFERENCES restaurants(id),
  paiement_id     UUID REFERENCES paiements(id),
  montant         INTEGER NOT NULL,
  plan            TEXT,
  nom_resto       TEXT,
  email_resto     TEXT,
  statut          TEXT DEFAULT 'emise',
  envoyee_par_email BOOLEAN DEFAULT false
);
ALTER TABLE factures DISABLE ROW LEVEL SECURITY;

-- Trigger pour générer numéro de facture
CREATE OR REPLACE FUNCTION generate_facture_numero()
RETURNS TRIGGER AS $$
DECLARE
  v_year TEXT := EXTRACT(YEAR FROM NOW())::TEXT;
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) + 1 INTO v_count FROM factures WHERE EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM NOW());
  NEW.numero := 'FAC-' || v_year || '-' || LPAD(v_count::TEXT, 3, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trig_facture_numero ON factures;
CREATE TRIGGER trig_facture_numero
  BEFORE INSERT ON factures
  FOR EACH ROW EXECUTE FUNCTION generate_facture_numero();

-- ══════════════════════════════════════════
-- 8. VUES ANALYTICS ENRICHIES
-- ══════════════════════════════════════════
CREATE OR REPLACE VIEW v_analytics AS
SELECT
  r.id,
  r.nom,
  r.zone,
  r.plan,
  r.statut,
  r.nb_vues,
  r.nb_clics_gps,
  r.rating,
  r.nb_avis,
  r.abonnement_fin,
  COALESCE(a.nb_avis_en_attente, 0) AS nb_avis_en_attente,
  COALESCE(p.nb_paiements, 0) AS nb_paiements,
  COALESCE(p.total_encaisse, 0) AS total_encaisse
FROM restaurants r
LEFT JOIN (
  SELECT restaurant_id, COUNT(*) AS nb_avis_en_attente
  FROM avis WHERE statut = 'en_attente'
  GROUP BY restaurant_id
) a ON a.restaurant_id = r.id
LEFT JOIN (
  SELECT restaurant_id, COUNT(*) AS nb_paiements, SUM(montant) AS total_encaisse
  FROM paiements WHERE statut = 'confirme'
  GROUP BY restaurant_id
) p ON p.restaurant_id = r.id;

-- ══════════════════════════════════════════
-- 9. RÉSUMÉ
-- ══════════════════════════════════════════
SELECT 'Extensions & tables créées :' AS info;
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('favoris','clients','horaires','factures')
ORDER BY table_name;

SELECT '✅ Migration technique complète' AS result;
