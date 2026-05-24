// ╔══════════════════════════════════════════╗
// ║  MANGEICI — Variables d'environnement    ║
// ║  CE FICHIER NE DOIT PAS ÊTRE SUR GITHUB  ║
// ║  Ajoutez-le dans .gitignore              ║
// ╚══════════════════════════════════════════╝

// Pour Netlify: Site settings → Environment variables
// Ajoutez chaque variable ci-dessous dans Netlify,
// puis ce fichier sera généré automatiquement.

window.__ENV = {
  // Supabase (clé anon = publique par design, protégée par RLS)
  SUPABASE_URL:  "https://ldcweouzknksuudvroqu.supabase.co",
  SUPABASE_ANON: "VOTRE_CLE_ANON_ICI",

  // FedaPay (clé publique = OK dans le front, mais pas dans git)
  FEDAPAY_KEY:   "VOTRE_CLE_FEDAPAY_ICI",

  // Admin (hash du mot de passe, pas le mot de passe en clair)
  ADMIN_HASH:    "VOTRE_HASH_SHA256_ICI",
};
