import SwiftUI

@available(iOS 27.1, *)
struct OuterGreetingView: View {
  @Bindable var conversation: ConversationModel

  var body: some View {
    BridgeConversationScreen(conversation: conversation, person: .outer, isInteractive: true)
  }
}
