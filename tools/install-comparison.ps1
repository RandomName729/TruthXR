param([string]$Destination='D:\BloodTruth\pc-vr-upstream')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$baseline='D:\BloodTruth\pc-vr'
$build=Join-Path $repo 'build-upstream'
if (-not (Test-Path "$build/shadps4.exe")) { throw 'Build executable missing' }
if (Test-Path $Destination) { throw 'Separate destination already exists; inspect before replacing it' }
New-Item -ItemType Directory -Path "$Destination/user" -Force | Out-Null
Copy-Item -LiteralPath "$build/shadps4.exe" -Destination $Destination
Get-ChildItem $build -Filter '*.dll' -File | Copy-Item -Destination $Destination
foreach ($name in @('config.json','users.json','vr_headset_fov.json')) {
 if (Test-Path "$baseline/user/$name") { Copy-Item -LiteralPath "$baseline/user/$name" -Destination "$Destination/user" }
}
foreach ($name in @('home','input_config','sys_modules','fonts')) {
 if (Test-Path "$baseline/user/$name") { Copy-Item -LiteralPath "$baseline/user/$name" -Destination "$Destination/user" -Recurse }
}
$launcher=Get-Content "$baseline/launch-bloodtruth.ps1" -Raw
$launcher=$launcher.Replace('Blood & Truth PC VR - Prototype','Blood & Truth PC VR - New upstream comparison')
Set-Content "$Destination/launch-bloodtruth-upstream.ps1" $launcher
Set-Content "$Destination/Start Blood and Truth Upstream.bat" '@echo off', 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-bloodtruth-upstream.ps1"', 'pause'
$revision=(& git -C $repo rev-parse HEAD).Trim()
$hash=(Get-FileHash "$Destination/shadps4.exe").Hash
Set-Content "$Destination/BUILD.txt" "Blood & Truth upstream comparison prototype`nUpstream commit: $revision`nExecutable SHA256: $hash`nSeparate settings and copied saves in this folder. The original pc-vr install is unchanged.`nGameplay/loading has not yet been verified."
Write-Output "Installed separate comparison at $Destination"
