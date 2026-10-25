param([string]$ToolchainRoot, [string]$SourcePath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (-not $ToolchainRoot) { $ToolchainRoot=Join-Path $root ../toolchain }
$tc=(Resolve-Path $ToolchainRoot).Path
$crt="$tc/winsysroot/VC/Tools/MSVC/14.44.17.14"
$sdk="$tc/winsysroot/Windows Kits/10"
$env:INCLUDE="$crt/include;$sdk/Include/10.0.26100/ucrt;$sdk/Include/10.0.26100/um;$sdk/Include/10.0.26100/shared"
$env:LIB="$crt/lib/x64;$sdk/Lib/10.0.26100/um/x64;$sdk/Lib/10.0.26100/ucrt/x64"
$clang="$tc/clang+llvm-21.1.8-x86_64-pc-windows-msvc/bin/clang-cl.exe"
$command=(& "$tc/python-tools/bin/ninja.exe" -C "$root/build-upstream" -t commands | Select-String ' -c -- .*image_info.cpp$').Line
if (-not $command) { throw 'Configure/build Blood & Truth before running this test.' }
$includes=@([regex]::Matches($command,'-(?:I|imsvc)(\S+)') | ForEach-Object { '/I'+$_.Groups[1].Value })
$out="$root/build/compat-tests"
New-Item -ItemType Directory -Force $out | Out-Null
# Compile the actual production constructor without pulling in unrelated methods
# and the entire emulator. Do not maintain a separate implementation in this test.
if (-not $SourcePath) { $SourcePath="$root/src/video_core/texture_cache/image_info.cpp" }
$source=Get-Content $SourcePath -Raw
$ctorStart=$source.IndexOf('ImageInfo::ImageInfo(const AmdGpu::DepthBuffer&')
$ctorEnd=$source.IndexOf('ImageInfo::ImageInfo(const AmdGpu::Image&', $ctorStart)
$isolated='#include "video_core/renderer_vulkan/liverpool_to_vk.h"' + "`n" + '#include "video_core/texture_cache/image_info.h"' + "`n" + '#include "video_core/texture_cache/tile.h"' + "`nnamespace VideoCore { using namespace Vulkan;`n" + $source.Substring($ctorStart,$ctorEnd-$ctorStart) + "`n}"
Set-Content "$out/stencil_target_production.cpp" $isolated
& $clang /nologo /FIbit /std:c++latest /MD /EHsc /O2 /Gy /clang:-flto=thin /DFMT_HEADER_ONLY /DNOMINMAX /DWIN32_LEAN_AND_MEAN -fuse-ld=lld "/I$root/tools/tests/stubs" @includes "$root/tools/tests/stencil_target_test.cpp" "$root/src/video_core/amdgpu/tiling.cpp" "$out/stencil_target_production.cpp" "/Fo:$out/" "/Fe:$out/stencil_target_test.exe" /link /OPT:REF
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$out/stencil_target_test.exe"
exit $LASTEXITCODE
