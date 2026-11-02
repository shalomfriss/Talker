import AVFoundation
import Foundation
import ZIPFoundation

struct BankedMessage: Sendable {
    let text: String
    let audioData: Data
}

struct MessageBankImportBatch: Sendable {
    let messages: [BankedMessage]
    let skipped: Int
}

enum MessageBankImporter {
    private static let supportedExtensions: Set<String> = ["m4a", "mp3", "wav", "aiff", "aif", "caf"]
    private static let maxRecordingBytes = 20_000_000
    private static let maxArchiveBytes = 200_000_000
    private static let maxRecordings = 200

    static func read(_ urls: [URL]) -> MessageBankImportBatch {
        var messages: [BankedMessage] = []
        var skipped = 0
        var totalBytes = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                if url.pathExtension.lowercased() == "zip" {
                    let data = try Data(contentsOf: url)
                    guard data.count <= maxArchiveBytes else { skipped += 1; continue }
                    let archive = try Archive(data: data, accessMode: .read)
                    for entry in archive {
                        guard messages.count < maxRecordings else { skipped += 1; continue }
                        guard entry.type == .file else { continue }
                        guard supportedExtensions.contains((entry.path as NSString).pathExtension.lowercased()),
                              entry.uncompressedSize <= maxRecordingBytes,
                              entry.uncompressedSize <= maxArchiveBytes - totalBytes else {
                            skipped += 1
                            continue
                        }
                        do {
                            var recording = Data()
                            _ = try archive.extract(entry) { chunk in
                                guard recording.count + chunk.count <= maxRecordingBytes else {
                                    throw ImportError.tooLarge
                                }
                                recording.append(chunk)
                            }
                            if let message = makeMessage(filename: (entry.path as NSString).lastPathComponent,
                                                         data: recording) {
                                messages.append(message)
                                totalBytes += recording.count
                            } else { skipped += 1 }
                        } catch { skipped += 1 }
                    }
                } else {
                    guard messages.count < maxRecordings,
                          supportedExtensions.contains(url.pathExtension.lowercased()),
                          (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= maxRecordingBytes,
                          (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= maxArchiveBytes - totalBytes else {
                        skipped += 1
                        continue
                    }
                    let data = try Data(contentsOf: url)
                    guard data.count <= maxRecordingBytes,
                          data.count <= maxArchiveBytes - totalBytes,
                          let message = makeMessage(filename: url.lastPathComponent, data: data) else {
                        skipped += 1
                        continue
                    }
                    messages.append(message)
                    totalBytes += data.count
                }
            } catch { skipped += 1 }
        }
        return MessageBankImportBatch(messages: messages, skipped: skipped)
    }

    private static func makeMessage(filename: String, data: Data) -> BankedMessage? {
        let text = (filename as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !data.isEmpty, (try? AVAudioPlayer(data: data)) != nil else { return nil }
        return BankedMessage(text: text, audioData: data)
    }

    private enum ImportError: Error { case tooLarge }
}
