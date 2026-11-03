import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct SceneHotspotVideoView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let data: Data?
    let posterData: Data?
    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    @State private var errorMessage: String?

    init(hotspot: SceneHotspot) {
        title = hotspot.option.label
        data = hotspot.videoData
        posterData = hotspot.videoPosterData
    }

    init(item: CommunicationItem) {
        title = item.label
        data = item.videoData
        posterData = item.videoPosterData
    }

    init(page: StoryPage) {
        title = "Page video"
        data = page.videoData
        posterData = page.videoPosterData
    }

    init(step: RoutineStep) {
        title = step.title
        data = step.videoData
        posterData = step.videoPosterData
    }

    init(title: String, data: Data?, posterData: Data?) {
        self.title = title
        self.data = data
        self.posterData = posterData
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("hotspot-video-player")
                    Button("Replay video", systemImage: "gobackward") {
                        player.seek(to: .zero)
                        player.play()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("hotspot-video-replay")
                } else if let poster = posterData {
                    AsyncThumbnailImage(data: poster, maxPixelSize: 900, contentMode: .fit) {
                        Image(systemName: "video").font(.largeTitle)
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await prepareVideo() }
            .onDisappear { clearVideo() }
        }
    }

    private func prepareVideo() async {
        guard let data else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        do {
            try await Task.detached(priority: .userInitiated) {
                try data.write(to: url, options: .atomic)
            }.value
            guard !Task.isCancelled else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            videoURL = url
            let playback = AVPlayer(url: url)
            player = playback
            playback.play()
        } catch {
            try? FileManager.default.removeItem(at: url)
            errorMessage = "This video could not be played."
        }
    }

    private func clearVideo() {
        player?.pause()
        player = nil
        if let videoURL { try? FileManager.default.removeItem(at: videoURL) }
        videoURL = nil
    }
}
