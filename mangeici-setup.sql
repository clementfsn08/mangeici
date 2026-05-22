-- ================================================
-- MANGEICI — Script de création des tables Supabase
-- Colle tout ce SQL dans : Supabase > SQL Editor > New query > Run
-- ================================================

-- 1. TABLE RESTAURANTS
CREATE TABLE IF NOT EXISTS restaurants (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  nom             TEXT NOT NULL,
  zone            TEXT NOT NULL,
  adresse         TEXT,
  telephone       TEXT NOT NULL,
  email           TEXT NOT NULL,
  description     TEXT,
  cuisine         TEXT[],
  prix_min        INTEGER NOT NULL DEFAULT 0,
  capacite        TEXT,
  ambiances       TEXT[],
  photo_url       TEXT,
  plan            TEXT NOT NULL DEFAULT 'gratuit',
  statut          TEXT NOT NULL DEFAULT 'en_attente',
  visible         BOOLEAN DEFAULT true,
  afficher_tel    BOOLEAN DEFAULT true,
  afficher_horaires BOOLEAN DEFAULT true,
  accepter_avis   BOOLEAN DEFAULT true,
  notif_avis      BOOLEAN DEFAULT true,
  notif_hebdo     BOOLEAN DEFAULT true,
  rating          NUMERIC(2,1) DEFAULT 0,
  nb_avis         INTEGER DEFAULT 0,
  nb_vues         INTEGER DEFAULT 0,
  nb_clics_gps    INTEGER DEFAULT 0,
  gps_lat         NUMERIC(9,6),
  gps_lng         NUMERIC(9,6)
);

-- 2. TABLE MENUS
CREATE TABLE IF NOT EXISTS menus (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  nom             TEXT NOT NULL,
  categorie       TEXT NOT NULL DEFAULT 'plat',
  prix            INTEGER NOT NULL,
  description     TEXT,
  emoji           TEXT DEFAULT '🍽',
  disponible      BOOLEAN DEFAULT true
);

-- 3. TABLE PROMOTIONS
CREATE TABLE IF NOT EXISTS promotions (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  titre           TEXT NOT NULL,
  reduction       TEXT,
  description     TEXT,
  date_debut      DATE,
  date_fin        DATE,
  statut          TEXT DEFAULT 'on',
  nb_vues         INTEGER DEFAULT 0
);

-- 4. TABLE PAIEMENTS
CREATE TABLE IF NOT EXISTS paiements (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  plan            TEXT NOT NULL,
  montant         INTEGER NOT NULL,
  methode         TEXT NOT NULL,
  statut          TEXT DEFAULT 'confirme',
  reference       TEXT,
  telephone       TEXT
);

-- 5. TABLE STATS QUOTIDIENNES
CREATE TABLE IF NOT EXISTS stats_quotidiennes (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date            DATE DEFAULT CURRENT_DATE,
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  nb_vues         INTEGER DEFAULT 0,
  nb_clics_gps    INTEGER DEFAULT 0,
  nb_vues_menu    INTEGER DEFAULT 0
);

-- 6. DÉSACTIVER RLS (pour commencer simplement)
ALTER TABLE restaurants         DISABLE ROW LEVEL SECURITY;
ALTER TABLE menus                DISABLE ROW LEVEL SECURITY;
ALTER TABLE promotions           DISABLE ROW LEVEL SECURITY;
ALTER TABLE paiements            DISABLE ROW LEVEL SECURITY;
ALTER TABLE stats_quotidiennes   DISABLE ROW LEVEL SECURITY;

-- 7. DONNÉES DE DÉMO
INSERT INTO restaurants (nom, zone, adresse, telephone, email, description, cuisine, prix_min, ambiances, plan, statut, rating, nb_avis, nb_vues, nb_clics_gps, gps_lat, gps_lng, photo_url) VALUES
('Le Jardin d''Éden',    'Cadjehoun',      'Rue des Cocotiers, Cadjehoun',    '+229 96 00 00 01', 'eden@resto.bj',     'Restaurant cosy avec terrasse ombragée',         ARRAY['Cuisine béninoise'], 1500, ARRAY['En couple','Solo','Terrasse'],    'premium', 'actif', 4.7, 128, 847,  124, 6.3600, 2.3773, 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80&fit=crop'),
('Braises & Co.',        'Fidjrossè',      'Av. du Bord de Mer, Fidjrossè',   '+229 96 00 00 02', 'braises@resto.bj',  'Spécialiste des grillades au feu de bois',       ARRAY['Grillades'],         2000, ARRAY['Entre amis','Climatisé'],         'pro',     'actif', 4.5,  94, 512,   80, 6.3488, 2.3680, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&q=80&fit=crop'),
('Saveurs d''Asie',      'Akpakpa',        'Bd Saint Michel, Akpakpa',        '+229 96 00 00 03', 'asie@resto.bj',     'Cuisine asiatique authentique au cœur de Cotonou', ARRAY['Asiatique'],         3500, ARRAY['Famille','Livraison'],            'premium', 'actif', 4.8, 211, 1203, 187, 6.3620, 2.4180, 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&q=80&fit=crop'),
('Chez Maman Cécile',    'Cotonou Centre', 'Marché Dantokpa, face nord',      '+229 96 00 00 04', 'cecile@resto.bj',   'Cuisine béninoise maison, faite avec amour',     ARRAY['Cuisine béninoise'], 800,  ARRAY['Solo','Familial','Authentique'], 'gratuit', 'actif', 4.3, 302, 634,   45, 6.3654, 2.4183, 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80&fit=crop'),
('Le Libanais',          'Haie Vive',      'Rue du Commerce, Haie Vive',      '+229 96 00 00 05', 'liban@resto.bj',    'Mezze et spécialités libanaises dans un cadre raffiné', ARRAY['Libanais'],      4500, ARRAY['En couple','Business'],           'pro',     'actif', 4.6,  87, 423,   61, 6.3710, 2.3900, 'https://images.unsplash.com/photo-1561626423-a51b45aef0a1?w=600&q=80&fit=crop'),
('Ocean Grill',          'Fidjrossè',      'Plage de Fidjrossè',              '+229 96 00 00 06', 'ocean@resto.bj',    'Fruits de mer frais avec vue sur l''Atlantique', ARRAY['Fruits de mer'],    5000, ARRAY['En couple','Vue mer','Romantique'],'premium','actif', 4.9, 163, 921,  142, 6.3455, 2.3650, 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80&fit=crop'),
('Maquis du Peuple',     'Gbègamey',       'Carrefour Gbègamey',              '+229 96 00 00 07', 'maquis@resto.bj',   'Ambiance authentique, musique live le week-end', ARRAY['Cuisine béninoise'], 1000, ARRAY['Entre amis','Musique live'],      'gratuit', 'actif', 4.2, 256, 445,   38, 6.3740, 2.3960, 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80&fit=crop'),
('Burger Palace BJ',     'Cotonou Centre', 'Avenue Steinmetz, Cotonou',       '+229 96 00 00 08', 'burger@resto.bj',   'Les meilleurs burgers de Cotonou, livraison rapide', ARRAY['Fast-food'],      2000, ARRAY['Solo','Livraison','Rapide'],      'pro',     'actif', 4.4, 198, 712,   98, 6.3670, 2.4200, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80&fit=crop');

-- 8. DONNÉES MENUS DE DÉMO (pour Le Jardin d'Éden)
INSERT INTO menus (restaurant_id, nom, categorie, prix, description, emoji, disponible)
SELECT id, 'Riz sauce graine',     'plat',    1500, 'Riz blanc sauce graine maison',    '🍛', true  FROM restaurants WHERE nom = 'Le Jardin d''Éden';
INSERT INTO menus (restaurant_id, nom, categorie, prix, description, emoji, disponible)
SELECT id, 'Akassa + poisson',     'plat',    1200, 'Akassa frais avec poisson grillé', '🐟', true  FROM restaurants WHERE nom = 'Le Jardin d''Éden';
INSERT INTO menus (restaurant_id, nom, categorie, prix, description, emoji, disponible)
SELECT id, 'Poulet braisé',        'plat',    2500, 'Demi-poulet avec accompagnement',  '🍗', true  FROM restaurants WHERE nom = 'Le Jardin d''Éden';
INSERT INTO menus (restaurant_id, nom, categorie, prix, description, emoji, disponible)
SELECT id, 'Jus de bissap maison', 'boisson',  500, 'Jus d''hibiscus naturel',          '🥤', true  FROM restaurants WHERE nom = 'Le Jardin d''Éden';

-- 9. PROMO DE DÉMO
INSERT INTO promotions (restaurant_id, titre, reduction, description, date_debut, date_fin, statut, nb_vues)
SELECT id, '-15% sur tous les plats du midi', '-15%', 'Valable lundi–vendredi 11h–14h', '2025-01-10', '2025-01-31', 'on', 124
FROM restaurants WHERE nom = 'Saveurs d''Asie';

-- ✅ TERMINÉ — Vérifie dans Table Editor que les tables sont bien créées
SELECT 'restaurants' as table_name, COUNT(*) as nb_lignes FROM restaurants
UNION ALL SELECT 'menus', COUNT(*) FROM menus
UNION ALL SELECT 'promotions', COUNT(*) FROM promotions
UNION ALL SELECT 'paiements', COUNT(*) FROM paiements;
