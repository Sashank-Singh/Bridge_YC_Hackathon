import SwiftUI
import Translation

@available(iOS 27.1, *)
struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var camera = CameraSessionModel()
  @State private var conversation = ConversationModel()

  var body: some View {
    ZStack {
      CameraPreview(session: camera.session)
        .opacity(0.001)
        .allowsHitTesting(false)

      InnerDuoLayout(conversation: conversation)
    }
      .sceneAccessory {
        CameraCaptureAccessory {
          OuterGreetingView(conversation: conversation)
        }
      }
      .translationTask(conversation.translationConfiguration) { session in
        await conversation.translate(using: session)
      }
      .task(id: scenePhase) {
        if scenePhase == .active {
          await camera.start()
        } else {
          camera.stop()
          conversation.stop()
        }
      }
      .onDisappear {
        camera.stop()
        conversation.stop()
      }
  }
}

@available(iOS 27.1, *)
private struct InnerDuoLayout: View {
  @Bindable var conversation: ConversationModel

  var body: some View {
    GeometryReader { proxy in
      HStack(spacing: 0) {
        BridgeConversationScreen(conversation: conversation, person: .inner, isInteractive: true)
          .frame(width: proxy.size.width * 0.5)
          .clipped()

        BridgeBrandPanel()
          .frame(width: proxy.size.width * 0.5)
          .clipped()
      }
    }
    .ignoresSafeArea()
  }
}

private struct BridgeBrandPanel: View {
  private let ink = Color(red: 0.08, green: 0.09, blue: 0.09)
  private let paper = Color(red: 0.93, green: 0.91, blue: 0.85)
  private let coral = Color(red: 0.91, green: 0.28, blue: 0.22)
  private let teal = Color(red: 0.04, green: 0.52, blue: 0.55)

  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < 320
      ZStack {
        paper

        Rectangle()
          .fill(ink.opacity(0.08))
          .frame(width: 1)
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: compact ? 14 : 22) {
          BridgeLogoMark(coral: coral, teal: teal)
            .scaleEffect(compact ? 0.68 : 1)

          VStack(spacing: 8) {
            Text("Bridge.")
              .font(.system(size: compact ? 34 : 52, weight: .black, design: .rounded))
              .foregroundStyle(ink)

            Text("Different languages.\nOne conversation.")
              .font(compact ? .subheadline : .headline)
              .multilineTextAlignment(.center)
              .foregroundStyle(ink.opacity(0.52))
              .lineSpacing(4)
          }
        }
        .padding(compact ? 18 : 40)
      }
    }
  }
}

private struct BridgeLogoMark: View {
  let coral: Color
  let teal: Color

  var body: some View {
    HStack(spacing: -9) {
      Circle()
        .trim(from: 0.08, to: 0.58)
        .stroke(coral, style: StrokeStyle(lineWidth: 15, lineCap: .round))
        .rotationEffect(.degrees(12))

      Circle()
        .trim(from: 0.58, to: 1.08)
        .stroke(teal, style: StrokeStyle(lineWidth: 15, lineCap: .round))
        .rotationEffect(.degrees(12))
    }
    .frame(width: 96, height: 54)
    .accessibilityHidden(true)
  }
}

@available(iOS 27.1, *)
struct BridgeConversationScreen: View {
  @Bindable var conversation: ConversationModel
  let person: ConversationModel.Speaker
  let isInteractive: Bool
  @State private var availableWidth: CGFloat = 1000

  private let ink = Color(red: 0.08, green: 0.09, blue: 0.09)
  private let paper = Color(red: 0.97, green: 0.95, blue: 0.90)

  private var accent: Color {
    person == .inner
      ? Color(red: 0.91, green: 0.28, blue: 0.22)
      : Color(red: 0.04, green: 0.52, blue: 0.55)
  }

  private var isCurrentSpeaker: Bool { conversation.speaker == person }
  private var language: BridgeLanguage { conversation.language(for: person) }
  private var otherLanguage: BridgeLanguage { conversation.language(for: person.other) }
  private var personName: String { person == .inner ? "Person 1" : "Person 2" }
  private var isCompact: Bool { availableWidth < 320 }

  var body: some View {
    ZStack {
      paper.ignoresSafeArea()

      VStack(spacing: 0) {
        header
        stateContent
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(.top, isCompact ? 14 : 28)
        languageBar
      }
      .padding(.horizontal, isCompact ? 16 : 24)
      .padding(.top, 10)
      .padding(.bottom, 18)
    }
    .foregroundStyle(ink)
    .animation(.snappy(duration: 0.35), value: conversation.phase)
    .background {
      GeometryReader { proxy in
        Color.clear
          .onAppear { availableWidth = proxy.size.width }
          .onChange(of: proxy.size.width) { _, width in availableWidth = width }
      }
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Bridge.")
          .font(.headline.weight(.black))
        Text(personName.uppercased())
          .font(.caption2.weight(.bold))
          .tracking(1.4)
          .foregroundStyle(accent)
      }

      Spacer()

      Circle()
        .fill(accent)
        .frame(width: 12, height: 12)
        .overlay {
          Circle().stroke(accent.opacity(0.2), lineWidth: 7)
        }
        .accessibilityHidden(true)
    }
  }

  @ViewBuilder
  private var stateContent: some View {
    switch conversation.phase {
    case .ready:
      if isInteractive {
        readyView
      } else {
        statusView(title: "Ready for \(personName)", subtitle: "Start the conversation from the other display.", symbol: "person.2.wave.2")
      }
    case .requestingAccess:
      statusView(title: "Getting ready…", symbol: "mic.badge.plus")
    case .listening:
      if isCurrentSpeaker { listeningView } else { waitingView }
    case .finishing:
      statusView(title: "Finishing your sentence…", symbol: "ellipsis.bubble.fill")
    case .translating:
      translatingView
    case .translated:
      translatedView
    case .failed(let message):
      failedView(message)
    }
  }

  private var readyView: some View {
    VStack(spacing: isCompact ? 14 : 26) {
      Image(systemName: "waveform.and.mic")
        .font(.system(size: isCompact ? 36 : 48, weight: .medium))
        .foregroundStyle(accent)

      VStack(spacing: 10) {
        Text("Place Bridge between you")
          .font(.system(size: isCompact ? 28 : 36, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
        Text("Start once, then take turns. Bridge detects when each person finishes, translates, and speaks on the other side.")
          .font(isCompact ? .body : .title3)
          .foregroundStyle(ink.opacity(0.65))
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }

      primaryButton("Start with \(personName)", symbol: "mic.fill") {
        Task { await conversation.startSpeaking(person) }
      }

      Button {
        conversation.playDemo()
      } label: {
        Label(isCompact ? "Play demo" : "Play 30-second demo", systemImage: "play.circle.fill")
          .font(isCompact ? .subheadline : .headline)
      }
      .buttonStyle(.bordered)
      .tint(accent)
    }
  }

  private var listeningView: some View {
    VStack(spacing: 24) {
      VStack(spacing: 8) {
        Text("LISTENING IN \(language.name.uppercased())")
          .font(.caption.weight(.bold))
          .tracking(1.8)
          .foregroundStyle(accent)
        Text(conversation.liveText.isEmpty ? "Go ahead…" : conversation.liveText)
          .font(.system(size: conversation.liveText.isEmpty ? 42 : 34, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
      }

      WaveformMark(color: accent)

      if isInteractive {
        Button("Finish now") {
          conversation.finishSpeaking()
        }
        .buttonStyle(.bordered)
        .tint(accent)
      }

      Text("Pause naturally — translation starts automatically.")
        .font(.footnote.weight(.medium))
        .foregroundStyle(ink.opacity(0.55))
    }
  }

  private var waitingView: some View {
    statusView(
      title: "Listening to the other person",
      subtitle: "Their \(otherLanguage.name) will appear here in \(language.name) when they finish.",
      symbol: "ear"
    )
  }

  private var translatingView: some View {
    VStack(spacing: 24) {
      ProgressView()
        .controlSize(.large)
        .tint(accent)
      Text("Translating…")
        .font(.system(size: 38, weight: .bold, design: .rounded))
      Text(isCurrentSpeaker ? conversation.sourceText : "Turning \(otherLanguage.name) into \(language.name)")
        .font(.title3)
        .multilineTextAlignment(.center)
        .foregroundStyle(ink.opacity(0.62))
    }
  }

  private var translatedView: some View {
    VStack(spacing: 24) {
      VStack(spacing: 10) {
        Text(isCurrentSpeaker ? "YOU SAID" : "TRANSLATION")
          .font(.caption.weight(.bold))
          .tracking(1.8)
          .foregroundStyle(accent)
        Text(isCurrentSpeaker ? conversation.sourceText : conversation.translatedText)
          .font(.system(size: isCompact ? 27 : 38, weight: .bold, design: .rounded))
          .multilineTextAlignment(.center)
      }

      if !isCurrentSpeaker && isInteractive {
        Button {
          if conversation.isDemoActive {
            conversation.playDemo()
          } else {
            conversation.speakTranslation()
          }
        } label: {
          Label(conversation.isDemoActive ? (isCompact ? "Restart demo" : "Restart 30-second demo") : "Play again", systemImage: "speaker.wave.2.fill")
        }
        .buttonStyle(.bordered)
        .tint(accent)
      }

      if conversation.isDemoActive && !isCurrentSpeaker {
        Button {
          conversation.continueDemo()
        } label: {
          Label("Reply in demo", systemImage: "mic.fill")
        }
        .buttonStyle(.bordered)
        .tint(accent)
      } else {
        Label(
          isCurrentSpeaker ? "Playing this for \(person.other == .inner ? "Person 1" : "Person 2")" : "Reply after playback",
          systemImage: isCurrentSpeaker ? "speaker.wave.2.fill" : "mic.fill"
        )
        .font(.headline)
        .foregroundStyle(accent)
      }
    }
  }

  private func failedView(_ message: String) -> some View {
    VStack(spacing: 22) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 44))
        .foregroundStyle(accent)
      Text("Bridge needs your help")
        .font(.system(size: isCompact ? 25 : 32, weight: .bold, design: .rounded))
      Text(message)
        .font(.title3)
        .multilineTextAlignment(.center)
        .foregroundStyle(ink.opacity(0.65))
      if isInteractive {
        primaryButton("Try again", symbol: "arrow.clockwise") {
          Task { await conversation.startSpeaking(person) }
        }
      }
    }
  }

  private func statusView(title: String, subtitle: String? = nil, symbol: String) -> some View {
    VStack(spacing: 20) {
      Image(systemName: symbol)
        .font(.system(size: 48, weight: .medium))
        .foregroundStyle(accent)
      Text(title)
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .multilineTextAlignment(.center)
      if let subtitle {
        Text(subtitle)
          .font(.title3)
          .foregroundStyle(ink.opacity(0.62))
          .multilineTextAlignment(.center)
      }
    }
  }

  private func primaryButton(
    _ title: String,
    symbol: String,
    disabled: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(isCompact ? .subheadline : .headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 12 : 18)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .background(disabled ? ink.opacity(0.25) : accent, in: Capsule())
    .disabled(disabled)
  }

  private var languageBar: some View {
    HStack(spacing: 12) {
      if !isCompact {
        Image(systemName: "person.crop.circle")
          .foregroundStyle(accent)
      }

      if isInteractive {
        if isCompact {
          languageMenu(language, shortLabel: person == .inner ? "P1" : "P2") { candidate in
            if person == .inner {
              conversation.innerLanguage = candidate
            } else {
              conversation.outerLanguage = candidate
            }
          }
          .disabled(conversation.phase != .ready && conversation.phase != .translated && !isFailed)

          if person == .inner {
            Image(systemName: "arrow.right")
              .font(.caption.weight(.bold))
              .foregroundStyle(ink.opacity(0.45))
            languageMenu(conversation.outerLanguage, shortLabel: "P2") { candidate in
              conversation.outerLanguage = candidate
            }
            .disabled(conversation.phase != .ready && conversation.phase != .translated && !isFailed)
          }
        } else {
          Picker("Language", selection: person == .inner ? $conversation.innerLanguage : $conversation.outerLanguage) {
            ForEach(BridgeLanguage.allCases) { language in
              Text(language.name).tag(language)
            }
          }
          .pickerStyle(.menu)
          .tint(ink)
          .disabled(conversation.phase != .ready && conversation.phase != .translated && !isFailed)

          if person == .inner {
            Menu {
              ForEach(BridgeLanguage.allCases) { candidate in
                Button(candidate.name) { conversation.outerLanguage = candidate }
              }
            } label: {
              Label("Person 2: \(conversation.outerLanguage.name)", systemImage: "person.2")
                .font(.subheadline.weight(.semibold))
            }
            .disabled(conversation.phase != .ready && conversation.phase != .translated && !isFailed)
          }
        }
      } else {
        Text(language.name)
          .font(.headline)
      }

      Spacer()

      if !isCompact {
        Text(person == .inner ? "PERSON 1" : "PERSON 2")
          .font(.caption2.weight(.black))
          .tracking(1.4)
          .foregroundStyle(ink.opacity(0.45))
      }
    }
    .padding(.horizontal, isCompact ? 12 : 16)
    .padding(.vertical, isCompact ? 9 : 12)
    .background(.white.opacity(0.6), in: Capsule())
  }

  private var isFailed: Bool {
    if case .failed = conversation.phase { return true }
    return false
  }

  private func languageMenu(
    _ selected: BridgeLanguage,
    shortLabel: String,
    action: @escaping (BridgeLanguage) -> Void
  ) -> some View {
    Menu {
      ForEach(BridgeLanguage.allCases) { candidate in
        Button(candidate.name) { action(candidate) }
      }
    } label: {
      Label("\(shortLabel): \(languageCode(for: selected))", systemImage: "chevron.up.chevron.down")
        .font(.caption.weight(.bold))
    }
  }

  private func languageCode(for language: BridgeLanguage) -> String {
    switch language {
    case .english: "EN"
    case .spanish: "ES"
    case .french: "FR"
    case .german: "DE"
    case .italian: "IT"
    case .japanese: "JA"
    case .korean: "KO"
    case .chinese: "ZH"
    }
  }
}

private struct WaveformMark: View {
  let color: Color

  var body: some View {
    HStack(alignment: .center, spacing: 5) {
      ForEach(Array([12, 25, 40, 30, 52, 34, 44, 22, 12].enumerated()), id: \.offset) { _, height in
        Capsule()
          .fill(color)
          .frame(width: 5, height: CGFloat(height))
      }
    }
    .frame(height: 58)
    .accessibilityHidden(true)
  }
}
