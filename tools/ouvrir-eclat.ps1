# Construit la place Éclat et l'ouvre dans une nouvelle fenêtre de Roblox Studio (v0.5.0).
# Usage (depuis le dossier du projet) :  powershell -ExecutionPolicy Bypass -File tools\ouvrir-eclat.ps1
#
# Le fichier construit (build\Eclat.rbxlx) est une copie : il ne touche ni à ta place Refuge ni
# au serveur Rojo du Refuge. Relancer le script après une modification du code pour la tester.
# Pour une partie accélérée : barre de commande (serveur) pendant le test :
#   workspace:SetAttribute("EclatRestart", "42:0.1")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "build\Eclat.rbxlx"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null

$rojo = Join-Path $env:USERPROFILE ".rokit\bin\rojo.exe"
& $rojo build (Join-Path $root "places\eclat.project.json") -o $out
if ($LASTEXITCODE -ne 0) { throw "La construction Rojo a échoué." }

$studio = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe |
	Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $studio) { throw "Roblox Studio introuvable." }
Start-Process -FilePath $studio.FullName -ArgumentList "`"$out`""
Write-Host "Place Éclat ouverte : $out"
