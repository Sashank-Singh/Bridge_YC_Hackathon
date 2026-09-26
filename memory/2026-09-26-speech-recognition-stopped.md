# Speech recognition stopped

## Symptom

Starting a Person 1 turn immediately changed the conversation screen to “Speech recognition stopped. Please try again.” Audio was not transcribed or translated.

## Initial contributing issues

The video-only `AVCaptureSession` used to activate the iPhone Duo outer display retained its default `automaticallyConfiguresApplicationAudioSession = true`. AVFoundation therefore reconfigured the shared app audio session and selected a camera-oriented microphone while `AVAudioEngine` was trying to capture speech. Simulator logs showed capture/audio route failures during this flow.

The speech request also forced on-device recognition whenever the recognizer advertised support. Simulator and devices without downloaded locale assets can advertise that capability but terminate the recognition task instead of falling back.

## Confirmed remaining root cause

After cleaning and relaunching the built-in preview, the updated app still reproduced the failure. Its diagnostic output was:

`kLSRErrorDomain 300 — Failed to initialize recognizer`

Apple documents this exact code as a recognizer initialization failure. Current Apple Developer Forum reports reproduce it in recent iOS Simulators even when `SFSpeechRecognizer.isAvailable` is true. This is a simulator speech-asset/runtime defect; microphone capture and Bridge's audio engine are not the failing layer. Voice recognition must be validated on a physical device until Apple fixes the simulator runtime.

## Fix

- Disabled automatic application-audio-session configuration on the video-only camera session.
- Let `ConversationModel` remain the sole owner of the shared `AVAudioSession` used for speech capture.
- Allowed `SFSpeechRecognizer` to choose on-device or server recognition instead of forcing on-device recognition.
- Logged the speech error domain and code so any remaining device-specific failure is diagnosable.
- Added a simulator-specific explanation for error 300 so the preview no longer suggests an endless retry; physical devices retain the normal recoverable error message.

## Verification

- Parsed all Swift sources with `swiftc -frontend -parse` successfully.
- Ran `git diff --check` successfully.
- Full Xcode build/runtime validation is unavailable locally because the project targets the iOS 27.1 Duo APIs while the installed Xcode SDK is iOS 27.0.
- Cleaned and relaunched Bitrig's built-in preview, reproduced the updated build, and captured `kLSRErrorDomain 300` from its console.
