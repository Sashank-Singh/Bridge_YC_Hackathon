import Foundation

enum BridgeLanguage: String, CaseIterable, Identifiable {
  case english
  case spanish
  case french
  case german
  case italian
  case japanese
  case korean
  case chinese

  var id: String { rawValue }

  var name: String {
    switch self {
    case .english: "English"
    case .spanish: "Spanish"
    case .french: "French"
    case .german: "German"
    case .italian: "Italian"
    case .japanese: "Japanese"
    case .korean: "Korean"
    case .chinese: "Chinese"
    }
  }

  var localeIdentifier: String {
    switch self {
    case .english: "en-US"
    case .spanish: "es-ES"
    case .french: "fr-FR"
    case .german: "de-DE"
    case .italian: "it-IT"
    case .japanese: "ja-JP"
    case .korean: "ko-KR"
    case .chinese: "zh-CN"
    }
  }

  var translationLanguage: Locale.Language {
    Locale.Language(identifier: localeIdentifier)
  }
}
