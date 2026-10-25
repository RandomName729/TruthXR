param([Parameter(Mandatory=$true)][int]$GameProcessId, [Parameter(Mandatory=$true)][string]$InstallPath, [ValidateSet('High','Ultra8x')][string]$Resolution='High', [switch]$Once)
$ErrorActionPreference='Stop'
$report=Join-Path $InstallPath 'user/log/native-resolution.log'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativeResolutionMemory {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int id);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] buffer, UIntPtr size, out UIntPtr count);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool WriteProcessMemory(IntPtr process, IntPtr address, byte[] buffer, UIntPtr size, out UIntPtr count);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
}
'@
$renderScale=[float]$(if ($Resolution -eq 'Ultra8x') { [Math]::Sqrt(8) } else { 1.5 })
$handle=[IntPtr]::Zero
function Read-Memory([long]$Address,[int]$Size) {
 $bytes=New-Object byte[] $Size; $count=[UIntPtr]::Zero
 if (-not [NativeResolutionMemory]::ReadProcessMemory($handle,[IntPtr]$Address,$bytes,[UIntPtr]$Size,[ref]$count) -or $count.ToUInt64() -ne $Size) { throw 'Resolution settings are not readable yet.' }
 return ,$bytes
}
function Read-Pointer([long]$Address) { [BitConverter]::ToInt64((Read-Memory $Address 8),0) }
function Write-Memory([long]$Address,[byte[]]$Bytes) {
 $count=[UIntPtr]::Zero
 if (-not [NativeResolutionMemory]::WriteProcessMemory($handle,[IntPtr]$Address,$Bytes,[UIntPtr]$Bytes.Length,[ref]$count) -or $count.ToUInt64() -ne $Bytes.Length) { throw 'Could not apply native resolution.' }
}
try {
 $game=Get-Process -Id $GameProcessId
 if ([IO.Path]::GetFullPath($game.Path) -ne [IO.Path]::GetFullPath((Join-Path $InstallPath 'shadps4.exe'))) { throw 'Unexpected emulator path.' }
 $handle=[NativeResolutionMemory]::OpenProcess(0x38,$false,$GameProcessId)
 if ($handle -eq [IntPtr]::Zero) { throw 'Cannot access the emulator graphics settings.' }
 $base=0L; $verified=$false; $lastSettings=0L; $attempts=0
 while (-not $game.HasExited) {
  $attempts++
  try {
   if (-not $base) {
    $log=Get-Item -LiteralPath (Join-Path $InstallPath 'user/log/shad_log.txt')
    if ($log.LastWriteTime -lt $game.StartTime) { throw 'Waiting for the new game log.' }
    $line=Get-Content -LiteralPath $log.FullName -TotalCount 150 | Where-Object { $_ -match 'Loading module eboot\.bin to 0x([0-9a-fA-F]+)' } | Select-Object -First 1
    if (-not $line -or $line -notmatch 'Loading module eboot\.bin to 0x([0-9a-fA-F]+)') { throw 'Waiting for the game module.' }
    $base=[Convert]::ToInt64($Matches[1],16)
   }
   if (-not $verified) {
    $anchors=@{
     0x13f02e1='80-BB-A5-00-00-00-00-49-8B-45-40-0F-95-C2-80-3D'
     0x13f039e='C5-FA-10-83-D8-00-00-00-C5-FA-10-50-48-C5-FA-10'
     0x13a8673='41-8B-46-44-49-8D-4E-4C-89-05-EB-0D-67-01-48-8B'
     0x13efa48='C5-FA-10-15-20-9A-62-01-C5-FA-10-25-DC-F1-E2-00'
    }
    foreach ($anchor in $anchors.GetEnumerator()) {
     if ([BitConverter]::ToString((Read-Memory ($base+$anchor.Key) 16)) -ne $anchor.Value) { throw 'Unsupported game code; refusing resolution changes.' }
    }
    $verified=$true
   }
   $manager=Read-Pointer ($base+0x2cf5bf8)
   if ($manager -le 0) { throw 'Waiting for render settings.' }
   $index=[BitConverter]::ToInt32((Read-Memory ($manager+0x100) 4),0)
   if ($index -lt -1 -or $index -ge 16) { throw 'Render settings are not initialized.' }
   $settings=if ($index -ge 0) { (Read-Pointer ($manager+0x80+8*$index))+0x80 } else { $manager+0x260 }
   $adaptive=Read-Memory ($settings+0xa5) 1
   $scales=Read-Memory ($settings+0xd8) 12
   if ($adaptive[0] -gt 1) { throw 'Unexpected adaptive-resolution value.' }
   foreach ($offset in @(0,4,8)) {
    $value=[BitConverter]::ToSingle($scales,$offset)
    if ([float]::IsNaN($value) -or $value -lt 0 -or $value -gt 3) { throw 'Unexpected native render scale.' }
   }
   $desired=[BitConverter]::GetBytes($renderScale)
   if ($adaptive[0] -ne 0) { Write-Memory ($settings+0xa5) ([byte[]]@(0)) }
   foreach ($offset in @(0,4,8)) {
    if ([BitConverter]::ToSingle($scales,$offset) -ne $renderScale) { Write-Memory ($settings+0xd8+$offset) $desired }
   }
   if ($lastSettings -ne $settings) {
    "$(Get-Date -Format o) Applied $Resolution ($renderScale per axis) native stereo resolution, adaptive reduction disabled. PID=$GameProcessId settings=$settings" | Add-Content -LiteralPath $report
    $lastSettings=$settings
   }
   if ($Once) { break }
  } catch {
   if ($_.Exception.Message -like 'Unsupported game code*' -or $attempts -ge 120 -and -not $lastSettings -or $Once) { throw }
  }
  Start-Sleep -Milliseconds 1000
  $game.Refresh()
 }
} catch {
 "$(Get-Date -Format o) Resolution helper stopped: $($_.Exception.Message)" | Add-Content -LiteralPath $report
 throw
} finally {
 if ($handle -ne [IntPtr]::Zero) { [void][NativeResolutionMemory]::CloseHandle($handle) }
}

