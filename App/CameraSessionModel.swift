import AVFoundation
import Observation

@Observable
@MainActor
final class CameraSessionModel {
  @ObservationIgnored var session = AVCaptureSession()
  @ObservationIgnored private var captureQueue = DispatchQueue(label: "DuoGreetings.camera")

  var status: CameraStatus = .starting

  func start() async {
    let authorized: Bool
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      authorized = true
    case .notDetermined:
      authorized = await AVCaptureDevice.requestAccess(for: .video)
    default:
      authorized = false
    }

    guard authorized else {
      status = .denied
      return
    }

    status = .starting
    let session = session
    let captureQueue = captureQueue
    let started = await withCheckedContinuation { continuation in
      captureQueue.async {
        let configured = Self.configure(session)
        if configured && !session.isRunning {
          session.startRunning()
        }
        continuation.resume(returning: configured && session.isRunning)
      }
    }
    status = started ? .running : .unavailable
  }

  func stop() {
    let session = session
    captureQueue.async {
      if session.isRunning {
        session.stopRunning()
      }
    }
  }

  nonisolated private static func configure(_ session: AVCaptureSession) -> Bool {
    session.beginConfiguration()
    session.sessionPreset = .high
    defer { session.commitConfiguration() }

    if session.inputs.isEmpty {
      guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        ?? AVCaptureDevice.default(for: .video),
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input) else {
        return false
      }
      session.addInput(input)
    }

    if session.outputs.isEmpty {
      let output = AVCapturePhotoOutput()
      guard session.canAddOutput(output) else {
        return false
      }
      session.addOutput(output)
    }
    return true
  }
}

enum CameraStatus {
  case starting
  case running
  case denied
  case unavailable

  var message: String {
    switch self {
    case .starting:
      "Starting camera…"
    case .running:
      ""
    case .denied:
      "Allow camera access to show the outer greeting on iPhone Duo."
    case .unavailable:
      "No camera is available here. Open this app on iPhone Duo to show both greetings."
    }
  }
}
