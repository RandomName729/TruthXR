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
& "$tc/clang+llvm-21.1.8-x86_64-pc-windows-msvc/bin/clang-cl.exe" /nologo /std:c++latest /MD /EHsc /O2 /DNOMINMAX /DWIN32_LEAN_AND_MEAN -fuse-ld=lld /I"$root/tools/tests/stubs" @includes /Gy /DFMT_HEADER_ONLY "$root/tools/tests/bounded_induction_test.cpp" "$root/src/shader_recompiler/ir/microinstruction.cpp" "$root/src/shader_recompiler/ir/value.cpp" "$root/src/shader_recompiler/ir/basic_block.cpp" "$root/src/shader_recompiler/ir/opcodes.cpp" "$root/src/shader_recompiler/ir/type.cpp" "$root/src/shader_recompiler/ir/attribute.cpp" "$root/src/shader_recompiler/ir/patch.cpp" "/Fo:$out/" "/Fe:$out/bounded_induction_test.exe"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$out/bounded_induction_test.exe"
exit $LASTEXITCODE


