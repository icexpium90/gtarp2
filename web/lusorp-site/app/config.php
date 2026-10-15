<?php
// Configuration du site LUSO RP : tout ce qui se modifie est ici.
return [
    'nom'          => 'LUSO RP',
    'slogan'       => 'Roleplay FiveM francophone',
    'url'          => 'https://rp.luostatis.fr',
    'description'  => 'LUSO RP, serveur FiveM roleplay : métiers, entreprises, immobilier, gangs et événements. Rejoins la ville.',

    // Serveur FiveM : IP publique et port (utilisés pour le statut en direct et le bouton Se connecter)
    'serveur_ip'   => '169.58.243.127',
    'serveur_port' => 30120,
    // Code cfx.re du serveur (ex. "abc123", visible dans txAdmin) : si renseigné, le bouton utilise cfx.re/join/<code>
    'cfx_code'     => '',
    'places'       => 48,      // affiché si le serveur ne répond pas

    'discord'      => 'https://discord.gg/MuFbeK87B4',
    'boutique'     => '',      // lien Tebex (laisser vide pour masquer le bouton)
    'reseaux'      => [
        // 'YouTube' => 'https://youtube.com/@...',
        // 'TikTok'  => 'https://tiktok.com/@...',
        // 'Instagram' => 'https://instagram.com/...',
    ],

    'cache_statut' => 30,      // secondes entre deux interrogations du serveur FiveM
];
