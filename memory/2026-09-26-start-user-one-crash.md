# Start with User 1 crash — 2026-09-26

## Symptom

Pressing **Start with User 1** terminates the app.

## Root cause

`ConversationModel` eagerly constructed `AVAudioEngine` before the Duo simulator established a valid microphone route. Simulator logs show AVFAudio attaching the engine with a 0 Hz input format. `startSpeaking` then passed that invalid format to `installTap`, which raises a native AVFAudio exception outside Swift's `do/catch`.

The previous implementation also removed the input tap in both `finishSpeaking` and `stopAudioCapture`.

## Fix

- Create a fresh audio engine only after audio-session activation.
- Validate sample rate and channel count before installing the tap.
- Show an actionable microphone error rather than calling AVFAudio with an invalid format.
- Centralize tap removal and reset the engine after every turn.

## Evidence

- Simulator logs contain `AVAudioIONodeImpl ... error -10879` and `AURemoteIO ... 0 Hz`.
- The old call path installed a tap without validating its input format.
- The revised path cannot call `installTap` with a zero-rate or zero-channel format.

## Status

DONE_WITH_CONCERNS — source syntax is verified. Full compilation requires the iOS 27.1 SDK because the Duo `CameraCaptureAccessory` is not exposed by the selected iOS 27.0 command-line SDK.
