-- ================================================
-- MANGEICI — Table profils & suggestions
-- Colle dans Supabase > SQL Editor > Run
-- ================================================

-- 1. TABLE PROFILS RESTAURANTS (Premium uniquement)
CREATE TABLE IF NOT EXISTS profils (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE UNIQUE,
  banniere_url    TEXT,                    -- image bannière principale
  logo_url        TEXT,                    -- logo du restaurant
  bio             TEXT,                    -- description longue
  galerie         TEXT[],                  -- tableau d'URLs images
  whatsapp        TEXT,                    -- numéro WhatsApp du resto
  instagram       TEXT,                    -- handle Instagram
  facebook        TEXT,                    -- URL Facebook
  actif           BOOLEAN DEFAULT true
);

ALTER TABLE profils DISABLE ROW LEVEL SECURITY;

-- 2. TABLE AVIS CLIENTS
CREATE TABLE IF NOT EXISTS avis (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  auteur          TEXT NOT NULL,
  note            INTEGER NOT NULL CHECK (note BETWEEN 1 AND 5),
  commentaire     TEXT,
  approuve        BOOLEAN DEFAULT true
);

ALTER TABLE avis DISABLE ROW LEVEL SECURITY;

-- Avis de démo pour les restaurants existants
INSERT INTO avis (restaurant_id, auteur, note, commentaire) 
SELECT id, 'Kofi A.', 5, 'Excellent ! Les plats sont délicieux et le service impeccable. Je recommande vivement le riz sauce graine.'
FROM restaurants WHERE nom = 'Le Jardin d''Éden' LIMIT 1;

INSERT INTO avis (restaurant_id, auteur, note, commentaire) 
SELECT id, 'Fatoumata D.', 5, 'Cadre magnifique, cuisine authentique. C''est devenu notre restaurant préféré en couple.'
FROM restaurants WHERE nom = 'Le Jardin d''Éden' LIMIT 1;

INSERT INTO avis (restaurant_id, auteur, note, commentaire) 
SELECT id, 'Rodrigue M.', 4, 'Très bonne adresse. Prix raisonnables et portions généreuses. Viendrai encore !'
FROM restaurants WHERE nom = 'Le Jardin d''Éden' LIMIT 1;

-- 3. TABLE SUGGESTIONS
CREATE TABLE IF NOT EXISTS suggestions (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  prenom      TEXT,
  email       TEXT,
  sujet       TEXT,
  message     TEXT NOT NULL,
  lu          BOOLEAN DEFAULT false
);

ALTER TABLE suggestions DISABLE ROW LEVEL SECURITY;

-- Vérification
SELECT 'profils' as table_name, COUNT(*) FROM profils
UNION ALL SELECT 'avis', COUNT(*) FROM avis
UNION ALL SELECT 'suggestions', COUNT(*) FROM suggestions;

SELECT '✅ Tables profils & suggestions créées' as result;
