import SwiftUI

@available(iOS 27.1, *)
struct OuterGreetingView: View {
  var body: some View {
    ZStack {
      Color.indigo.ignoresSafeArea()

      Text("Hello Outer World")
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
