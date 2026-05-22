-- ================================================
-- MANGEICI — Corriger l'affichage des restaurants
-- Colle dans Supabase > SQL Editor > Run
-- ================================================

-- 1. Voir l'état actuel de tous les restaurants
SELECT id, nom, zone, statut, visible, plan 
FROM restaurants 
ORDER BY created_at;

-- 2. Activer TOUS les restaurants (statut + visible)
UPDATE restaurants
SET 
  statut  = 'actif',
  visible = true
WHERE statut = 'en_attente' OR visible = false OR visible IS NULL;

-- 3. Vérification finale
SELECT 
  nom, 
  zone, 
  statut, 
  visible, 
  plan
FROM restaurants
ORDER BY created_at;

SELECT '✅ ' || COUNT(*) || ' restaurants maintenant actifs et visibles' AS resultat
FROM restaurants 
WHERE statut = 'actif' AND visible = true;
