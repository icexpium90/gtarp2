<?php
// Administration du site LUSO RP : changer la photo de fond et la galerie.
// Premiere visite : creation du mot de passe avec le code d'installation (fichier app/donnees/code_installation.txt).

declare(strict_types=1);

$cfg = require __DIR__ . '/../../app/config.php';
require __DIR__ . '/../../app/statut.php';
require __DIR__ . '/../../app/images.php';

const TAILLE_MAX = 10 * 1024 * 1024;   // 10 Mo par image
const ESSAIS_MAX = 5;                  // essais de mot de passe avant blocage
const BLOCAGE = 900;                   // secondes de blocage

$donnees = dirname(__DIR__, 2) . '/app/donnees';
$fichierAdmin = $donnees . '/admin.json';
$fichierCode = $donnees . '/code_installation.txt';
$fichierEssais = $donnees . '/essais.json';

if (!is_dir($donnees)) {
    @mkdir($donnees, 0770, true);
}

session_name('lusorp_admin');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/admin',
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_start();

header('X-Robots-Tag: noindex, nofollow');
header('Cache-Control: no-store');

function lire_json(string $f): array
{
    if (!is_file($f)) return [];
    $d = json_decode((string)file_get_contents($f), true);
    return is_array($d) ? $d : [];
}

function ecrire_json(string $f, array $d): bool
{
    return file_put_contents($f, json_encode($d, JSON_PRETTY_PRINT), LOCK_EX) !== false;
}

function jeton(): string
{
    if (empty($_SESSION['jeton'])) {
        $_SESSION['jeton'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['jeton'];
}

function verifier_jeton(): bool
{
    return isset($_POST['jeton'], $_SESSION['jeton']) && hash_equals($_SESSION['jeton'], (string)$_POST['jeton']);
}

$admin = lire_json($fichierAdmin);
$installe = !empty($admin['hash']);
$ip = $_SERVER['REMOTE_ADDR'] ?? 'inconnue';
$messages = [];
$erreurs = [];

// code d'installation : genere une seule fois, a lire sur le serveur (FTP / SSH)
if (!$installe && !is_file($fichierCode)) {
    @file_put_contents($fichierCode, strtoupper(bin2hex(random_bytes(4))) . PHP_EOL, LOCK_EX);
    @chmod($fichierCode, 0640);
}

$action = $_POST['action'] ?? $_GET['action'] ?? '';

// ------------------------------------------------------------------------------------------------ installation
if (!$installe && $action === 'installer' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $code = strtoupper(trim((string)($_POST['code'] ?? '')));
    $attendu = strtoupper(trim((string)@file_get_contents($fichierCode)));
    $mdp = (string)($_POST['mdp'] ?? '');
    if (!verifier_jeton()) {
        $erreurs[] = 'Session expirée, réessayez.';
    } elseif ($attendu === '' || !hash_equals($attendu, $code)) {
        $erreurs[] = 'Code d\'installation incorrect.';
    } elseif (strlen($mdp) < 10) {
        $erreurs[] = 'Mot de passe trop court (10 caractères minimum).';
    } elseif ($mdp !== (string)($_POST['mdp2'] ?? '')) {
        $erreurs[] = 'Les deux mots de passe ne correspondent pas.';
    } elseif (!ecrire_json($fichierAdmin, ['hash' => password_hash($mdp, PASSWORD_DEFAULT), 'cree' => date('c')])) {
        $erreurs[] = 'Impossible d\'écrire dans app/donnees (droits du dossier : voir LISEZMOI).';
    } else {
        @unlink($fichierCode);
        session_regenerate_id(true);
        $_SESSION['connecte'] = true;
        header('Location: ./');
        exit;
    }
}

// ------------------------------------------------------------------------------------------------ connexion
if ($installe && $action === 'connexion' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $essais = lire_json($fichierEssais);
    $e = $essais[$ip] ?? ['n' => 0, 't' => 0];
    if ($e['n'] >= ESSAIS_MAX && time() - $e['t'] < BLOCAGE) {
        $erreurs[] = 'Trop d\'essais. Réessayez dans ' . ceil((BLOCAGE - (time() - $e['t'])) / 60) . ' min.';
    } elseif (!verifier_jeton()) {
        $erreurs[] = 'Session expirée, réessayez.';
    } elseif (password_verify((string)($_POST['mdp'] ?? ''), $admin['hash'])) {
        unset($essais[$ip]);
        ecrire_json($fichierEssais, $essais);
        session_regenerate_id(true);
        $_SESSION['connecte'] = true;
        header('Location: ./');
        exit;
    } else {
        $e = ['n' => ($e['n'] >= ESSAIS_MAX ? 0 : $e['n']) + 1, 't' => time()];
        $essais[$ip] = $e;
        ecrire_json($fichierEssais, $essais);
        usleep(600000);
        $erreurs[] = 'Mot de passe incorrect.';
    }
}

if ($action === 'deconnexion') {
    $_SESSION = [];
    session_destroy();
    header('Location: ./');
    exit;
}

$connecte = $installe && !empty($_SESSION['connecte']);

// ------------------------------------------------------------------------------------------------ images
function enregistrer_image(array $fichier, string $chemin, array &$erreurs): bool
{
    if (($fichier['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        $codes = [UPLOAD_ERR_INI_SIZE => 'fichier trop gros pour PHP (upload_max_filesize)', UPLOAD_ERR_FORM_SIZE => 'fichier trop gros',
            UPLOAD_ERR_PARTIAL => 'envoi incomplet', UPLOAD_ERR_NO_FILE => 'aucun fichier choisi'];
        $erreurs[] = 'Envoi impossible : ' . ($codes[$fichier['error'] ?? 0] ?? 'erreur ' . ($fichier['error'] ?? '?')) . '.';
        return false;
    }
    if (!is_uploaded_file($fichier['tmp_name']) || $fichier['size'] > TAILLE_MAX) {
        $erreurs[] = 'Fichier refusé (10 Mo maximum).';
        return false;
    }
    $info = @getimagesize($fichier['tmp_name']);
    $types = [IMAGETYPE_JPEG => 'jpg', IMAGETYPE_PNG => 'png', IMAGETYPE_WEBP => 'webp'];
    if (!$info || !isset($types[$info[2]])) {
        $erreurs[] = 'Format refusé : JPG, PNG ou WEBP uniquement.';
        return false;
    }
    if ($info[0] < 300 || $info[1] < 200 || $info[0] > 8000 || $info[1] > 8000) {
        $erreurs[] = 'Dimensions refusées (de 300×200 à 8000×8000 px).';
        return false;
    }
    $dest = lusorp_dossier_public() . '/' . $chemin;
    if (!is_dir(dirname($dest))) {
        @mkdir(dirname($dest), 0775, true);
    }
    $tmp = $dest . '.envoi';
    $ok = false;
    // re-encodage avec GD si disponible (retire les donnees cachees, image propre), sinon copie telle quelle
    if (extension_loaded('gd')) {
        $img = match ($info[2]) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($fichier['tmp_name']),
            IMAGETYPE_PNG => @imagecreatefrompng($fichier['tmp_name']),
            IMAGETYPE_WEBP => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($fichier['tmp_name']) : false,
            default => false,
        };
        if ($img) {
            $ok = imagejpeg($img, $tmp, 86);
            imagedestroy($img);
            $ext = 'jpg';
        }
    }
    if (!$ok) {
        $ok = move_uploaded_file($fichier['tmp_name'], $tmp);
        $ext = $types[$info[2]];
    }
    if (!$ok) {
        $erreurs[] = 'Impossible d\'écrire l\'image (droits du dossier public/assets/img : voir LISEZMOI).';
        return false;
    }
    lusorp_supprimer_image($chemin);
    rename($tmp, "$dest.$ext");
    @chmod("$dest.$ext", 0664);
    return true;
}

$emplacements = lusorp_emplacements();
if ($connecte && $_SERVER['REQUEST_METHOD'] === 'POST' && in_array($action, ['envoyer', 'supprimer'], true)) {
    $cle = (string)($_POST['emplacement'] ?? '');
    if (!verifier_jeton()) {
        $erreurs[] = 'Session expirée, réessayez.';
    } elseif (!isset($emplacements[$cle])) {
        $erreurs[] = 'Emplacement inconnu.';
    } elseif ($action === 'envoyer') {
        if (enregistrer_image($_FILES['image'] ?? [], $emplacements[$cle]['chemin'], $erreurs)) {
            $messages[] = $emplacements[$cle]['label'] . ' : image mise à jour.';
        }
    } else {
        lusorp_supprimer_image($emplacements[$cle]['chemin']);
        $messages[] = $emplacements[$cle]['label'] . ' : image retirée.';
    }
}
?><!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Administration | <?= e($cfg['nom']) ?></title>
    <link rel="icon" type="image/png" href="../assets/img/favicon.png">
    <link rel="stylesheet" href="../assets/css/style.css?v=2">
    <style>
        .admin { width: min(980px, 100% - 2rem); margin: 3rem auto 4rem; }
        .admin header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; }
        .admin header a.marque img { width: 52px; height: 52px; }
        .admin h1 { font-size: 2.2rem; }
        .boite { padding: 1.8rem; margin-bottom: 1.2rem; }
        .boite label { display: block; font-weight: 600; margin: 1rem 0 0.4rem; }
        .boite input[type=password], .boite input[type=text] { width: 100%; padding: 0.75rem 0.9rem; border-radius: 10px; border: 1px solid var(--bord); background: rgba(0,0,0,0.35); color: #fff; font: inherit; }
        .boite .btn { margin-top: 1.3rem; }
        .alerte { padding: 0.8rem 1rem; border-radius: 10px; margin-bottom: 1rem; }
        .alerte.ok { background: rgba(15, 157, 72, 0.18); border: 1px solid rgba(15, 157, 72, 0.5); }
        .alerte.ko { background: rgba(215, 38, 47, 0.18); border: 1px solid rgba(215, 38, 47, 0.5); }
        .images { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1.2rem; }
        .image { padding: 1.2rem; display: grid; gap: 0.8rem; align-content: start; }
        .image h3 { font-size: 1.1rem; }
        .apercu { aspect-ratio: 16 / 9; border-radius: 10px; overflow: hidden; background: rgba(0,0,0,0.4); display: grid; place-items: center; color: var(--doux); border: 1px solid var(--bord); }
        .apercu img { width: 100%; height: 100%; object-fit: cover; }
        .image small { color: var(--doux); }
        .image form { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: center; }
        .image input[type=file] { flex: 1 1 100%; color: var(--doux); font-size: 0.9rem; }
        .image .btn { margin: 0; }
        .aide { color: var(--doux); font-size: 0.9rem; }
        @media (max-width: 760px) { .images { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
<div class="fond" aria-hidden="true"></div>
<div class="admin">
    <header>
        <a class="marque" href="../">
            <img src="../assets/img/logo-180.png" alt="">
            <span><strong><?= e($cfg['nom']) ?></strong><small>Administration du site</small></span>
        </a>
        <?php if ($connecte): ?>
            <a class="btn fantome petit" href="?action=deconnexion">Se déconnecter</a>
        <?php endif; ?>
    </header>

    <?php foreach ($messages as $m): ?><div class="alerte ok"><?= e($m) ?></div><?php endforeach; ?>
    <?php foreach ($erreurs as $m): ?><div class="alerte ko"><?= e($m) ?></div><?php endforeach; ?>

    <?php if (!$installe): ?>
        <form class="boite carte" method="post" autocomplete="off">
            <h1>Créer l'accès admin</h1>
            <p class="aide">Première connexion : le code d'installation se trouve sur le serveur web, dans le fichier
                <code>app/donnees/code_installation.txt</code> (à ouvrir avec FileZilla / WinSCP, ou
                <code>sudo cat /var/www/lusorp/app/donnees/code_installation.txt</code>).</p>
            <input type="hidden" name="action" value="installer">
            <input type="hidden" name="jeton" value="<?= e(jeton()) ?>">
            <label for="code">Code d'installation</label>
            <input type="text" id="code" name="code" required>
            <label for="mdp">Mot de passe admin (10 caractères minimum)</label>
            <input type="password" id="mdp" name="mdp" minlength="10" required autocomplete="new-password">
            <label for="mdp2">Confirmer le mot de passe</label>
            <input type="password" id="mdp2" name="mdp2" minlength="10" required autocomplete="new-password">
            <button class="btn plein" type="submit">Créer l'accès</button>
        </form>
    <?php elseif (!$connecte): ?>
        <form class="boite carte" method="post">
            <h1>Connexion</h1>
            <input type="hidden" name="action" value="connexion">
            <input type="hidden" name="jeton" value="<?= e(jeton()) ?>">
            <label for="mdp">Mot de passe</label>
            <input type="password" id="mdp" name="mdp" required autofocus autocomplete="current-password">
            <button class="btn plein" type="submit">Se connecter</button>
        </form>
    <?php else: ?>
        <h1>Photos du site</h1>
        <p class="aide">JPG, PNG ou WEBP, 10 Mo maximum. La nouvelle image remplace l'ancienne immédiatement sur le site.
            Sans image, la galerie affiche un cadre aux couleurs du logo.</p>
        <div class="images">
            <?php foreach ($emplacements as $cle => $em): $img = lusorp_image($em['chemin']); ?>
                <section class="image carte">
                    <h3><?= e($em['label']) ?></h3>
                    <div class="apercu"><?php if ($img): ?><img src="../<?= e($img) ?>" alt=""><?php else: ?>Aucune image<?php endif; ?></div>
                    <small>Conseil : <?= e($em['conseil']) ?></small>
                    <form method="post" enctype="multipart/form-data">
                        <input type="hidden" name="jeton" value="<?= e(jeton()) ?>">
                        <input type="hidden" name="emplacement" value="<?= e($cle) ?>">
                        <input type="file" name="image" accept="image/jpeg,image/png,image/webp" required>
                        <button class="btn plein petit" type="submit" name="action" value="envoyer">Envoyer</button>
                    </form>
                    <?php if ($img): ?>
                        <form method="post" onsubmit="return confirm('Retirer cette image ?');">
                            <input type="hidden" name="jeton" value="<?= e(jeton()) ?>">
                            <input type="hidden" name="emplacement" value="<?= e($cle) ?>">
                            <button class="btn fantome petit" type="submit" name="action" value="supprimer">Retirer</button>
                        </form>
                    <?php endif; ?>
                </section>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>
</body>
</html>
