param([string]$ToolchainRoot)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (-not $ToolchainRoot) { $ToolchainRoot=Join-Path $root ../toolchain }
$tc=(Resolve-Path $ToolchainRoot).Path
$crt="$tc/winsysroot/VC/Tools/MSVC/14.44.17.14"
$sdk="$tc/winsysroot/Windows Kits/10"
$env:INCLUDE="$crt/include;$sdk/Include/10.0.26100/ucrt;$sdk/Include/10.0.26100/um;$sdk/Include/10.0.26100/shared"
$env:LIB="$crt/lib/x64;$sdk/Lib/10.0.26100/um/x64;$sdk/Lib/10.0.26100/ucrt/x64"
$command=(& "$tc/python-tools/bin/ninja.exe" -C "$root/build-upstream" -t commands | Select-String ' -c -- .*image_info.cpp$').Line
if (-not $command) { throw 'Configure the build first.' }
$includes=@([regex]::Matches($command,'-(?:I|imsvc)(\S+)') | ForEach-Object { '/I'+$_.Groups[1].Value })
$out="$root/build/compat-tests"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($name in @('move_controllers_test','recalibration_test','overlay_projection_test','virtual_camera_frame_test','bloodtruth_memory_test')) {
    $stub=@(); if ($name -eq 'move_controllers_test') { $stub=@("/I$root/tools/tests/stubs") }
    & "$tc/clang+llvm-21.1.8-x86_64-pc-windows-msvc/bin/clang-cl.exe" /nologo /std:c++latest /MD /EHsc /O2 /DNOMINMAX /DWIN32_LEAN_AND_MEAN -fuse-ld=lld @stub @includes "$root/tools/tests/$name.cpp" "/Fo:$out/" "/Fe:$out/$name.exe"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & "$out/$name.exe"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "$name passed"
}
exit 0
