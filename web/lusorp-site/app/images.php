<?php
// Images modifiables depuis /admin : fond de l'accueil et galerie (1 a 3).
// Chaque emplacement est un fichier unique : public/assets/img/<nom>.<webp|jpg|png>

const LUSORP_EXTENSIONS = ['webp', 'jpg', 'jpeg', 'png'];

function lusorp_emplacements(): array
{
    return [
        'fond'      => ['label' => 'Fond de l\'accueil', 'chemin' => 'assets/img/fond', 'conseil' => '1920 px de large ou plus, format paysage'],
        'galerie/1' => ['label' => 'Galerie 1 (aussi utilisée dans « La ville »)', 'chemin' => 'assets/img/galerie/1', 'conseil' => '1600 px de large, paysage'],
        'galerie/2' => ['label' => 'Galerie 2', 'chemin' => 'assets/img/galerie/2', 'conseil' => '1000 px de large, portrait ou paysage'],
        'galerie/3' => ['label' => 'Galerie 3', 'chemin' => 'assets/img/galerie/3', 'conseil' => '1000 px de large, portrait ou paysage'],
    ];
}

function lusorp_dossier_public(): string
{
    return dirname(__DIR__) . '/public';
}

// URL relative de l'image (avec ?v= pour forcer le rechargement apres un changement), ou null
function lusorp_image(string $chemin): ?string
{
    foreach (LUSORP_EXTENSIONS as $ext) {
        $f = lusorp_dossier_public() . "/$chemin.$ext";
        if (is_file($f)) {
            return "$chemin.$ext?v=" . filemtime($f);
        }
    }
    return null;
}

function lusorp_supprimer_image(string $chemin): void
{
    foreach (LUSORP_EXTENSIONS as $ext) {
        $f = lusorp_dossier_public() . "/$chemin.$ext";
        if (is_file($f)) {
            @unlink($f);
        }
    }
}
