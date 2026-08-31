# Upstream BongoCat v1.1.0 macOS parity ledger

Reference commit: `44f44bcf2b17b8e16463ad479a477a949d01cc9a`.

`Complete` means the Swift application performs the same macOS-visible job or a tested native equivalent.
`Better equivalent` means the Swift application intentionally replaces a reference workaround with a simpler native behavior.
Platform-specific or distribution-only features that do not apply to this local build are marked `Not applicable`.

## Window and desktop behavior

| Reference behavior | Status | Swift implementation and evidence |
| --- | --- | --- |
| Transparent cat window | Complete | Transparent, borderless, nonactivating `NSPanel` with native Metal content |
| Show, hide, drag, and restore position | Complete | Immediate AppKit actions, saved screen coordinates, lower-right first-launch placement, and off-screen recovery |
| Join Spaces and full-screen apps | Complete | `.canJoinAllSpaces` and `.fullScreenAuxiliary` collection behavior |
| Always on top and pointer click-through | Complete | Native window level and `ignoresMouseEvents` switches |
| Position lock | Better equivalent | One lock disables both moving and resizing while leaving global input reactions active |
| Scale and free edge resize | Complete | 10%-500% scaling, native edge resizing, preserved 612:354 aspect ratio, and persisted derived scale |
| Shift and right-drag resize | Complete | Reference gesture retained alongside native edge resizing |
| Resize feedback | Better equivalent | Metal redraws at the new drawable size without the reference black redraw overlay |
| Opacity and corner radius | Complete | Native panel alpha and continuous clipping |
| Keep window inside a display | Complete | Window frame clamps to the best matching visible screen |
| Hide on pointer hover with delay | Complete | Cancelable delayed work item hides even when the pointer stops moving and restores click handling on exit |
| Model and pointer mirroring | Complete | Independent horizontal model and Cubism pointer transforms |
| Right-click cat menu | Complete | The cat reuses the live localized menu bar actions |

## Input and interaction

| Reference behavior | Status | Swift implementation and evidence |
| --- | --- | --- |
| Input Monitoring permission | Complete | First launch requests listen access and the settings action opens the exact Privacy page |
| Global keyboard press and release | Complete | Listen-only Core Graphics event tap with virtual key and modifier preservation |
| Modifier, function-key fallback, and Caps Lock handling | Complete | Both Command keys, generic modifier assets, F1-F12 to Fn fallback, and 100 ms Caps Lock release |
| Simultaneous hand state | Better equivalent | Each hand keeps its newest overlay and restores an older still-held key after release |
| Left and right mouse buttons | Complete | Independent state drives `ParamMouseLeftDown` and `ParamMouseRightDown` without moving the canvas |
| Pointer movement and smoothing | Complete | Event-driven monitor coordinates with the reference 0.75 damping curve and no permanent pointer poll |
| Ignore pointer movement | Complete | Returns pointer parameters to center without disabling keyboard or mouse-button reactions |
| Gamepad buttons, sticks, and thumb buttons | Complete | Native `GameController` maps all reference button assets and Cubism stick parameters |
| Prevent input modification or collection | Complete | The event tap is listen-only and input values remain in process memory |
| Windows stuck-key auto-release | Not applicable | macOS supplies native key-up events; Caps Lock keeps the reference special handling |

## Model rendering and management

| Reference behavior | Status | Swift implementation and evidence |
| --- | --- | --- |
| Standard, keyboard, and gamepad presets | Complete | The three original model folders and resources are packaged unchanged |
| Real `.moc3` rendering | Complete | Cubism Core and the Native Framework evaluate the real model and render transparent drawables through Metal |
| Pointer, eye, angle, hand, and mouse parameters | Complete | All reference parameter IDs are applied directly to the model |
| Motions, expressions, and motion sound | Complete | Native Framework motion/expression managers plus `AVAudioPlayer` |
| Physics and pose for imported models | Complete | Optional `.physics3.json` and `.pose3.json` files are path-validated, loaded, and allowed to settle before Metal pauses |
| Maximum frame rate and idle suspension | Better equivalent | 0/display through 240 FPS during animation; the Metal view pauses after static and physics work settles |
| Import one or more model directories | Complete | `NSOpenPanel`, SwiftUI file drop, detached validation, and atomic copy through a temporary sibling |
| Validate model references | Better equivalent | Moc, textures, motion, sound, expression, physics, and pose paths must exist inside the model directory |
| Detect model mode and persist catalog | Complete | Hand assets select standard, keyboard, or gamepad mode and stable IDs persist in `UserDefaults` |
| Switch and reveal models | Complete | Selection reloads the renderer immediately and Finder reveal uses `NSWorkspace` |
| Delete custom model with confirmation | Better equivalent | Confirmed deletion moves the folder to macOS Trash for recovery |
| Cover gallery | Complete | Valid `resources/cover.png` previews render in an adaptive native gallery |
| Create, convert, and model gallery links | Not applicable | The source-only native UI exposes model actions implemented inside the app |

## Settings, shortcuts, and lifecycle

| Reference behavior | Status | Swift implementation and evidence |
| --- | --- | --- |
| Settings and persistence | Complete | SwiftUI/AppKit Liquid Glass settings backed by one observable `UserDefaults` owner |
| Menu bar controls | Complete | Localized `NSStatusItem` menu includes window actions, original-project attribution, version, restart, and quit |
| Launch at login | Complete | `SMAppService.mainApp` registration with error recovery |
| Dock and menu bar visibility | Better equivalent | Native activation policy and status visibility always preserve at least one recovery path |
| System, light, and dark appearance | Complete | Immediate application appearance override |
| Five reference languages | Complete | Simplified Chinese, Traditional Chinese, English, Vietnamese, and Brazilian Portuguese |
| Application shortcuts | Complete | Global show/hide, settings, mirror, click-through, and always-on-top commands |
| Motion and expression shortcuts | Complete | Model-scoped assignments use the reference Command-number and modifier tiers |
| Single-instance reopen | Complete | File lock rejects direct duplicate processes and distributed notification opens the existing settings window |
| Restart and quit | Complete | Native helper waits for termination and relaunches the same app path |

## Updates, diagnostics, and privacy

| Reference behavior | Status | Swift implementation and evidence |
| --- | --- | --- |
| Self-update | Not applicable | This local-only build has no independent native release feed or signed native release asset |
| Copy system information | Complete | Clipboard report includes app, macOS, architecture, model, input status, and process information |
| Original project and logs | Complete | Clear upstream attribution plus bounded local diagnostics and Finder reveal |
| Offline cat operation | Complete | Rendering, input, settings, and model management make no network requests; only explicit links use the network |
| No input persistence or transmission | Complete | Key, pointer, mouse, and gamepad values are not logged, saved, or sent |

## Verification contract

The test suite covers defaults, permission routing, event translation, pointer damping, overlay fallbacks, mouse independence, gamepad mapping, real drawable changes, all bundled models, optional Physics/Pose, motions, expressions, custom model import, shortcuts, lifecycle, localization, diagnostics, and window behavior.

The local gate additionally builds and signs the host architecture, checks the running process and Input Monitoring state, and records idle CPU, memory, and app size.
