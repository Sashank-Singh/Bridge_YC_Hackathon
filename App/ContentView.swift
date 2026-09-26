import SwiftUI

@available(iOS 27.1, *)
struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @State private var camera = CameraSessionModel()

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      CameraPreview(session: camera.session)
        .ignoresSafeArea()

      Color.black.opacity(0.42)
        .ignoresSafeArea()

      VStack(spacing: 20) {
        Text("Hello Inner World")
          .font(.largeTitle.bold())
          .multilineTextAlignment(.center)
          .foregroundStyle(.white)

        if camera.status != .running {
          VStack(spacing: 12) {
            Text(camera.status.message)
              .font(.body)
              .multilineTextAlignment(.center)
              .foregroundStyle(.white.opacity(0.85))

            if camera.status == .denied {
              Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  openURL(url)
                }
              }
              .buttonStyle(.borderedProminent)
            }
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .sceneAccessory {
      CameraCaptureAccessory {
        OuterGreetingView()
      }
    }
    .task(id: scenePhase) {
      if scenePhase == .active {
        await camera.start()
      } else {
        camera.stop()
      }
    }
    .onDisappear {
      camera.stop()
    }
  }
}
