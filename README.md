# 🌉 Bridge - Real-Time Dual-Language Translation for iPhone Duo

<div align="center">
  
![Bridge Logo](https://img.shields.io/badge/Bridge-Real--Time%20Translation-blue?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square&logo=swift)
![iOS](https://img.shields.io/badge/iOS-27.1+-green?style=flat-square&logo=apple)
![YC Hackathon](https://img.shields.io/badge/YC-Hackathon-red?style=flat-square)

**Bridge** is an innovative dual-screen translation app built for iPhone Duo hardware, enabling seamless real-time conversations between people speaking different languages.

[Features](#-features) • [How It Works](#-how-it-works) • [Getting Started](#-getting-started) • [Architecture](#-architecture)

</div>

---

## 📱 Overview

Bridge revolutionizes cross-language communication by leveraging the unique dual-screen capabilities of iPhone Duo. Two people can face each other across the device's fold, speaking in their native languages while Bridge handles real-time translation and audio playback on each screen.

### The Problem
Language barriers prevent meaningful conversations between people who speak different languages. Traditional translation apps create awkward back-and-forth exchanges.

### The Solution
Bridge positions each person's conversation on their half of the iPhone Duo screen. One person speaks while listening through speakers, and Bridge automatically:
- 🎙️ Detects when they finish speaking
- 🔄 Translates their message in real-time
- 🔊 Plays the translation aloud on the other screen

---

## ✨ Features

### Core Functionality
- **Dual-Screen UI**: Optimized layout for iPhone Duo's fold, with each person seeing their own interface
- **Live Transcription**: Real-time speech-to-text in 8 languages using native iOS APIs
- **Automatic Translation**: Built-in translation framework converts between languages instantly
- **Audio Playback**: Speaks translated text aloud with natural voice synthesis
- **Smart Turn Detection**: Automatically detects natural pauses to trigger translation

### Supported Languages
- 🇺🇸 English
- 🇪🇸 Spanish
- 🇫🇷 French
- 🇩🇪 German
- 🇮🇹 Italian
- 🇯🇵 Japanese
- 🇰🇷 Korean
- 🇨🇳 Chinese

### User Experience
- **Interactive Ready State**: Start conversation with a tap
- **Live Waveform Display**: Visual feedback during audio capture
- **Demo Mode**: 30-second pre-recorded conversation to showcase features
- **Language Selection**: Change languages between ready and conversation states
- **Error Handling**: Graceful failure states with recovery options
- **Responsive Design**: Adapts to compact and regular screen sizes

---

## 🏗️ How It Works

### Architecture Overview

```
┌─────────────────────────────────────┐
│      ContentView (Main UI)          │
│  - Dual-screen layout for Duo       │
│  - Scene accessories for cameras    │
└────────────┬────────────────────────┘
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
CameraSessionModel  ConversationModel
(Camera Input)      (Speech & Translation)
      │
      ├─ Captures audio from microphone
      └─ Manages camera preview (hidden)
```

### Conversation Flow

1. **Ready Phase**: User taps to start conversation
2. **Listening Phase**: Audio captured in source language
3. **Finishing Phase**: Wait for natural pause detection
4. **Translating Phase**: Translation API processes text
5. **Translated Phase**: Results displayed and played aloud
6. **Ready Phase**: User can respond in their language

### Key Components

#### ConversationModel
- Manages conversation state machine
- Handles speech transcription via native APIs
- Coordinates translation with `Translation` framework
- Manages audio playback
- Tracks source and translated text

#### CameraSessionModel
- Initializes and manages AVCaptureSession
- Handles audio input configuration
- Manages session lifecycle (start/stop)

#### BridgeLanguage
- Enum defining supported languages
- Maps to locale identifiers for translation
- Provides language names and codes

#### UI Components
- **BridgeConversationScreen**: Main conversation display for one person
- **BridgeBrandPanel**: Feature showcase with logo and tagline
- **BridgeLogoMark**: Animated dual-circle logo (coral and teal)
- **WaveformMark**: Visual audio feedback during listening

---

## 🚀 Getting Started

### Requirements
- iOS 27.1 or later
- iPhone Duo hardware
- Xcode 15.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Sashank-Singh/Bridge_YC_Hackathon.git
   cd Bridge_YC_Hackathon
   ```

2. **Open in Xcode**
   ```bash
   open Project.xcodeproj
   ```

3. **Configure signing**
   - Select the Bridge target
   - Update Bundle Identifier with your Team ID
   - Select your Development Team

4. **Run the app**
   - Select iPhone Duo simulator or device
   - Press ▶️ or Cmd+R

### First Run

1. Grant microphone permissions when prompted
2. Grant camera access (required for scene accessories)
3. Tap "Start with Person 1" to begin conversation
4. Speak in your native language
5. Watch as Bridge translates and responds

### Demo Mode
Try the 30-second pre-recorded demo to see Bridge in action without needing two speakers.

---

## 📂 Project Structure

```
Bridge_YC_Hackathon/
├── App/
│   ├── App.swift                 # App entry point
│   ├── ContentView.swift         # Main UI & layout
│   ├── ConversationModel.swift   # Business logic
│   ├── CameraSessionModel.swift  # Camera/audio capture
│   ├── BridgeLanguage.swift      # Language definitions
│   ├── CameraPreview.swift       # Camera preview component
│   ├── OuterGreetingView.swift   # Outer screen UI
│   ├── Assets.xcassets/          # Image assets
│   └── Info.plist                # App configuration
├── Project.xcodeproj/            # Xcode project
├── memory/                       # State persistence
└── .gitignore                    # Git ignore rules
```

---

## 🎨 Design System

Bridge uses a distinctive design language inspired by paper and ink:

- **Ink Color**: `#141516` (Dark charcoal)
- **Paper Color**: `#EDEBE0` (Off-white)
- **Coral Accent**: `#E84639` (Warm coral - Inner speaker)
- **Teal Accent**: `#0D8589` (Cool teal - Outer speaker)

The design emphasizes clarity, warmth, and the unique spatial relationship enabled by the dual-screen form factor.

---

## 🔄 State Management

ConversationModel uses a comprehensive state machine:

```swift
enum Phase {
    case ready                    // Waiting to start
    case requestingAccess         // Requesting permissions
    case listening                // Capturing audio
    case finishing                // Detecting pause
    case translating              // Processing translation
    case translated               // Showing results
    case failed(String)           // Error state
}
```

---

## 🎯 Key Features Deep Dive

### Automatic Turn Detection
- Monitor audio levels to detect natural pauses
- Transition smoothly from listening to translating
- User can manually finish if pause detection fails

### Demo Mode
- Pre-recorded sample conversation
- Allows testing without two speakers
- Cycles through languages for showcase

### Multi-Language Support
- Native iOS speech recognition per language
- Translation framework handles 8 language pairs
- Locale-specific text-to-speech for playback

### Error Handling
- Network error states with retry options
- Permission denial handling
- Graceful degradation if translation fails

---

## 📊 Technical Highlights

- **SwiftUI**: Modern declarative UI framework
- **async/await**: Structured concurrency for translation API calls
- **Translation Framework**: Native iOS translation engine
- **AVFoundation**: Audio capture and playback
- **Scene Accessories**: Leverage iPhone Duo's unique hardware
- **Environmental Variables**: Scene phase detection for lifecycle management

---

## 🛠️ Development

### Building from Source
```bash
xcodebuild -project Project.xcodeproj -scheme Bridge -configuration Debug
```

### Testing Translation
Enable console logging in ConversationModel to see translation details:
```swift
print("Translating: \(sourceText) → \(language.name)")
```

### Customizing Languages
Add new languages in `BridgeLanguage.swift`:
```swift
case portuguese
// ...
var name: String {
    case .portuguese: "Portuguese"
}
```

---

## 🎓 Learning Resources

- [Apple Translation Framework](https://developer.apple.com/documentation/translation)
- [iPhone Duo Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/platforms/designing-for-iphone-duo)
- [AVFoundation Audio Capture](https://developer.apple.com/av-foundation)
- [SwiftUI State Management](https://developer.apple.com/tutorials/swiftui)

---

## 📝 License

This project is open source. See LICENSE file for details.

---

## 👥 Contributors

- **Sashank Singh** - Project Lead
- **Alan Tan** - Core Architecture

---

## 🏆 YC Hackathon

Bridge was built as part of the Y Combinator Hackathon, showcasing innovative use of dual-screen hardware for real-world language accessibility challenges.

---

## 💭 Future Enhancements

- [ ] Support for more languages
- [ ] Custom voice selection
- [ ] Conversation history & export
- [ ] Accessibility improvements
- [ ] Offline translation mode
- [ ] Emotion/tone preservation in translation

---

## 📞 Support

For issues, questions, or suggestions:
1. Check existing GitHub Issues
2. Review the troubleshooting section in docs
3. Open a new Issue with detailed description

---

<div align="center">

**Built with ❤️ for seamless cross-language conversations**

[Report Issue](https://github.com/Sashank-Singh/Bridge_YC_Hackathon/issues) • [Discussions](https://github.com/Sashank-Singh/Bridge_YC_Hackathon/discussions)

</div>
