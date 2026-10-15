<?php
// Point d'accès JSON pour le statut en direct (rafraîchi par assets/js/main.js toutes les 30 s)
$cfg = require __DIR__ . '/../../app/config.php';
require __DIR__ . '/../../app/statut.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
echo json_encode(lusorp_statut($cfg));
