# Builds the release folder and ZIP for TruthXR from the files in this repository and a
# shadps4.exe you have already built.
#
# Example:
#   powershell -ExecutionPolicy Bypass -File tools\make-release.ps1 -ExePath Build\x64-Clang-Release\shadps4.exe
#
# The result is written next to the repository (not inside it) so it is never committed by accident.
param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string]$Version = '0.1.1',
    [string]$OutDir
)
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $repoRoot -Parent) 'TruthXR-release' }
if (-not (Test-Path -LiteralPath $ExePath)) { throw "The executable was not found: $ExePath" }

# A release should be made from committed files, so the commit ID written to BUILD.txt is true.
$dirty = git -C $repoRoot status --porcelain
if ($dirty) {
    Write-Warning 'There are uncommitted changes. Commit them first, or BUILD.txt will name a commit that does not match the files.'
}
$commit = (git -C $repoRoot rev-parse HEAD).Trim()

$name = "TruthXR-$Version"
$stage = Join-Path $OutDir $name
$zip = Join-Path $OutDir "$name.zip"

# Start from nothing, so files from an earlier release can never end up in this one.
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
$gameFolder = Join-Path $stage 'pc-vr'
New-Item -ItemType Directory -Path $gameFolder -Force | Out-Null

# The launcher scripts and default settings go in pc-vr, next to the emulator.
$launcher = Join-Path $repoRoot 'bloodtruth-launcher'
foreach ($file in @('launch-bloodtruth.ps1', 'expand-package.ps1', 'set-native-resolution.ps1',
                    'config-default.json', 'users-default.json')) {
    Copy-Item -LiteralPath (Join-Path $launcher $file) -Destination $gameFolder
}
Copy-Item -LiteralPath $ExePath -Destination (Join-Path $gameFolder 'shadps4.exe')

# PkgTool is looked for in pc-vr/pkgtool by the launcher.
Copy-Item -LiteralPath (Join-Path $repoRoot 'tools/pkgtool') -Destination (Join-Path $gameFolder 'pkgtool') -Recurse

# Licenses and documentation.
Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination $stage
Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSES') -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $repoRoot 'externals/openxr-sdk/LICENSE') -Destination (Join-Path $stage 'OPENXR-LICENSE')
Copy-Item -LiteralPath (Join-Path $repoRoot 'README.md') -Destination $stage
$notes = Join-Path $repoRoot "RELEASE-NOTES-$Version.md"
if (Test-Path -LiteralPath $notes) { Copy-Item -LiteralPath $notes -Destination $stage }

# The file players double-click.
$batch = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0pc-vr\launch-bloodtruth.ps1`"`r`nif errorlevel 1 pause`r`n"
[System.IO.File]::WriteAllText((Join-Path $stage 'Play Blood and Truth.bat'), $batch, [System.Text.Encoding]::ASCII)

# BUILD.txt records exactly what this release was made from.
$exeHash = (Get-FileHash -LiteralPath (Join-Path $gameFolder 'shadps4.exe') -Algorithm SHA256).Hash.ToLower()
$buildText = @(
    "TruthXR $Version",
    "Source commit: $commit",
    "Upstream base: e9f2c54c207ad6d789d898b3a691aa4b34a59c96",
    "Executable SHA256: $exeHash"
) -join "`r`n"
[System.IO.File]::WriteAllText((Join-Path $stage 'BUILD.txt'), $buildText + "`r`n", [System.Text.Encoding]::ASCII)

Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "Release folder: $stage"
Write-Host "Release ZIP:    $zip"
Write-Host "Executable SHA256: $exeHash"
