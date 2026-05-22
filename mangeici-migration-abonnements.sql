-- ================================================
-- MANGEICI — Gestion des abonnements & newsletter
-- Colle dans Supabase > SQL Editor > Run
-- ================================================

-- 1. TABLE NEWSLETTER
CREATE TABLE IF NOT EXISTS newsletter (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  email       TEXT NOT NULL UNIQUE,
  actif       BOOLEAN DEFAULT true
);
ALTER TABLE newsletter DISABLE ROW LEVEL SECURITY;

-- 2. Ajouter colonnes de gestion d'abonnement à restaurants
ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS abonnement_debut    DATE DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS abonnement_fin      DATE DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
  ADD COLUMN IF NOT EXISTS plan_prix_normal    INTEGER DEFAULT 0, -- prix SANS réduction (pour renouvellement)
  ADD COLUMN IF NOT EXISTS rappel_envoye       BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS auth_user_id        UUID DEFAULT NULL;

-- 3. Mettre à jour plan_prix_normal pour les restaurants existants
UPDATE restaurants SET plan_prix_normal =
  CASE plan
    WHEN 'premium' THEN 10500
    WHEN 'pro'     THEN 5000
    WHEN 'starter' THEN 2500
    ELSE 0
  END
WHERE plan_prix_normal = 0 OR plan_prix_normal IS NULL;

-- ================================================
-- 4. FONCTION : Downgrade automatique au plan gratuit
--    après 5 jours de non-renouvellement
-- ================================================
CREATE OR REPLACE FUNCTION check_expired_subscriptions()
RETURNS void AS $$
BEGIN
  -- Downgrader les restaurants expirés depuis +5 jours
  UPDATE restaurants
  SET
    plan = 'gratuit',
    plan_prix_normal = 0,
    visible = true,         -- reste visible en plan gratuit
    rappel_envoye = false   -- reset pour le prochain cycle
  WHERE
    plan != 'gratuit'
    AND abonnement_fin IS NOT NULL
    AND abonnement_fin < (CURRENT_DATE - INTERVAL '5 days');

  -- Log dans paiements pour traçabilité
  INSERT INTO paiements (restaurant_id, plan, montant, methode, statut, reference)
  SELECT id, 'gratuit', 0, 'system', 'downgrade_auto', 'Downgrade automatique - non renouvellement'
  FROM restaurants
  WHERE plan = 'gratuit'
    AND abonnement_fin < (CURRENT_DATE - INTERVAL '5 days')
    AND NOT EXISTS (
      SELECT 1 FROM paiements p
      WHERE p.restaurant_id = restaurants.id
        AND p.reference = 'Downgrade automatique - non renouvellement'
        AND p.created_at::date = CURRENT_DATE
    );
END;
$$ LANGUAGE plpgsql;

-- ================================================
-- 5. FONCTION : Marquer les restaurants à rappeler
--    (10 jours avant expiration)
-- ================================================
CREATE OR REPLACE FUNCTION get_restaurants_to_remind()
RETURNS TABLE(
  id UUID, nom TEXT, email TEXT, telephone TEXT,
  plan TEXT, plan_prix_normal INTEGER, abonnement_fin DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id, r.nom, r.email, r.telephone,
    r.plan, r.plan_prix_normal, r.abonnement_fin
  FROM restaurants r
  WHERE
    r.plan != 'gratuit'
    AND r.abonnement_fin IS NOT NULL
    AND r.abonnement_fin = (CURRENT_DATE + INTERVAL '10 days')::date
    AND r.rappel_envoye = false
    AND r.statut = 'actif';
END;
$$ LANGUAGE plpgsql;

-- ================================================
-- 6. FONCTION : Renouveler un abonnement
--    (appelée après paiement confirmé FedaPay)
--    IMPORTANT : utilise plan_prix_normal (sans réduction)
-- ================================================
CREATE OR REPLACE FUNCTION renouveler_abonnement(
  p_restaurant_id UUID,
  p_plan TEXT,
  p_fedapay_tx_id TEXT DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_prix INTEGER;
BEGIN
  -- Prix NORMAL selon le plan (jamais le prix réduit)
  v_prix := CASE p_plan
    WHEN 'premium' THEN 10500
    WHEN 'pro'     THEN 5000
    WHEN 'starter' THEN 2500
    ELSE 0
  END;

  -- Mettre à jour le restaurant
  UPDATE restaurants
  SET
    plan               = p_plan,
    plan_prix_normal   = v_prix,
    abonnement_debut   = CURRENT_DATE,
    abonnement_fin     = (CURRENT_DATE + INTERVAL '30 days')::date,
    rappel_envoye      = false,
    statut             = 'actif',
    visible            = true
  WHERE id = p_restaurant_id;

  -- Enregistrer le paiement
  INSERT INTO paiements (restaurant_id, plan, montant, methode, statut, reference)
  VALUES (p_restaurant_id, p_plan, v_prix, 'fedapay', 'confirme', p_fedapay_tx_id);
END;
$$ LANGUAGE plpgsql;

-- ================================================
-- 7. Vue : tableau de bord admin - abonnements
-- ================================================
CREATE OR REPLACE VIEW v_abonnements AS
SELECT
  r.id,
  r.nom,
  r.zone,
  r.email,
  r.telephone,
  r.plan,
  r.plan_prix_normal,
  r.abonnement_fin,
  r.statut,
  (r.abonnement_fin - CURRENT_DATE) AS jours_restants,
  CASE
    WHEN r.abonnement_fin < CURRENT_DATE THEN 'expire'
    WHEN r.abonnement_fin < (CURRENT_DATE + INTERVAL '10 days') THEN 'expiration_proche'
    ELSE 'actif'
  END AS statut_abonnement
FROM restaurants r
WHERE r.plan != 'gratuit'
ORDER BY r.abonnement_fin ASC;

-- ================================================
-- 8. TABLE PLANS (pour gestion dynamique depuis admin)
-- ================================================
CREATE TABLE IF NOT EXISTS plans (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  code        TEXT NOT NULL UNIQUE,   -- 'gratuit', 'starter', 'pro', 'premium'
  nom         TEXT NOT NULL,
  prix        INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  features    TEXT[],                 -- liste des fonctionnalités
  max_plats   INTEGER DEFAULT 3,
  max_promos  INTEGER DEFAULT 0,
  max_photos  INTEGER DEFAULT 0,
  has_menu    BOOLEAN DEFAULT false,
  has_stats   BOOLEAN DEFAULT false,
  has_badge   BOOLEAN DEFAULT false,
  has_priority BOOLEAN DEFAULT false,
  actif       BOOLEAN DEFAULT true,
  ordre       INTEGER DEFAULT 0       -- ordre d'affichage
);
ALTER TABLE plans DISABLE ROW LEVEL SECURITY;

-- Insérer les plans de base
INSERT INTO plans (code, nom, prix, description, features, max_plats, max_promos, max_photos, has_menu, has_stats, has_badge, has_priority, actif, ordre) VALUES
('gratuit', 'Gratuit', 0, 'Pour démarrer et tester la plateforme',
  ARRAY['Fiche restaurant basique','Visible dans les résultats','Infos horaires & contact'],
  3, 0, 0, false, false, false, false, true, 0),
('starter', 'Starter', 2500, 'Pour les restaurants qui veulent un menu en ligne',
  ARRAY['Tout du plan Gratuit','Menu complet (10 plats)','Photo principale','Horaires détaillés'],
  10, 0, 1, true, false, false, false, true, 1),
('pro', 'Pro', 5000, 'Pour les restaurants qui veulent plus de visibilité',
  ARRAY['Tout du plan Starter','Promotions & offres (3 max)','Badge Pro visible','Priorité dans les résultats','Statistiques de base'],
  30, 3, 3, true, true, true, true, true, 2),
('premium', 'Premium', 10500, 'Pour les restaurants qui veulent dominer leur zone',
  ARRAY['Tout du plan Pro','Menu illimité','Promos illimitées','Stats complètes + heatmap','Galerie 5 photos','Support dédié WhatsApp','Top classement accueil'],
  999, 999, 5, true, true, true, true, true, 3)
ON CONFLICT (code) DO NOTHING;

-- ================================================
-- Vérification finale
-- ================================================
SELECT 'Tables créées :' as info;
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('newsletter','plans','codes_promo','paiements','restaurants')
ORDER BY table_name;

SELECT '✅ Migration abonnements OK' as result;
