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
                } else if let poster = posterData,
                          let image = UIImage(data: poster) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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
            .onAppear { prepareVideo() }
            .onDisappear { clearVideo() }
        }
    }

    private func prepareVideo() {
        guard let data else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        do {
            try data.write(to: url, options: .atomic)
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
