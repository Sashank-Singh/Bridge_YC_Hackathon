# Outer display investigation — 2026-09-26

## Symptom

The iPhone Duo inner display renders Bridge, while the outer display remains black.

## Root cause

The last known-good implementation used the iOS 27.1-only `CameraCaptureAccessory`. During the Bridge translation implementation, it was replaced with iOS 27.0's `ExternalNonInteractiveAccessory` so the project could compile with the installed iOS 27.0 SDK. On the iPhone Duo simulator, SwiftUI reports that accessory as unavailable, so its content is never mounted.

## Evidence

- Screen 1 renders the inner Bridge UI; screen 3 remains black.
- `SceneAccessoryContent.onAvailabilityChange` reports `false` for `ExternalNonInteractiveAccessory`.
- Granting camera permission does not change availability.
- Explicitly enabling `ExternalNonInteractiveAccessory` does not change availability.
- Mounting the live `CameraPreview` does not change availability.
- The prior committed implementation uses `CameraCaptureAccessory` and targets iOS 27.1.

## Fix

Restored the iOS 27.1 `CameraCaptureAccessory`, restored the iOS 27.1 deployment target, and kept the camera preview mounted behind the opaque Bridge interface so the capture-backed outer accessory remains active.

## Status

DONE_WITH_CONCERNS — the source-level regression is reversed. The locally selected Xcode exposes only the iOS 27.0 SDK, so command-line compilation cannot verify the iOS 27.1-only symbol even though the installed Duo runtime is iOS 27.1.
