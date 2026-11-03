import AVFoundation
import Combine
import Foundation

struct SpeechVoiceOption: Identifiable, Sendable {
    let identifier: String
    let name: String
    let language: String
    let isPersonalVoice: Bool
    var id: String { identifier }
}

@MainActor
final class SpeechVoiceCatalog: ObservableObject {
    static let shared = SpeechVoiceCatalog()
    @Published private(set) var voices: [SpeechVoiceOption] = []
    private var loading = false

    private init() {}

    func refresh() {
        guard !loading else { return }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = AVSpeechSynthesisVoice.speechVoices().map { voice in
                SpeechVoiceOption(identifier: voice.identifier, name: voice.name,
                                  language: voice.language,
                                  isPersonalVoice: voice.voiceTraits.contains(.isPersonalVoice))
            }
            Task { @MainActor [weak self] in
                self?.voices = options
                self?.loading = false
            }
        }
    }
}

enum PhraseLanguage {
    @MainActor
    static var availableCodes: [String] {
        codes(from: SpeechVoiceCatalog.shared.voices)
    }

    static func codes(from voices: [SpeechVoiceOption]) -> [String] {
        Array(Set(voices.map(\.language)))
            .sorted { left, right in
                let common = ["en-US", "es-ES"]
                let leftRank = common.firstIndex(of: left) ?? common.count
                let rightRank = common.firstIndex(of: right) ?? common.count
                return leftRank == rightRank
                    ? title(for: left).localizedStandardCompare(title(for: right)) == .orderedAscending
                    : leftRank < rightRank
            }
    }

    static func title(for code: String) -> String {
        let name = Locale.current.localizedString(forIdentifier: code) ?? code
        return "\(name) (\(code))"
    }

    static func normalized(_ code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty,
              code.count <= 32 else { return nil }
        let parts = code.split(separator: "-", omittingEmptySubsequences: false)
        guard let first = parts.first, (2...8).contains(first.count),
              first.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) }),
              parts.dropFirst().allSatisfy({ part in
                  (2...8).contains(part.count) && part.utf8.allSatisfy {
                      (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                  }
              }) else { return nil }
        return code
    }
}
