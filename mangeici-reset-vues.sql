-- ================================================
-- MANGEICI — Reset des compteurs de vues à zéro
-- Colle dans Supabase > SQL Editor > Run
-- ================================================

-- 1. Remettre tous les compteurs à zéro dans restaurants
UPDATE restaurants
SET
  nb_vues      = 0,
  nb_clics_gps = 0,
  nb_avis      = 0;

-- 2. Vider la table stats quotidiennes
TRUNCATE TABLE stats_quotidiennes;

-- 3. Créer une vraie table de tracking des vues
--    (pour le graphique par période dans l'admin)
CREATE TABLE IF NOT EXISTS vues_journalieres (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date            DATE NOT NULL DEFAULT CURRENT_DATE,
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  nb_vues         INTEGER DEFAULT 0,
  nb_clics_gps    INTEGER DEFAULT 0,
  nb_vues_menu    INTEGER DEFAULT 0,
  UNIQUE(date, restaurant_id)
);
ALTER TABLE vues_journalieres DISABLE ROW LEVEL SECURITY;

-- 4. Table vues globales du site (pas par resto)
CREATE TABLE IF NOT EXISTS vues_site (
  id      UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date    DATE NOT NULL DEFAULT CURRENT_DATE UNIQUE,
  nb_vues INTEGER DEFAULT 0
);
ALTER TABLE vues_site DISABLE ROW LEVEL SECURITY;

-- 5. Vérification
SELECT 'restaurants' as table_name, SUM(nb_vues) as total_vues FROM restaurants
UNION ALL
SELECT 'vues_journalieres', COUNT(*) FROM vues_journalieres
UNION ALL
SELECT 'vues_site', COUNT(*) FROM vues_site;

SELECT '✅ Reset des vues effectué — décompte repart de 0' as result;
