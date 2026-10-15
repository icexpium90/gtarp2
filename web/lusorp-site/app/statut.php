<?php
// Statut du serveur FiveM (joueurs connectés), lu côté serveur web puis mis en cache quelques secondes.
function lusorp_statut(array $cfg): array
{
    $cache = sys_get_temp_dir() . '/lusorp_statut.json';
    if (is_file($cache) && (time() - filemtime($cache)) < (int)$cfg['cache_statut']) {
        $donnees = json_decode((string)file_get_contents($cache), true);
        if (is_array($donnees)) {
            return $donnees;
        }
    }

    $base = sprintf('http://%s:%d', $cfg['serveur_ip'], (int)$cfg['serveur_port']);
    $ctx = stream_context_create(['http' => ['timeout' => 3, 'ignore_errors' => true, 'header' => "User-Agent: LUSO-RP-site\r\n"]]);

    $statut = ['en_ligne' => false, 'joueurs' => 0, 'max' => (int)$cfg['places'], 'maj' => time()];
    $dyn = @file_get_contents($base . '/dynamic.json', false, $ctx);
    if ($dyn !== false) {
        $d = json_decode($dyn, true);
        if (is_array($d)) {
            $statut['en_ligne'] = true;
            $statut['joueurs'] = (int)($d['clients'] ?? 0);
            $statut['max'] = (int)($d['sv_maxclients'] ?? $cfg['places']);
        }
    }

    @file_put_contents($cache, json_encode($statut), LOCK_EX);
    return $statut;
}

function lusorp_adresse(array $cfg): string
{
    return $cfg['serveur_ip'] . ':' . (int)$cfg['serveur_port'];
}

function lusorp_lien_connexion(array $cfg): string
{
    if (!empty($cfg['cfx_code'])) {
        return 'https://cfx.re/join/' . rawurlencode($cfg['cfx_code']);
    }
    return 'fivem://connect/' . lusorp_adresse($cfg);
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}
