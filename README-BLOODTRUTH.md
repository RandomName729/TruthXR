# Blood & Truth PC VR prototype

An experimental Windows OpenXR port based on shadPS4, with integration work inherited from AstroQuest and Farpoint. Version 0.1.0 is a development preview, not a finished or reliably playable port.

## Status

Local testing reached gameplay after calibration. Two tracked controllers and corrected hand mapping are implemented. Original, High (1440 x 1632 per eye), and Ultra (8x original pixel count) resolution options are available. Shader resource metadata, depth/stencil handling, GPU memory tracking, audio and VR compatibility fixes are included.

**Known problems:** geometry and textures can disappear or pop in and out, including walls and hands. Loading stalls and crashes remain possible. Higher resolutions are experimental. This release does not claim to resolve these remaining issues. The release executable is rebuilt from the published source; it has not received a fresh headset gameplay test.

## First installation

1. Install the Microsoft Visual C++ 2015-2022 x64 runtime. A Vulkan-capable GPU, Windows x64, an active OpenXR runtime, and a VR headset with two tracked controllers are required.
2. Extract the release ZIP into its own folder.
3. Supply your own complete extracted **Blood & Truth CUSA11108 version 1.00** game, including matching metadata. Put `eboot.bin` at `games/CUSA11108/files/uroot/eboot.bin` relative to the folder containing `Play Blood and Truth.bat`. Keep the complete game directory structure, including `sce_sys/param.sfo`. Alternatively enter another extracted `eboot.bin` path in the launcher. This package does not extract PKG files.
4. Connect the headset, wake both controllers, and open `Play Blood and Truth.bat`. Select resolution and mirror FPS, then start.

No game files, console firmware, saves, shader caches or personal logs are included. Only the exact supported game executable is accepted. Saves are created under `pc-vr/user/home/1000/savedata/`; logs are under `pc-vr/user/log/`. Keep the entire user folder when transferring your own progress between prototype installations.

## Controls

Both controllers provide independent tracked poses and triggers. Trigger maps to Move T; grip to the Move button; lower face button (A/X) to Cross; upper face button (B/Y) to Circle; stick click to Square; stick up to Triangle; stick down to Select. Left menu maps to Start. Both stick clicks recenter. The launcher enables the corrected Move hand order by default; `-OriginalMoveOrder` restores the original order for comparisons.

## Source and building

Base shadPS4 commit: `e9f2c54c207ad6d789d898b3a691aa4b34a59c96`. Clone this repository with `--recurse-submodules`. OpenXR SDK sources and their license are included under `externals/openxr-sdk`. Follow the upstream build instructions with `ENABLE_OPENXR=ON`. `tools/build-prototype.ps1` also supports the original local LLVM/MSVC sysroot layout through `-ToolchainRoot`; it is not an automatic toolchain installer.

Diagnostic capture code is opt-in; do not enable `SHADPS4_CAPTURE_TARGETS` or inject RenderDoc for ordinary play. Earlier capture experiments encountered GPU faults. Pipeline caching is disabled in the supplied configuration because descriptor-binding problems were observed during development.

## Credits and license

Based on [shadPS4](https://github.com/shadps4-emu/shadPS4), [AstroQuest](https://github.com/bigmak94/AstroQuest), and the related [Farpoint port](https://github.com/evertec82/Farpoint). Original copyright and attribution notices are retained. See LICENSE and LICENSES for GPL and third-party notices. This project is not affiliated with Sony or London Studio.
