# Piano Tutor

A native app for Mac, iPad and iPhone for learning to play the keyboard. Plug in a USB-MIDI keyboard
(it was written with the Casio CT-S300 in mind), follow the lessons, and the app
listens to what you play.

- **Course** – 8 units and 27 short lessons, from finding Middle C to playing a tune with left-hand chords.
- **Practice mode** – the music waits until you press the right keys.
- **In-time mode** – a metronome counts you in, the staff scrolls, and every note is judged as on the beat, early, late or missed.
- **Song library** – 18 traditional and classical tunes, playable with either hand or both, at 60%, 80% or full speed.
- **Free play** – see the name and staff position of whatever you play.
- **61-key on-screen keyboard** matching the CT-S300 (C2–C7), with finger numbers and key hints. On iPhone and iPad it is multi-touch, and on small screens it shows the section of the keyboard the music needs.

Written in Swift with SwiftUI, CoreMIDI and AVFoundation. No third-party code;
on a Mac the piano sound comes from the General MIDI bank built into macOS.

> **Status:** the app builds and its unit tests pass on macOS (see the Build
> workflow), but it was written without access to a Mac and has not been run by
> hand yet. Expect rough edges in the notation drawing and layout.

## Requirements

- Mac: macOS 13 (Ventura) or later
- iPhone and iPad: iOS / iPadOS 16 or later
- Xcode 15 or later. The Mac app also builds with just the Xcode Command Line Tools (`xcode-select --install`).

## Build and run on a Mac

```bash
./scripts/build-app.sh
open "build/Piano Tutor.app"
```

The script builds a release binary and wraps it in an app bundle. You can move
`Piano Tutor.app` to your Applications folder.

Every push also builds the app on GitHub Actions; the result is attached to the
workflow run as the `PianoTutor-app` artifact. A downloaded copy is not
notarised, so macOS blocks it on first launch: right-click the app and choose
**Open**, or allow it under System Settings → Privacy & Security. An app you
build yourself with the script above opens normally.

For development, either run it straight from the package:

```bash
swift run PianoTutor
```

or open `Package.swift` in Xcode and press Run.

Run the tests with `swift test`.

## Build and run on iPhone and iPad

The iOS app is built from the same sources by an Xcode project that
[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates from `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open PianoTutor.xcodeproj
```

Choose the **PianoTutor-iOS** scheme and a simulator, and press Run. To run on
your own device, select your team under Signing & Capabilities first.

- **iPad** shows the same layout as the Mac. All 61 keys are shown when they fit.
- **iPhone** works upright or on its side. The on-screen keyboard shows as many
  keys as can be played comfortably, placed around the notes of the current
  exercise; the arrows at its ends move it by an octave.
- A USB-MIDI keyboard works the same way as on a Mac. Connect it to the USB-C
  port (or through a Lightning to USB adapter on older devices).
- iOS has no built-in piano sound bank, so notes play as a plain tone. To get a
  real piano, add a General MIDI SoundFont named `SoundBank.sf2` to `Support/iOS`
  and run `xcodegen generate` again.
- There is no app icon yet.

## Connecting a Casio CT-S300

1. Connect the keyboard's USB port (micro-USB, on the back) to your Mac. Use a cable that carries data; some cables only charge.
2. Switch the keyboard on.
3. Open Piano Tutor. The sidebar shows "Keyboard connected" with the device name. No driver is needed.

In **Settings** you can check which note the app last received.

By default the app does not play your notes through the Mac when a MIDI keyboard
is connected, because the keyboard has its own speakers. The metronome and any
accompaniment come from the Mac. You can change this under Settings → Sound.

Without a keyboard you can click the on-screen keys or use the computer
keyboard: `A S D F G H J K` are the white keys from Middle C, `W E T Y U` the
black keys, and `Z` / `X` shift the octave.

## Project layout

| Path | Contents |
| --- | --- |
| `Sources/PianoTutorCore` | Pure Swift: pitches, the text notation parser, staff layout, scoring, and all lesson and song content |
| `Sources/PianoTutor` | The app: MIDI input, audio, the scrolling staff, the keyboard and the screens |
| `Tests/PianoTutorCoreTests` | Unit tests for the core |
| `scripts/build-app.sh` | Builds the macOS `.app` bundle |
| `project.yml`, `Support/iOS` | XcodeGen definition and resources for the iPhone and iPad app |

## Adding your own music

Songs are written in a small text notation (see `Sources/PianoTutorCore/Notation.swift`):

```
E4 E4 F4 G4 | G4 F4 E4 D4 | C4 C4 D4 E4 | E4/q. D4/e D4/h
```

- `C4/h` is a half-note Middle C. Durations are `w`, `h`, `q`, `e`; add `.` for a dotted note. A note without a duration is a quarter note.
- `C4+E4+G4/w` is a chord, `r/q` a rest, `|` a barline, and `~` ties a note to the next one.
- `E4/q:3` sets the finger number.

Add a melody to `Tunes.swift` and an entry to `SongLibrary.swift`. Every measure
is checked against the time signature, and `swift test` reports any mistakes.

## Credits

Notation symbols use the [Bravura](https://github.com/steinbergmedia/bravura)
music font by Steinberg, under the SIL Open Font License
(`Sources/PianoTutor/Resources/Bravura-LICENSE.txt`).

All tunes are traditional or in the public domain.
