# Experimental native iOS port

Intended compatibility target: iPhone 12 (A14) and later, ARM64, iOS 18 or newer. This is a target to validate, not a claim that every listed device has passed physical-device QA. This is a source port of
LoreanXavier/pt-pc, not a PS4 emulator or binary recompiler. The original project's
C++ game implementation is compiled ahead of time. Lua 5.1 is interpreted;
Whisper/ggml CPU code is statically linked. There is no CPU JIT or JIT fallback.
MoltenVK translates Vulkan shaders to Metal using the normal GPU driver APIs.

Build on an Apple silicon Mac with Xcode, CMake, Ninja and the Vulkan headers/glslc
(`brew install cmake ninja vulkan-headers shaderc vulkan-loader`):

```sh
./script/build_ios.sh
python3 script/audit_nojit.py build/ios-device/PT.app
```

The script downloads MoltenVK 1.4.2 for **iOS** and checks its published SHA-256.
Only its device framework is bundled. It never links the host's macOS Vulkan
loader into the application. Models and third-party dependencies follow the
upstream build's pinned downloads. Output: `dist/PT-iOS-unsigned.ipa`.
The IPA must be signed for the destination device before installation; it is not
an App Store package. No automatic device installation is performed.

On first launch select the folder from your own extracted US P.T. dump
(CUSA01127) containing these three non-empty files:

- `chunk1.psarc`
- `texture.qar`
- `pathid_list_ps4.bin`

Import copies the files into the app's Documents/Game folder via a staging
folder, leaving the selected source untouched. A failed import can be retried.
Documents/P.T. contains settings, saves and logs and is exposed in Files.
The app includes neither the original game archives nor a downloader for them.
The importer checks names and sizes; the engine performs the archive parsing.

Touch controls use an SDL virtual gamepad: left stick moves, right stick looks,
● is action/confirm, BACK cancels, ZOOM holds the right-stick button (R3), Ⅱ pauses.
Sticks/buttons release when the app loses focus. Existing physical gamepad input
is retained. Touch layout and controller interaction still require device QA.

Desktop update checks are disabled at launch. External-process features cannot
spawn helpers on iOS. VR, DLSS/FSR and enhanced-texture helper downloads are not
part of this build. The original renderer still checks Vulkan feature support and
can reject unsupported configurations; successful linking is not gameplay proof.


## iOS memory and texture policy

The iOS build uses one adaptive texture policy for every supported device generation.
It samples the app's current physical-memory headroom when a texture is created; it
does not maintain separate A14/A15 and low-RAM code paths or assume that advertised
device RAM is available to the process. Lower headroom selects a smaller base mip
before GPU image and staging allocations. When the GPU cannot allocate an image,
the existing fallback releases enhanced textures and retries with lower mip levels.
BC subresources are decoded one at a time directly into the upload staging buffer,
using a reused CPU scratch allocation; the build does not retain a full second
RGBA copy of every compressed texture. Oversized single staging uploads are
submitted synchronously instead of exceeding the 24 MiB deferred-upload budget.

On iOS, predictive whole-stage prefetch and texture decode-ahead are disabled so
the active stage is not competing with a second stage's decoded CPU assets. BC
FTEX formats are routed through the renderer's capability-aware upload path; when
the selected GPU cannot sample BC formats, the subresources are decoded to RGBA8.
Deferred Vulkan upload staging is capped at 24 MiB on iOS.

On every iOS launch, desktop settings are normalised before renderer creation:
Vulkan is selected, HDR and VR are disabled, and desktop DLSS/FSR/frame-generation
or neural-rendering choices are cleared. Graphics settings loaded from an older
desktop configuration are also clamped to a mobile-safe profile: ray tracing and
enhanced texture replacements are off, shadows are limited to the low tier,
anisotropy is capped at 8x, and expensive post effects are disabled. The FPS
setting defaults to 60 Hz, is limited to 60 Hz with VSync enabled, and thermal
pressure or Low Power Mode reduces it to 30 Hz.

An iOS memory-warning notification also invokes the same cleanup path as sampled
process pressure. After optional texture copies and unreferenced stage models are
released, the 3D render extent is reduced by 20% if pressure remains. The UI and
presentation surface stay at native resolution, and the renderer rebuilds its
scene targets at the smaller size on the next frame. Mesh cache reclamation waits
for the GPU once, then destroys the batch without repeating a device-idle wait for
each mesh.

These measures reduce avoidable CPU/GPU memory overlap and allocation spikes. They
do not guarantee a fixed frame rate or prevent every jetsam termination: Apple
GPU resources use the device's unified memory, and sustained GPU load, thermal
throttling, shader compilation, scene complexity and the OS process budget still
affect performance. Physical-device gameplay testing remains required.

## Validation

See `build/ios-validation.json` and `build/build-ios.log` for local evidence when
present. The NoJIT audit is a static import/segment check, not a complete runtime
proof. Without original game archives we can validate the build and import UI,
but not corridor rendering, puzzle progression, memory pressure, audio/voice,
performance or stability on a physical iPhone.

The independent `tests/ios-import` Xcode project compiles the **same production
import controller** into a UI smoke harness. It contains no game renderer and is
not the IPA. Generate with `xcodegen generate --spec tests/ios-import/project.yml`
and run scheme `PTImportSmoke` on a simulator for first-run UI checks. This does
not validate the SDL bootstrap handoff or actual game execution.

Local result (2026-10-18): device application built and packaged successfully;
both PT and MoltenVK are iOS arm64, and the static NoJIT audit passed. The
production importer controller was launched in its separate smoke harness on
iOS 18.6 Simulator; first-screen appearance was captured in
`build/import-first-run.jpg`. Folder-picker interaction, successful archive
import, SDL-to-UIKit handoff and gameplay remain unverified.

## Private build with the supplied game archives

Set `PT_IOS_GAME_DIR` to the extracted folder when running `script/build_ios.sh`.
The CMake cache option with the same name packages only the three required data
files under `PT.app/Game`; no PS4 executable is shipped. The application prefers
a complete Documents/Game import, then the bundled Game folder, and otherwise
opens the importer. Saves/settings remain in writable Documents/P.T.

Output with resources: `dist/PT-iOS-with-game-unsigned.ipa`. Clearing the option
removes bundled archives at the next relink for the engine-only package.
`script/validate_game.py <folder>` checks all 12 core FPK packages, QAR bounds and
path names. `dist/game-validation.json` records the supplied US archives and the
comparison of their SHA-256 hashes with the IPA entries. The supplied Russian
patch is retained separately and has not been applied.

With the supplied archives, the macOS ARM64 engine also completed a 600-frame
headless game run (floor f010, step 13) and rendered a 960×540 frame through
MoltenVK on Apple M1 Pro, exiting normally with code 0. No Lua errors occurred in
that game run. This is a data/engine check on Mac, not an iPhone test.
The separate upstream `--script-test` diagnostic ran 91 chunks and failed 6:
its RegisterStubApi environment lacks APIs such as UiDaemon and
GrPluginDepthOfField. That diagnostic is **not** recorded as passing.
Logs and the captured frame are under `build/runtime-macos/`.

## Device report and touch fix (2026-10-18)

The user reports that the private resource-bearing IPA runs P.T. on their iPhone
and that a DualShock 4 works. The original touch overlay was absent. SDL's UIKit
backend replaces the root controller view when its Metal/Vulkan surface is
created, after the original overlay attachment point. Version 0.1.1/build 2
reattaches the controls to the current root view after renderer creation and at
event-pump boundaries, keeping one virtual gamepad across view replacements.
The original working IPA is retained; the updated package is named
`PT-iOS-touch-v0.1.1-unsigned.ipa`. Physical-device confirmation of this touch fix
is still needed.

Version 0.1.2/build 3 additionally opts into ProMotion via
CADisableMinimumFrameDurationOnPhone and caps normal gameplay at 120 FPS (a lower
user-selected limit is respected). NSProcessInfo thermal/power state is sampled
once per second. Serious/critical thermal state or Low Power Mode lowers the cap
to 30. Recovery requires nominal thermal state and at least 60 seconds since the
last hot/low-power observation; this prevents rapid cap oscillation. This is a
load-control policy, not evidence of sustained 120 FPS or measured heat reduction.
The physical device's FPS/temperature still need to be measured.

`tests/ios-touch` exercises the production overlay with SDL's actual UIKit/Metal
view replacement in an iOS 18.6 simulator. It passed reattachment, recognition of
one virtual gamepad, button press/release readback, focus-loss release and Metal
surface removal. See `build/touch-regression.log` and screenshot. The standalone
thermal policy test covers cap bounds, lower user limits, serious/critical heat,
Low Power Mode and recovery hysteresis. This does not replace phone touch testing.
Latest package: `dist/PT-iOS-touch-promotion-v0.1.2-unsigned.ipa`.

## Version 0.1.3: native display and MetalFX Temporal

The iOS target now builds the existing temporal MetalFX backend and links the
system MetalFX framework. Reactive-mask availability checks include iOS 17.4.
Upscaling remains opt-in: Scaling/Upscaling > Apple MetalFX > Quality (or another
quality preset). Existing saved upscaler selection is preserved. This adds
**temporal upscaling**, not frame generation, and needs no CPU JIT.

The application creates its iOS window fullscreen and normalizes saved desktop
window modes to fullscreen on load. Desktop mode and output-resolution rows are
read-only on iOS; they report native fullscreen output. Their setters reject
programmatic changes too. Rendering scale is controlled through upscaling quality.
The production fullscreen policy restored native drawable dimensions after a
windowed resize in the SDL UIKit/Metal simulator regression harness. This prevents
the unsupported desktop-settings path that caused a partially sized image.

Validation: iOS ARM64 build and NoJIT audit passed; MetalFX Temporal processed
591 successive rendered frames on Mac M1 Pro (640×360 -> 960×540, Quality), with
normal exit code 0. See `build/runtime-macos/metalfx-warm.log`. This establishes
the interoperability path on Mac, not performance or compatibility on iPhone.
Full-screen recovery and touch regression log: `build/display-regression.log`.
Physical iPhone confirmation remains needed for both this fix and MetalFX.
Reference: https://developer.apple.com/documentation/metalfx/mtlfxtemporalscalerdescriptor

Latest private IPA: `dist/PT-iOS-MetalFX-v0.1.3-unsigned.ipa`.

## Version 0.1.4: selectable render resolution restored

The native-output-only change in 0.1.3 increased the scene/postprocessing target
size and the user reported substantially worse performance. That policy is
superseded: iOS keeps its fullscreen presentation surface but the resolution row
is active again. Presets include 854×480, 1280×720, 1600×900, 1920×1080, the native
display size and the current saved selection. The setter updates the selected
render extent without resizing the UIKit window or changing desktop modes.
The selected extent is used for initial renderer targets and every game frame.
The renderer's existing fit/composite path presents it to the native surface;
aspect ratios that differ from the display are fitted without stretching.
MetalFX scales its input to the selected size, then the final image is presented.

Suggested comparison for the reported regression: select 1600×900, first with
upscaling off, then compare MetalFX if desired. MetalFX is not guaranteed faster
at every resolution. The Mac runtime check completed 600 game frames / 591
rendered frames with MetalFX Performance at 800×450 -> 1600×900, exit 0.
See `build/runtime-macos/resolution-1600.log`. iOS ARM64 build, NoJIT audit and IPA
CRC checks passed. Actual iPhone frame rate and resolution switching require
user verification.
Latest private IPA: `dist/PT-iOS-resolution-v0.1.4-unsigned.ipa`.


## Version 0.1.5: display aspect and touch gamepad

The resolution menu now derives its presets from the actual fullscreen drawable
aspect instead of offering fixed16:9 extents. A saved width is retained (bounded
by the native width), and the height is recalculated on startup. For a 2622x1206
drawable,1600 pixels wide gives1600x736; no native-resolution scene rendering is
required. Presentation fills the drawable, absorbing the subpixel aspect error
from even-height rounding. MetalFX and the existing 120 FPS/thermal policy remain.

The overlay already used an SDL virtual gamepad in earlier versions. This build
identifies that pad as a virtual Xbox controller and disables SDL's touch-to-mouse
and mouse-to-touch synthesis before startup. The right stick uses a radial 6% dead
zone and an exponential fine-control curve, with a 65%maximum turn-rate input.
Only the virtual touch pad bypasses the engine's additional hardware-stick dead
zone; physical controllers retain their own response and settings.

Each stick owns its active UITouch. Release/cancellation clears that ownership
and the axes, preventing late move events from restoring stale input. Focus loss,
background/foreground, orientation/window transitions, and SDL root-view replacement
reset sticks and buttons. The buttons use A/B labels; action, back, zoom and pause
retain their original gamepad bindings.

Validation: device ARM64 application built; static NoJIT audit passed. The actual
shared policy header passed host tests covering drawable aspect across four
screen sizes, native/clamped extents, radial dead zone, monotonic look response,
diagonal magnitude and invalid input. The UIKit regression harness was extended
for Xbox identity, disabled mouse synthesis, reset, cancellation and drag-out.
Its new runtime cases have not been run: the simulator is currently shut down.
Physical iPhone multi-touch behavior and camera comfort remain to be checked.
Private package:dist/PT-iOS-fullscreen-touch-v0.1.5-unsigned.ipa (sign for the phone).


## Version 0.1.6: MetalFX submission and fullscreen/UI repair

User reports severe FPS loss with MetalFX and provides screenshots showing
squashed menu geometry and a partial UIKit/render viewport. Confirmed code issues:
EndFrame blocked the CPU on MetalFX completion every frame; the resolution setter
could still resize the native window if another settings path reset fullscreen.
The limiter also added a whole sleep period after an already overdue frame.

EndFrame now submits its resume command buffer with an explicit timeline wait at
ALL_COMMANDS for MetalFX completion. The Metal completion callback still signals
the Vulkan timeline after finishing; the renderer no longer waits on the CPU.
The resolution setter never resizes the iOS window, regardless of saved mode.
Presentation/UI/capture images use native swapchain dimensions independently of
the selected scene resolution. Overlay attachment repairs UIKit window/root and
control frames if they drift. The FPS cap no longer adds a full period to late
frames. The120FPS ceiling, thermal policy, touch response and NoCPUJIT remain.

Runtime evidence: Mac ARM64/MoltenVK run completed600 game frames,591 rendered
MetalFX Performance frames at800x368 ->1600x736, normal exit0. Last-run log:
build/runtime-macos/metalfx-sync-1600.log. This verifies the asynchronous dependency
path on Mac; it is not a controlled performance comparison or iPhone proof.
Actual phone FPS and the supplied menu/viewport cases remain to be verified.
Private package:dist/PT-iOS-MetalFX-fullscreen-v0.1.6-unsigned.ipa.


## iOS GPU compatibility and memory fallback (2026-11-08)

The Vulkan renderer runs through MoltenVK on top of Metal. BC texture compression
is optional: when the Metal GPU does not expose all BC formats used by P.T., FTEX
BC1/2/3/5/7 data is decoded to RGBA8 during upload. BC7 decoding uses the full
mode decoder from the already-pinned `bc7enc_rdo` dependency; BC5 preserves its
R/G normal channels. The decode is parallelized by block rows and writes one mip
at a time into the upload staging buffer to avoid retaining a second full set of
expanded CPU textures. Devices that support all required BC formats keep the native
compressed upload path.

The bindless texture layout uses sampled-image arrays plus one shared sampler,
not thousands of combined-image-sampler descriptors. MoltenVK's Tier 2 argument-buffer
limits allow hundreds of thousands of sampled images but only about 2,048 sampler
descriptors per stage. A combined-image-sampler array consumes both limits; splitting
the image array from its single shared sampler avoids that sampler cap. The image-array
size is clamped to the physical device's update-after-bind limits. Vulkan features
that the shaders do not use are no longer enabled as hard requirements; BC support
and anisotropic filtering are optional. Runtime arrays, non-uniform sampled-image
indexing, update-after-bind, timeline semaphores, dynamic rendering, synchronization2
and shader clip distance remain required by the current renderer.

On iOS, `os_proc_available_memory()` supplies the app's remaining process-memory
allocation budget (not total device free RAM) for the existing memory-pressure guard. Under pressure the game stops stage
prefetching, releases optional enhanced textures, and reduces the largest mip level
of subsequent large texture uploads. Full archive read-ahead is disabled by default
on iOS so launch does not populate more than a gigabyte of file cache before gameplay;
`PT_PREFETCH=1` opts back in for diagnostics.

These are compatibility and memory safeguards, not proof of flawless gameplay.
The iPhone 12/A14 and iPhone 13/A15 still require a real-device build and tests for
startup, texture correctness (especially BC5/BC7), scene transitions, memory headroom,
thermal behavior and sustained frame rate. The current development environment
cannot sign or run this IPA on those physical devices.
