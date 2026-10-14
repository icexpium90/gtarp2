<#
  Met a jour les artifacts FXServer (Windows) vers la version "recommended" (ou "latest" / "optional").

  Usage (PowerShell) :
    .\maj_fxserver.ps1 -FxDir "C:\FXServer\server" [-Canal recommended] [-Relancer "C:\FXServer\server\FXServer.exe"]

    -FxDir     dossier qui contient FXServer.exe
    -Canal     recommended (defaut, conseille), latest ou optional
    -Relancer  programme a relancer apres la mise a jour (FXServer.exe, ou votre .bat de lancement txAdmin)

  Automatique : Planificateur de taches > Creer une tache > Declencheur hebdomadaire > Action :
    powershell.exe -ExecutionPolicy Bypass -File "C:\FXServer\maj_fxserver.ps1" -FxDir "C:\FXServer\server" -Relancer "C:\FXServer\server\FXServer.exe"
#>
param(
    [Parameter(Mandatory = $true)][string]$FxDir,
    [ValidateSet('recommended', 'latest', 'optional')][string]$Canal = 'recommended',
    [string]$Relancer = ''
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path (Join-Path $FxDir 'FXServer.exe'))) { throw "FXServer.exe introuvable dans $FxDir" }

$info = Invoke-RestMethod 'https://changelogs-live.fivem.net/api/changelog/versions/win32/server'
$version = $info.$Canal
$url = $info."$($Canal)_download"
if (-not $version -or -not $url) { throw "Reponse de l'API inattendue" }

$fichierVersion = Join-Path $FxDir '.fxversion'
$actuelle = if (Test-Path $fichierVersion) { (Get-Content $fichierVersion -Raw).Trim() } else { 'aucune' }
Write-Host "Version installee : $actuelle | $Canal disponible : $version"
if ($actuelle -eq "$version") { Write-Host 'Deja a jour.'; exit 0 }

$tmp = Join-Path $env:TEMP ("fxserver_" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $archive = Join-Path $tmp ([IO.Path]::GetFileName($url))
    Write-Host "Telechargement de $url"
    Invoke-WebRequest $url -OutFile $archive -UseBasicParsing
    $extrait = Join-Path $tmp 'extrait'
    New-Item -ItemType Directory -Path $extrait | Out-Null
    if ($archive -like '*.zip') {
        Expand-Archive $archive -DestinationPath $extrait
    } else {
        # .7z : 7-Zip s'il est installe, sinon tar.exe de Windows 10/11 (libarchive)
        $sevenZip = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($sevenZip) { & $sevenZip x $archive "-o$extrait" -y | Out-Null }
        else { tar.exe -xf $archive -C $extrait }
    }
    if (-not (Test-Path (Join-Path $extrait 'FXServer.exe'))) { throw 'Archive invalide (FXServer.exe absent)' }

    # arret du serveur (FXServer.exe lance depuis ce dossier, txAdmin compris)
    Get-Process FXServer -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($FxDir) } | Stop-Process -Force
    Start-Sleep -Seconds 3

    # sauvegarde puis remplacement
    $sauvegarde = "$FxDir`_ancien"
    if (Test-Path $sauvegarde) { Remove-Item $sauvegarde -Recurse -Force }
    Copy-Item $FxDir $sauvegarde -Recurse
    Copy-Item (Join-Path $extrait '*') $FxDir -Recurse -Force
    Set-Content $fichierVersion "$version"
    Write-Host "FXServer mis a jour : $actuelle -> $version (sauvegarde : $sauvegarde)"
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($Relancer) {
    Write-Host "Relance : $Relancer"
    Start-Process -FilePath $Relancer -WorkingDirectory (Split-Path $Relancer)
}
