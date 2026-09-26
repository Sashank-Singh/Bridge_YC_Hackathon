import AVFoundation
import Observation
import Speech
import Translation

@Observable
@MainActor
final class ConversationModel: NSObject, AVSpeechSynthesizerDelegate {
  enum Speaker {
    case inner
    case outer

    var other: Speaker { self == .inner ? .outer : .inner }
  }

  enum Phase: Equatable {
    case ready
    case requestingAccess
    case listening
    case finishing
    case translating
    case translated
    case failed(String)
  }

  var innerLanguage: BridgeLanguage {
    didSet { UserDefaults.standard.set(innerLanguage.rawValue, forKey: "bridge.innerLanguage") }
  }
  var outerLanguage: BridgeLanguage {
    didSet { UserDefaults.standard.set(outerLanguage.rawValue, forKey: "bridge.outerLanguage") }
  }
  var phase: Phase = .ready
  var speaker: Speaker = .inner
  var liveText = ""
  var sourceText = ""
  var translatedText = ""
  var translationConfiguration: TranslationSession.Configuration?
  var isDemoActive = false

  @ObservationIgnored private var audioEngine: AVAudioEngine?
  @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
  @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
  @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  @ObservationIgnored private var finishTimeout: Task<Void, Never>?
  @ObservationIgnored private var silenceTimeout: Task<Void, Never>?
  @ObservationIgnored private var demoTask: Task<Void, Never>?
  @ObservationIgnored private var demoStep = 0
  @ObservationIgnored private var activeDemoTurns: [(Speaker, String, String)] = []
  @ObservationIgnored private var turnID = UUID()

  override init() {
    innerLanguage = BridgeLanguage(rawValue: UserDefaults.standard.string(forKey: "bridge.innerLanguage") ?? "") ?? .english
    let savedOuterLanguage = UserDefaults.standard.string(forKey: "bridge.outerLanguage")
    // The original prototype used Spanish as its second default. Migrate that
    // untouched default to the requested English ↔ German demo pair.
    outerLanguage = savedOuterLanguage == nil || savedOuterLanguage == BridgeLanguage.spanish.rawValue
      ? .german
      : BridgeLanguage(rawValue: savedOuterLanguage!) ?? .german
    super.init()
    synthesizer.delegate = self
  }

  func language(for person: Speaker) -> BridgeLanguage {
    person == .inner ? innerLanguage : outerLanguage
  }

  func startSpeaking(_ person: Speaker) async {
    guard phase != .listening, phase != .requestingAccess, phase != .finishing, phase != .translating else { return }
    guard innerLanguage != outerLanguage else {
      phase = .failed("Choose two different languages to start.")
      return
    }

    synthesizer.stopSpeaking(at: .immediate)
    isDemoActive = false
    speaker = person
    phase = .requestingAccess

    let microphoneAllowed = await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
    }
    guard microphoneAllowed else {
      phase = .failed("Allow microphone access in Settings to capture speech.")
      return
    }

    let speechAllowed: Bool
    if SFSpeechRecognizer.authorizationStatus() == .authorized {
      speechAllowed = true
    } else {
      speechAllowed = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status == .authorized)
        }
      }
    }
    guard speechAllowed else {
      phase = .failed("Allow speech recognition in Settings to turn speech into text.")
      return
    }

    let locale = Locale(identifier: language(for: person).localeIdentifier)
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
      phase = .failed("Speech recognition is unavailable for \(language(for: person).name) right now.")
      return
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try AVAudioSession.sharedInstance().setActive(true)

      let engine = AVAudioEngine()
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        phase = .failed("The microphone is unavailable. Check the simulator audio input or reconnect your microphone, then try again.")
        return
      }

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      // Do not force an on-device model. A locale can report support before its
      // assets are downloaded, especially in Simulator, which ends the task
      // immediately instead of falling back to server recognition.
      request.requiresOnDeviceRecognition = false
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        request.append(buffer)
      }
      audioEngine = engine
      engine.prepare()

      turnID = UUID()
      let currentTurn = turnID
      liveText = ""
      sourceText = ""
      translatedText = ""
      recognitionRequest = request
      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
        Task { @MainActor [weak self] in
          self?.receiveRecognition(result, error: error, turn: currentTurn)
        }
      }
      try engine.start()
      phase = .listening
    } catch {
      stopAudioCapture()
      phase = .failed("Couldn’t start listening. Please try again.")
    }
  }

  func finishSpeaking() {
    guard phase == .listening else { return }
    silenceTimeout?.cancel()
    phase = .finishing
    audioEngine?.stop()
    recognitionRequest?.endAudio()

    let currentTurn = turnID
    finishTimeout?.cancel()
    finishTimeout = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      self?.completeRecognition(turn: currentTurn)
    }
  }

  func submitText(_ text: String, from person: Speaker) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, innerLanguage != outerLanguage else { return }
    stopAudioCapture()
    isDemoActive = false
    synthesizer.stopSpeaking(at: .immediate)
    turnID = UUID()
    speaker = person
    liveText = trimmed
    completeRecognition(turn: turnID)
  }

  func playDemo() {
    guard phase == .ready || phase == .translated else { return }
    stopAudioCapture()
    synthesizer.stopSpeaking(at: .immediate)
    isDemoActive = true
    demoTask?.cancel()
    demoStep = 0
    // Demos always use English on Person 1's side and the language selected
    // for Person 2, so every supported second language has a complete script.
    innerLanguage = .english
    if outerLanguage == .english { outerLanguage = .german }
    activeDemoTurns = demoTurns(for: outerLanguage)
    demoTask = Task { @MainActor [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: .seconds(3))
      // Keep each translated turn on screen for seven seconds so the user can
      // physically flip the Duo and show the other person what was said.
      for index in self.activeDemoTurns.indices {
        guard !Task.isCancelled else { return }
        self.demoStep = index
        self.showDemoTurn()

        if index < self.activeDemoTurns.count - 1 {
          try? await Task.sleep(for: .seconds(7))
        }
      }

      // Leave the final reply visible for the remainder of the thirty-second demo.
      try? await Task.sleep(for: .seconds(6))
    }
  }

  func continueDemo() {
    guard isDemoActive, !activeDemoTurns.isEmpty else { return }
    demoTask?.cancel()
    demoStep = (demoStep + 1) % activeDemoTurns.count
    showDemoTurn()
  }

  private func showDemoTurn() {
    let turn = activeDemoTurns[demoStep]
    speaker = turn.0
    sourceText = turn.1
    translatedText = turn.2
    liveText = turn.1
    phase = .translated
  }

  private func demoTurns(for language: BridgeLanguage) -> [(Speaker, String, String)] {
    let script: (String, String, String, String)
    switch language {
    case .english, .german:
      script = ("Hallo, schön, dich kennenzulernen. Ich bin zum ersten Mal in diesem Viertel.", "Danke, gleichfalls. Ich wohne in der Nähe. Wie gefällt dir dein Besuch?", "Mir geht es sehr gut. Möchtest du einen Kaffee trinken und weiterreden?", "Ja, sehr gerne. Gleich um die Ecke gibt es ein schönes Café. Alles klar. Los geht’s.")
    case .spanish:
      script = ("Hola, mucho gusto. Es la primera vez que visito este barrio.", "Gracias, igualmente. Vivo cerca. ¿Cómo está yendo tu visita?", "Lo estoy pasando muy bien. ¿Quieres tomar un café y seguir hablando?", "Sí, me encantaría. Hay una cafetería agradable a la vuelta de la esquina. Muy bien. Vamos.")
    case .french:
      script = ("Bonjour, ravi de vous rencontrer. Je visite ce quartier pour la première fois.", "Merci, moi aussi. J’habite tout près. Comment se passe votre visite ?", "Je passe un très bon moment. Voulez-vous prendre un café et continuer à discuter ?", "Oui, avec plaisir. Il y a un joli café juste au coin de la rue. D’accord. Allons-y.")
    case .italian:
      script = ("Ciao, piacere di conoscerti. È la prima volta che visito questo quartiere.", "Grazie, altrettanto. Abito qui vicino. Come sta andando la tua visita?", "Mi sto divertendo molto. Ti va di prendere un caffè e continuare a parlare?", "Sì, volentieri. C’è un bel bar proprio dietro l’angolo. Va bene. Andiamo.")
    case .japanese:
      script = ("こんにちは。お会いできてうれしいです。この辺りを訪れるのは初めてです。", "ありがとうございます。私もです。近くに住んでいますが、滞在はいかがですか？", "とても楽しんでいます。コーヒーを飲みながら、もう少しお話ししませんか？", "ぜひ。すぐ角を曲がったところに素敵なカフェがあります。よし、行きましょう。")
    case .korean:
      script = ("안녕하세요. 만나서 반갑습니다. 이 동네를 방문한 것은 처음이에요.", "감사합니다. 저도 반갑습니다. 저는 근처에 사는데, 방문은 어떠세요?", "정말 즐겁게 보내고 있어요. 커피를 마시면서 더 이야기할까요?", "네, 좋아요. 바로 모퉁이에 좋은 카페가 있어요. 좋아요. 가요.")
    case .chinese:
      script = ("你好，很高兴认识你。这是我第一次来这个街区。", "谢谢，我也是。我就住在附近。你的旅程怎么样？", "我玩得很开心。你想喝杯咖啡继续聊吗？", "好的，我很愿意。街角就有一家很不错的咖啡馆。好，我们走吧。")
    }

    return [
      (.inner, "Hello, it’s nice to meet you. I’m visiting this neighborhood for the first time.", script.0),
      (.outer, script.1, "Thank you, likewise. I live nearby. How are you enjoying your visit?"),
      (.inner, "I’m having a great time. Would you like to get a coffee and keep talking?", script.2),
      (.outer, script.3, "Yes, I’d love to. There’s a nice café just around the corner. Alright. Let’s go.")
    ]
  }

  func translate(using session: TranslationSession) async {
    guard phase == .translating else { return }
    let currentTurn = turnID
    let text = sourceText
    do {
      let response = try await session.translate(text)
      guard currentTurn == turnID else { return }
      translatedText = response.targetText
      phase = .translated
      speakTranslation()
    } catch {
      guard currentTurn == turnID else { return }
      phase = .failed("Translation couldn’t finish. Check language downloads or your connection, then try again.")
    }
  }

  func speakTranslation() {
    guard !translatedText.isEmpty else { return }
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: translatedText)
    utterance.voice = AVSpeechSynthesisVoice(language: language(for: speaker.other).localeIdentifier)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    synthesizer.speak(utterance)
  }

  func stop() {
    finishTimeout?.cancel()
    silenceTimeout?.cancel()
    demoTask?.cancel()
    stopAudioCapture()
    synthesizer.stopSpeaking(at: .immediate)
    isDemoActive = false
    if phase == .listening || phase == .finishing || phase == .requestingAccess {
      phase = .ready
    }
  }

  private func receiveRecognition(_ result: SFSpeechRecognitionResult?, error: Error?, turn: UUID) {
    guard turn == turnID else { return }
    if let result {
      liveText = result.bestTranscription.formattedString
      if result.isFinal {
        if phase == .finishing {
          completeRecognition(turn: turn)
        } else if phase == .listening && !liveText.isEmpty {
          finishSpeaking()
        }
      } else if phase == .listening && !liveText.isEmpty {
        scheduleAutomaticFinish(turn: turn)
      }
    }
    if let error, phase == .listening || phase == .finishing {
      let speechError = error as NSError
      print("Bridge speech recognition error: \(speechError.domain) \(speechError.code) — \(speechError.localizedDescription)")
      if phase == .finishing && !liveText.isEmpty {
        completeRecognition(turn: turn)
      } else {
        stopAudioCapture()
#if targetEnvironment(simulator)
        if speechError.domain == "kLSRErrorDomain", speechError.code == 300 {
          // The built-in Duo preview cannot initialize Apple's speech assets.
          // Return to the ready state so this simulator limitation never
          // replaces the demo experience with an error screen.
          phase = .ready
        } else {
          phase = .failed("Speech recognition stopped. Please try again.")
        }
#else
        phase = .failed("Speech recognition stopped. Please try again.")
#endif
      }
    }
  }

  private func completeRecognition(turn: UUID) {
    guard turn == turnID, phase == .finishing || phase == .listening || !liveText.isEmpty else { return }
    finishTimeout?.cancel()
    stopAudioCapture()
    let text = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      phase = .failed("No speech was heard. Try speaking again.")
      return
    }
    sourceText = text
    phase = .translating
    if translationConfiguration == nil {
      translationConfiguration = TranslationSession.Configuration(
        source: language(for: speaker).translationLanguage,
        target: language(for: speaker.other).translationLanguage
      )
    } else {
      translationConfiguration?.source = language(for: speaker).translationLanguage
      translationConfiguration?.target = language(for: speaker.other).translationLanguage
      translationConfiguration?.invalidate()
    }
  }

  private func stopAudioCapture() {
    silenceTimeout?.cancel()
    if let engine = audioEngine {
      if engine.isRunning { engine.stop() }
      engine.inputNode.removeTap(onBus: 0)
      engine.reset()
      audioEngine = nil
    }
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionRequest = nil
    recognitionTask = nil
  }

  private func scheduleAutomaticFinish(turn: UUID) {
    silenceTimeout?.cancel()
    silenceTimeout = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1.4))
      guard !Task.isCancelled, let self, self.turnID == turn, self.phase == .listening else { return }
      self.finishSpeaking()
    }
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    Task { @MainActor [weak self] in
      guard let self, self.phase == .translated else { return }
      try? await Task.sleep(for: .milliseconds(450))
      guard self.phase == .translated else { return }
      await self.startSpeaking(self.speaker.other)
    }
  }
}
