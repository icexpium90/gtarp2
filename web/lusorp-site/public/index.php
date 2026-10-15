<?php
$cfg = require __DIR__ . '/../app/config.php';
require __DIR__ . '/../app/statut.php';

$statut   = lusorp_statut($cfg);
$adresse  = lusorp_adresse($cfg);
$connexion = lusorp_lien_connexion($cfg);
$annee    = date('Y');

// Galerie : assets/img/galerie/1.jpg, 2.jpg, 3.jpg (ou .png / .webp) si présentes
function image_galerie(int $n): ?string
{
    foreach (['webp', 'jpg', 'jpeg', 'png'] as $ext) {
        if (is_file(__DIR__ . "/assets/img/galerie/$n.$ext")) {
            return "assets/img/galerie/$n.$ext";
        }
    }
    return null;
}

$activites = [
    ['icone' => 'badge', 'titre' => 'Métiers publics', 'texte' => 'Police, EMS, mécaniciens, taxis, dépanneuses : des grades, des véhicules de service et des factures pour faire tourner la ville.'],
    ['icone' => 'briefcase', 'titre' => 'Entreprises', 'texte' => 'Dynasty 8, LS Customs, concessions : recrute, facture tes clients, gère le compte de ta société et cumule jusqu’à trois métiers.'],
    ['icone' => 'home', 'titre' => 'Immobilier', 'texte' => 'Appartements, villas MLO, garages physiques, coffres et ateliers privés : achète, loue, décore et invite qui tu veux.'],
    ['icone' => 'car', 'titre' => 'Voitures', 'texte' => 'Concessions, import, LS Customs complet avec bodykits et préparation : chaque véhicule raconte quelque chose de son pilote.'],
    ['icone' => 'mask', 'titre' => 'Choix risqués', 'texte' => 'Gangs, territoires, points de deal, blanchiment et braquages : la ville récompense l’audace, et la police n’oublie pas.'],
    ['icone' => 'music', 'titre' => 'Événements', 'texte' => 'Festivals avec DJ en direct, courses, soirées et événements staff : il se passe toujours quelque chose quelque part.'],
];

$faq = [
    ['q' => 'Comment rejoindre le serveur ?', 'r' => 'Installe FiveM, puis clique sur « Se connecter » ou ouvre la console FiveM (F8) et tape <code>connect ' . e($adresse) . '</code>. Rejoins aussi le Discord pour les annonces.'],
    ['q' => 'Le serveur est-il en whitelist ?', 'r' => 'Les règles et les éventuelles candidatures (métiers publics, gangs) sont expliquées sur le Discord. Lis-les avant ta première connexion.'],
    ['q' => 'Discord est-il obligatoire ?', 'r' => 'Fortement conseillé : annonces, support, signalements et candidatures passent par le Discord.'],
    ['q' => 'Quelle version de GTA V faut-il ?', 'r' => 'GTA V à jour (version Legacy) et FiveM à jour. Le premier téléchargement des cartes et véhicules peut prendre quelques minutes.'],
    ['q' => 'Où signaler un problème ?', 'r' => 'En jeu avec <code>/report</code>, ou dans le salon support du Discord avec une capture et l’heure du souci.'],
];

function icone(string $nom): string
{
    $p = [
        'badge' => '<path d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3Z"/><path d="m9 12 2 2 4-4"/>',
        'briefcase' => '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
        'home' => '<path d="m3 11 9-7 9 7"/><path d="M5 10v10h14V10M10 20v-6h4v6"/>',
        'car' => '<path d="M5 16h14l-1.5-6.5A2 2 0 0 0 15.6 8H8.4a2 2 0 0 0-1.9 1.5L5 16Z"/><path d="M3 16h18v3H3zM7 19v2M17 19v2"/>',
        'mask' => '<path d="M3 8c3-2 6-2 9 0 3-2 6-2 9 0 0 6-3 10-9 10S3 14 3 8Z"/><circle cx="8.5" cy="11" r="1.5"/><circle cx="15.5" cy="11" r="1.5"/>',
        'music' => '<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>',
        'discord' => '<path d="M8 8.5c2.6-1 5.4-1 8 0M7.5 16c2.9 1.3 6.1 1.3 9 0"/><path d="M6.5 6.5 5 9c-1 3-1.2 6-.5 9 1.4 1 2.8 1.6 4.2 2l1-1.8M17.5 6.5 19 9c1 3 1.2 6 .5 9-1.4 1-2.8 1.6-4.2 2l-1-1.8"/><circle cx="9.5" cy="13" r="1"/><circle cx="14.5" cy="13" r="1"/>',
        'play' => '<path d="m8 5 11 7-11 7V5Z"/>',
        'copy' => '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h8"/>',
        'arrow' => '<path d="M5 12h14M13 6l6 6-6 6"/>',
    ];
    return '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' . ($p[$nom] ?? '') . '</svg>';
}
?><!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($cfg['nom']) ?> | Serveur FiveM roleplay</title>
    <meta name="description" content="<?= e($cfg['description']) ?>">
    <meta property="og:type" content="website">
    <meta property="og:locale" content="fr_FR">
    <meta property="og:title" content="<?= e($cfg['nom']) ?> | Serveur FiveM roleplay">
    <meta property="og:description" content="<?= e($cfg['description']) ?>">
    <meta property="og:url" content="<?= e($cfg['url']) ?>">
    <meta property="og:image" content="<?= e($cfg['url']) ?>/assets/img/og.jpg">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="theme-color" content="#07090a">
    <link rel="icon" type="image/png" href="assets/img/favicon.png">
    <link rel="apple-touch-icon" href="assets/img/logo-180.png">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Anton&family=Inter:wght@400;500;600;700&family=Permanent+Marker&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="assets/css/style.css?v=1">
</head>
<body>
<div class="fond" aria-hidden="true"></div>

<header class="nav" id="haut">
    <a class="marque" href="#accueil">
        <img src="assets/img/logo-180.png" alt="" width="44" height="44">
        <span><strong><?= e($cfg['nom']) ?></strong><small>Roleplay FiveM</small></span>
    </a>
    <nav class="liens" aria-label="Navigation">
        <a href="#accueil">Accueil</a>
        <a href="#ville">La ville</a>
        <a href="#activites">Activités</a>
        <a href="#galerie">Galerie</a>
        <a href="#faq">FAQ</a>
    </nav>
    <div class="nav-actions">
        <span class="pastille <?= $statut['en_ligne'] ? 'ok' : 'off' ?>" data-statut-pastille>
            <i></i><span data-statut-court><?= $statut['en_ligne'] ? $statut['joueurs'] . ' en ville' : 'Vérification' ?></span>
        </span>
        <a class="btn fantome petit" href="<?= e($cfg['discord']) ?>" target="_blank" rel="noopener"><?= icone('discord') ?>Discord</a>
        <a class="btn plein petit" href="<?= e($connexion) ?>"><?= icone('play') ?>Jouer</a>
    </div>
    <button class="burger" aria-label="Menu" data-burger><span></span><span></span><span></span></button>
</header>

<main>
    <section class="hero" id="accueil">
        <div class="hero-texte">
            <p class="surtitre">Communauté roleplay FiveM</p>
            <h1>Ta légende<br>commence <em>ici.</em></h1>
            <p class="intro">Trouve ta place, construis ta réputation et laisse ta marque sur la ville.
                Métiers, entreprises, gangs, immobilier : à LUSO RP, chaque choix compte.</p>
            <div class="actions">
                <a class="btn plein" href="<?= e($connexion) ?>"><?= icone('play') ?>Entrer en ville</a>
                <a class="btn fantome" href="<?= e($cfg['discord']) ?>" target="_blank" rel="noopener"><?= icone('discord') ?>Rejoindre le Discord</a>
            </div>
            <ul class="chiffres">
                <li><strong data-statut-max><?= (int)$statut['max'] ?></strong><span>places</span></li>
                <li><strong>24/7</strong><span>ville ouverte</span></li>
                <li><strong>1</strong><span>histoire commune</span></li>
            </ul>
        </div>
        <div class="hero-logo">
            <div class="halo"></div>
            <picture>
                <source srcset="assets/img/logo.webp" type="image/webp">
                <img src="assets/img/logo.png" alt="Logo LUSO Roleplay" width="640" height="640">
            </picture>
        </div>
    </section>

    <section class="statut carte" aria-label="Statut du serveur">
        <div>
            <p class="surtitre">Statut en direct</p>
            <p class="joueurs"><span data-statut-joueurs><?= $statut['en_ligne'] ? (int)$statut['joueurs'] : '--' ?></span>
                <small>/ <span data-statut-max><?= (int)$statut['max'] ?></span> joueurs</small></p>
            <p class="etat" data-statut-texte><?= $statut['en_ligne'] ? 'Serveur en ligne' : 'Serveur injoignable pour le moment' ?></p>
        </div>
        <div class="adresse">
            <span>Adresse du serveur</span>
            <code data-adresse><?= e($adresse) ?></code>
            <button class="btn fantome petit" data-copier="<?= e('connect ' . $adresse) ?>"><?= icone('copy') ?>Copier</button>
        </div>
        <div class="statut-actions">
            <a class="btn plein" href="<?= e($connexion) ?>"><?= icone('play') ?>Se connecter</a>
            <a class="btn fantome" href="<?= e($cfg['discord']) ?>" target="_blank" rel="noopener"><?= icone('discord') ?>Discord</a>
            <small>Actualisé toutes les 30 s</small>
        </div>
    </section>

    <section class="ville" id="ville">
        <figure class="ville-visuel">
            <?php $img = image_galerie(1); ?>
            <?php if ($img): ?>
                <img src="<?= e($img) ?>" alt="La ville de LUSO RP" loading="lazy">
            <?php else: ?>
                <div class="visuel-vide"><img src="assets/img/logo-180.png" alt="" width="120" height="120"></div>
            <?php endif; ?>
            <figcaption><span>Population actuelle</span><strong><span data-statut-joueurs><?= $statut['en_ligne'] ? (int)$statut['joueurs'] : '--' ?></span> / <span data-statut-max><?= (int)$statut['max'] ?></span></strong><em>Une ville qui a du poids</em></figcaption>
        </figure>
        <div class="ville-texte">
            <p class="surtitre">La ville</p>
            <h2>Fais en sorte que la ville <em>se souvienne de toi.</em></h2>
            <p>Un serveur pensé pour le roleplay : une économie tenue par les joueurs, des métiers qui ont du sens et une équipe qui fait vivre la ville semaine après semaine.</p>
            <ul class="puces">
                <li>Développement actif et mises à jour régulières</li>
                <li>Systèmes sur mesure : immobilier, factures, multi-métiers, gangs</li>
                <li>Économie entre les mains des joueurs</li>
                <li>Événements chaque semaine</li>
            </ul>
            <a class="lien-fleche" href="#activites">Découvrir la ville <?= icone('arrow') ?></a>
        </div>
    </section>

    <section class="activites" id="activites">
        <div class="titre-section">
            <p class="surtitre">Fait pour les belles histoires</p>
            <h2>Une ville où il y a <em>toujours quelque chose à faire.</em></h2>
            <p class="compteur">06 façons de faire ta place</p>
        </div>
        <div class="grille">
            <?php foreach ($activites as $i => $a): ?>
                <article class="carte activite">
                    <span class="num"><?= sprintf('%02d', $i + 1) ?></span>
                    <?= icone($a['icone']) ?>
                    <h3><?= e($a['titre']) ?></h3>
                    <p><?= e($a['texte']) ?></p>
                </article>
            <?php endforeach; ?>
        </div>
    </section>

    <section class="galerie" id="galerie">
        <div class="titre-section">
            <p class="surtitre">Dans la ville</p>
            <h2>Vois où ton histoire <em>peut te mener.</em></h2>
            <p class="compteur">Carnet de route / 01—03</p>
        </div>
        <div class="vignettes">
            <?php foreach ([1 => 'Les lumières de la ville', 2 => 'Une avenue à la nuit tombée', 3 => 'Sportive et voiture de patrouille'] as $n => $legende): ?>
                <?php $img = image_galerie($n); ?>
                <figure class="vignette<?= $img ? '' : ' vide' ?>">
                    <?php if ($img): ?>
                        <img src="<?= e($img) ?>" alt="<?= e($legende) ?>" loading="lazy">
                    <?php else: ?>
                        <div class="visuel-vide"><img src="assets/img/logo-180.png" alt="" width="90" height="90"></div>
                    <?php endif; ?>
                    <figcaption><span><?= sprintf('%02d', $n) ?></span><?= e($legende) ?></figcaption>
                </figure>
            <?php endforeach; ?>
        </div>
    </section>

    <section class="appel carte">
        <div>
            <p class="surtitre">Prêt ?</p>
            <h2>Ton prochain chapitre <em>commence ici.</em></h2>
            <p class="etat" data-statut-texte><?= $statut['en_ligne'] ? 'Serveur en ligne' : 'Serveur injoignable pour le moment' ?></p>
        </div>
        <div class="appel-actions">
            <div class="adresse">
                <code><?= e($adresse) ?></code>
                <button class="btn fantome petit" data-copier="<?= e('connect ' . $adresse) ?>"><?= icone('copy') ?>Copier</button>
            </div>
            <div class="actions">
                <a class="btn plein" href="<?= e($connexion) ?>"><?= icone('play') ?>Se connecter</a>
                <a class="btn fantome" href="<?= e($cfg['discord']) ?>" target="_blank" rel="noopener"><?= icone('discord') ?>Ouvrir le Discord</a>
            </div>
            <small>Astuce : dans FiveM, appuie sur F8 et colle <code>connect <?= e($adresse) ?></code>.</small>
        </div>
    </section>

    <section class="faq" id="faq">
        <div class="titre-section">
            <p class="surtitre">FAQ</p>
            <h2>Des questions <em>avant de venir ?</em></h2>
            <p>Une autre question ? <a href="<?= e($cfg['discord']) ?>" target="_blank" rel="noopener">Pose-la sur le Discord</a>.</p>
        </div>
        <div class="questions">
            <?php foreach ($faq as $f): ?>
                <details class="carte">
                    <summary><?= e($f['q']) ?></summary>
                    <p><?= $f['r'] ?></p>
                </details>
            <?php endforeach; ?>
        </div>
    </section>
</main>

<footer class="pied">
    <div class="pied-marque">
        <img src="assets/img/logo-180.png" alt="LUSO RP" width="90" height="90">
        <p>Des systèmes immersifs et des histoires de joueurs, à vivre ensemble.</p>
        <div class="actions">
            <a class="btn plein petit" href="<?= e($cfg['discord']) ?>" target="_blank" rel="noopener"><?= icone('discord') ?>Rejoindre le Discord</a>
            <?php if (!empty($cfg['boutique'])): ?>
                <a class="btn fantome petit" href="<?= e($cfg['boutique']) ?>" target="_blank" rel="noopener">Boutique</a>
            <?php endif; ?>
        </div>
    </div>
    <div>
        <h4>Explorer</h4>
        <a href="#accueil">Accueil</a><a href="#ville">La ville</a><a href="#activites">Activités</a><a href="#galerie">Galerie</a><a href="#faq">FAQ</a>
    </div>
    <?php if (!empty($cfg['reseaux'])): ?>
        <div>
            <h4>Suivre</h4>
            <?php foreach ($cfg['reseaux'] as $nom => $lien): ?>
                <a href="<?= e($lien) ?>" target="_blank" rel="noopener"><?= e($nom) ?></a>
            <?php endforeach; ?>
            <small>Nouveautés, événements et actualités de la ville.</small>
        </div>
    <?php endif; ?>
    <div class="pied-bas">
        <span>© <?= $annee ?> <?= e($cfg['nom']) ?>. Tous droits réservés.</span>
        <span>Fait pour les histoires qui méritent d’être racontées.</span>
    </div>
</footer>

<div class="toast" role="status" aria-live="polite" data-toast></div>
<script src="assets/js/main.js?v=1" defer></script>
</body>
</html>
