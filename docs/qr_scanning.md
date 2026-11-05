# QR scanning

## How a frame travels

1. Android: the decoder's native camera (`native/src/android_camera.cpp`) receives the luminance plane directly
   on the camera's thread. Other platforms use Godot's `CameraServer`, with frames copied back from the GPU by
   `texture_get_data_async` (`QrCameraScanner`).
2. `QrDecoder` (GDExtension, `native/src/qr_decoder.cpp`) compares each frame with the previous one. While
   nothing changes it skips decoding, apart from one decode per second as a safety net. After a change it
   decodes every frame until the picture has been still for 3 s, handing the newest frame to two threads:
   - the **fast** thread runs the cheap Standard and Reduced passes on nearly every frame,
   - the **rescue** thread cycles through Magnified, Flattened and Sharpened.
3. The native camera runs at 30 fps while the scene is active and 15 fps while idle. Changes are ignored for 1 s
   after going idle, because the exposure shift from slowing down would otherwise look like motion and wake
   the camera again in an endless loop (measured: about 1990 mW instead of 1150 mW).
4. Reads surface through `QrCameraScanner.code_read`. `scripts/main.gd` turns them into the sound and the
   [card display](cards.md).

The game shows no camera picture, except in debug builds during onboarding, to help aiming a laptop camera.
`scripts/placeholder_scene.gd` stands in for the game's animated scene.

Decoding uses [ZXing-C++](https://github.com/zxing-cpp/zxing-cpp) (Apache 2.0).

**Cameras:** the game starts on the front camera, because the device lies on the table with its screen up.
The button switches between front and back. Cameras that do not say where they are, as on a laptop, are
switched between in the order they are listed, and infrared cameras are avoided at the start.

**Display rule:** the card stays until 5 s after the code was last seen. A code that stays in view plings
once. It plings again after 2 s out of view, and a different code plings immediately.

**False reads:** rescue reads must be repeated on another frame. The benchmark caught the Flattened and
Sharpened filters decoding garbage from damaged images twice, and no other pass has done so.

## Building

Prebuilt libraries are in `addons/qr_scanner/bin`. After changing `native/`:

    native/build.sh            # or: native/build.sh linux | android

This needs CMake, Python 3 and the Android NDK. `ANDROID_NDK_ROOT` overrides the NDK from `~/Android/Sdk`.

Android APK: `godot --headless --export-debug Android <path>.apk`

iOS is not set up: the extension has to be built on a Mac, added to `qr_scanner.gdextension`, and the
export needs a camera usage description. It would use Godot's camera feed, as the native camera is Android only.

## Testing

    godot --headless -s tests/test_decoder.gd      # decoder only
    godot --headless -s tests/test_cards.gd        # card database
    godot --headless -s tests/test_party.gd        # saving and loading the party
    godot res://tests/test_game.tscn               # the game with a fake camera; opens a window
    godot res://tests/test_onboarding.tscn         # the onboarding with a fake camera; opens a window

The game test runs Godot's camera feed path. The native camera can only be tested on an Android device or emulator.

The emulator can use a file as its camera, which runs the whole Android path, including the native camera. It shows only a zoomed part
of the picture, so keep the code large and centred:

    emulator -avd <name> -read-only -camera-back videofile:<code>.mp4

The export preset is ARM64 only, so for an x86_64 emulator first run
`QR_ANDROID_ABIS="arm64-v8a x86_64" native/build.sh android` and enable `architectures/x86_64`.

## Reliability benchmark

`native/tools/qr_bench.cpp` renders codes into synthetic frames with clutter, perspective, lighting, blur
and noise:

    cmake -S native -B /tmp/qrb -DQR_BUILD_BENCH=ON -DQR_BUILD_EXTENSION=OFF
    cmake --build /tmp/qrb -j
    /tmp/qrb/qr_bench 60 1280 720
    /tmp/qrb/qr_bench --false-positives 3000 1280 720 1000

Read rate per single frame in % (1280x720, 60 frames per condition, desktop CPU). "Any" means at least one
pass read that frame. Geometry changes on every frame here, while real video repeats similar frames, so
the chance of a read over several frames is lower than independent attempts would suggest.

| Condition                     | Standard | Any |
|-------------------------------|---------:|----:|
| Baseline, any rotation        |      100 | 100 |
| Tilt 50°                      |      100 | 100 |
| Tilt 65°                      |       80 |  83 |
| Modules of 3 px / 2 px        | 100 / 97 | 100 / 100 |
| Modules of 1.5 px             |        2 |   3 |
| Blur sigma 1.5 / 3 / 5 px     | 100 / 65 / 48 | 100 / 78 / 58 |
| Motion blur 12 px             |       98 | 100 |
| Very dim and noisy            |       98 | 100 |
| Low contrast, inverted        |      100 | 100 |
| Hard shadow across the code   |       50 |  93 |
| Glare / overexposed glare     |  100 / 0 | 100 / 0 |
| Mix: tilt, blur, dim, noise   |       65 |  88 |

Average cost per frame: Standard 1.0 ms, Reduced 0.2 ms, Magnified 4.6 ms, Flattened 3.7 ms, Sharpened 3.7 ms.

False positives: none in 12,000 code-free frames.

## Battery

Applied settings: 30 fps rendering (`application/run/max_fps`), 720p camera (`MAX_CAMERA_PIXELS`), change
detection, native camera at 15 fps while idle (`NATIVE_IDLE_FPS`), and no camera picture.

### Current state: no camera picture, nothing moving

Pixel 8 flat with the screen up, front camera, dark background with 12 moving dots, brightness 100/255.
Each run is 30 s of idle power, with no code in view:

| Configuration                                 | Total mW | CPU | Memory | Display |
|-----------------------------------------------|---------:|----:|-------:|--------:|
| Godot camera, change detection                |     1311 | 396 |    228 |     167 |
| Native camera, 720p, 30 fps                   |     1236 | 318 |    222 |     166 |
| **Native camera, 720p, 15 fps while idle**    |     1153 | 258 |    201 |     166 |
| Native camera, 480p, 30 fps                   |     1198 | 301 |    213 |     166 |
| Native camera, 480p, 15 fps while idle        |     1074 | 235 |    180 |     166 |
| Native camera, 240p, 15 fps while idle        |     1091 | 247 |    180 |     166 |
| Camera off                                    |      711 | 112 |     79 |     167 |

Figures are averages where a configuration ran twice. Repeat runs differed by 5 to 20 mW. The 240p result shows
that reopening the camera at a lower resolution while idle would not pay off. A real game scene will change the
GPU and display numbers.

### Earlier: with camera picture, nothing moving

Pixel 8 flat with the screen up, front camera, 720p, 30 fps, brightness 100/255:

| Configuration                            | Total mW | CPU | Display |
|------------------------------------------|---------:|----:|--------:|
| No change detection, 15 scans/s          |     1660 | 518 |     305 |
| Change detection, 5 / 10 / 15 checks/s   | 1548 / 1505 / 1506 | 414 / 379 / 376 | 310 / 309 / 314 |
| Camera on, no frames copied at all       |     1470 | 343 |     313 |
| Change detection, 480p                   |     1427 | 343 |     308 |
| Change detection, 15 fps                 |     1465 | 382 |     311 |
| Change detection, black screen, no HUD   |     1259 | 363 |     143 |

One more run of the 10 checks/s setting read 1776 mW. It was the first run with change detection and its app
CPU was about twice that of its neighbours, so the picture was probably not idle yet. It is left out above.

Read speed: 10 of 10 passes read, 0.4 to 3.3 s (median about 1.3 s) from the first change in the picture to
the read. This includes the time the hand takes to bring the code into place, so it is an upper limit for
the scanner itself.

### Hand-held scene, every frame decoded

Measured on a Pixel 8 with the on-device power rails (perfetto `android.power`): 30 s per run, normally lit
indoor scene, brightness 100/255, no code in view. Rail sums leave out some of the phone, such as power
conversion losses, so real battery drain is somewhat higher.

| Configuration                  | Total mW | CPU | Memory | Display |
|--------------------------------|---------:|----:|-------:|--------:|
| Uncapped, 1080p, every frame   |     2982 | 1354 |   513 |     278 |
| 30 fps, 1080p, every frame     |     2746 | 1221 |   462 |     277 |
| 30 fps, 720p, every frame      |     1963 |  729 |   318 |     270 |
| **30 fps, 720p, 15 scans/s**   |     1847 |  643 |   298 |     262 |
| Same, rescue on every 3rd scan |     1777 |  570 |   282 |     271 |
| Same, no decoding at all       |     1611 |  457 |   262 |     274 |
| Camera off, grey screen        |      769 |  112 |    78 |     220 |

The bold row is the average of two runs, which differed by 18 mW.

Brightness on the applied settings: 1746 mW at 20/255, 2144 mW at 255/255. Screen power also depends on
how bright the picture is.

Not worth it, per these measurements:
- 15 fps instead of 30 saved about 70 mW in a dark scene, not repeated in a lit one.
- Hiding the preview saved nothing measurable in a dark scene, where a black picture costs little anyway.
- Rendering is not the bottleneck: the GPU draws about 40 mW.

To measure, run `perfetto` on the device with `android_power_config { collect_power_rails: true }` and pass the
trace to `native/tools/power_rails.py`. Empty traces happen now and then, so repeat any run that reports nothing.
