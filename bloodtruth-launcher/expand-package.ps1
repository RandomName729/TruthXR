$zeroPasscode = '0' * 32
$unpackFolder = '.unpacking'

function Format-Gigabytes([double]$bytes) {
    return ('{0:N1} GB' -f ($bytes / 1GB))
}

function Read-PackageId([string]$path) {
    try {
        $head = New-Object byte[] 128
        $stream = [System.IO.File]::OpenRead($path)
        try { $read = $stream.Read($head, 0, $head.Length) } finally { $stream.Dispose() }
        if ($read -lt $head.Length) { return $null }
        if ($head[0] -ne 0x7F -or $head[1] -ne 0x43 -or $head[2] -ne 0x4E -or $head[3] -ne 0x54) {
            return $null
        }
        return [System.Text.Encoding]::ASCII.GetString($head, 0x40, 36).Trim([char]0)
    } catch {
        return $null
    }
}

function Find-GamePackage([string]$folder) {
    if (-not (Test-Path -LiteralPath $folder)) { return $null }
    return Get-ChildItem -LiteralPath $folder -Filter '*.pkg' -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*\$unpackFolder\*" } |
        Sort-Object Length -Descending |
        Select-Object -First 1
}

function Find-PkgTool([string]$launcherFolder, [string]$root) {
    foreach ($candidate in @((Join-Path $launcherFolder 'pkgtool/PkgTool.exe'),
                             (Join-Path $root 'tools/pkgtool/PkgTool.exe'))) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Get-FreeSpace([string]$path) {
    try {
        $driveRoot = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($path))
        return (New-Object System.IO.DriveInfo($driveRoot)).AvailableFreeSpace
    } catch {
        return -1
    }
}

function Expand-GamePackage {
    param([string]$PackagePath, [string]$GamesFolder, [string]$LauncherFolder, [string]$Root)

    $package = Get-Item -LiteralPath $PackagePath
    $contentId = Read-PackageId $package.FullName
    if ($null -eq $contentId) { throw "$($package.FullName) is not a PlayStation 4 package." }

    $tool = Find-PkgTool $LauncherFolder $Root
    if ($null -eq $tool) { throw 'PkgTool.exe is missing. It belongs in tools/pkgtool.' }

    $serial = 'game'
    if ($contentId -match '[A-Z]{4}[0-9]{5}') { $serial = $Matches[0] }
    $target = Join-Path $GamesFolder $serial

    $needed = $package.Length * 2
    $freeBefore = Get-FreeSpace $target
    if ($freeBefore -ge 0 -and $freeBefore -lt $needed) {
        throw "Unpacking needs about $(Format-Gigabytes $needed) free. Only $(Format-Gigabytes $freeBefore) is available."
    }

    $work = Join-Path $target $unpackFolder
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    try {
        $errorFile = Join-Path $work 'pkgtool-errors.txt'
        $outputFile = Join-Path $work 'pkgtool-output.txt'
        $arguments = 'pkg_extract --passcode ' + $zeroPasscode + ' "' + $package.FullName + '" "' + (Join-Path $work 'files') + '"'
        $process = Start-Process -FilePath $tool -ArgumentList $arguments -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile
        $null = $process.Handle

        try {
            while (-not $process.HasExited) {
                Start-Sleep -Milliseconds 500
                if ($freeBefore -ge 0) {
                    $written = [math]::Max(0, $freeBefore - (Get-FreeSpace $target))
                    Write-Progress -Activity 'Unpacking Blood & Truth' -Status ((Format-Gigabytes $written) + ' unpacked')
                }
            }
        } finally {
            if (-not $process.HasExited) { $process.Kill() }
            Write-Progress -Activity 'Unpacking Blood & Truth' -Completed
        }

        $unpacked = Join-Path $work 'files/uroot'
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $unpacked 'eboot.bin'))) {
            $reason = ''
            if (Test-Path -LiteralPath $errorFile) {
                $reason = @(Get-Content -LiteralPath $errorFile | Where-Object { $_.Trim() -ne '' })[0]
            }
            throw "The package could not be unpacked. Only a package made from a dump of the game works; a package from the PlayStation Store is encrypted. $reason"
        }

        $destination = Join-Path $target 'files/uroot'
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
        Move-Item -LiteralPath $unpacked -Destination $destination

        $leftOut = @('DIGESTS', 'ENTRY_KEYS', 'IMAGE_KEY', 'GENERAL_DIGESTS', 'METAS',
                     'ENTRY_NAMES', 'LICENSE_DAT', 'LICENSE_INFO')
        foreach ($line in (& $tool pkg_listentries $package.FullName 2>$null)) {
            if ($line -notmatch '^0x[0-9A-Fa-f]+\s+0x[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\d+)\s+(?:\d+\s+)?([A-Z0-9_]+)\s*$') { continue }
            $index = $Matches[1]
            $name = $Matches[2]
            if ($leftOut -contains $name -or $name.EndsWith('_DDS')) { continue }
            $file = $name.ToLower().Replace('__', '\')
            $at = $file.LastIndexOf('_')
            if ($at -gt 0) { $file = $file.Substring(0, $at) + '.' + $file.Substring($at + 1) }
            if ($file.StartsWith('playgo_')) { $file = 'playgo-' + $file.Substring(7) }
            $file = Join-Path (Join-Path $destination 'sce_sys') $file
            New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
            & $tool pkg_extractentry --passcode $zeroPasscode $package.FullName $index $file 2>$null | Out-Null
        }

        if (-not (Test-Path -LiteralPath (Join-Path $destination 'sce_sys/param.sfo'))) {
            throw "The package was unpacked, but its game description (param.sfo) could not be read from it."
        }
        return (Join-Path $destination 'eboot.bin')
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
