import SwiftUI

struct MessageDisplayView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var facingPartner = false
    @State private var picturePDF: PDFPreviewPayload?
    @State private var audioSharePayload: AudioSharePayload?
    @State private var isPreparingAudioShare = false
    @State private var showingAudioShareError = false
    @State private var audioShareError = ""
    @ScaledMetric(relativeTo: .largeTitle) private var messageFontSize = 42
    let message: String
    var isPictureMessage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                if let highlight = store.speechHighlight,
                   highlight.source == (isPictureMessage ? .picture : .typed),
                   let word = highlight.currentUnit {
                    Text(word)
                        .font(.system(size: messageFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 18))
                        .rotationEffect(.degrees(facingPartner ? 180 : 0))
                        .accessibilityLabel("Now speaking: \(word)")
                        .accessibilityIdentifier("current-spoken-word")
                }
                ScrollView {
                    VStack(spacing: 20) {
                        if isPictureMessage {
                            PictureMessageVisual(tokens: store.pictureMessageTokens)
                                .accessibilityIdentifier("picture-message-visual")
                        }
                        if let highlight = store.speechHighlight,
                           highlight.source == (isPictureMessage ? .picture : .typed) {
                            SpeechFollowAlongView(state: highlight, large: true)
                                .frame(maxWidth: .infinity, minHeight: 180)
                                .accessibilityIdentifier("large-message")
                        } else {
                            Text(message)
                                .font(.system(size: messageFontSize, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 180)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("large-message")
                        }
                    }
                    .rotationEffect(.degrees(facingPartner ? 180 : 0))
                }
                .frame(maxHeight: 420)
                Spacer()
                Button("Speak message", systemImage: "speaker.wave.2.fill") {
                    if isPictureMessage { store.speakMessage() }
                    else { store.speak(message, saveToHistory: true, followAlong: .typed) }
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                MessagePlaybackControl(source: isPictureMessage ? .picture : .typed)
                Button(facingPartner ? "Face me" : "Face partner", systemImage: "arrow.triangle.2.circlepath") {
                    facingPartner.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Rotate the message text for someone sitting opposite you")
                .accessibilityIdentifier("flip-message")
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        ShareLink(item: message) { Label("Share message", systemImage: "square.and.arrow.up") }
                        Button(isPreparingAudioShare ? "Preparing audio…" : "Share audio", systemImage: "waveform") {
                            prepareAudioShare()
                        }
                        .disabled(isPreparingAudioShare)
                        .accessibilityIdentifier("share-large-message-audio")
                    }
                    if isPictureMessage {
                        HStack(spacing: 16) {
                        PictureMessageShareButton(tokens: store.pictureMessageTokens)
                        Button("PDF", systemImage: "doc.richtext") {
                            picturePDF = PDFPreviewPayload(data: PictureMessagePDF.makeData(
                                tokens: store.pictureMessageTokens,
                                language: store.settings.communicationLanguage))
                        }
                        .accessibilityIdentifier("picture-message-pdf")
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(24)
            .navigationTitle("Your message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(item: $picturePDF) { payload in
                PrintableBoardsPreview(data: payload.data, title: "Picture PDF",
                                       filename: "Open Voice Picture Message")
            }
            .sheet(item: $audioSharePayload) { AudioShareSheet(url: $0.url) }
            .alert("Couldn't share audio", isPresented: $showingAudioShareError) {
                Button("OK", role: .cancel) {}
            } message: { Text(audioShareError) }
        }
    }

    private func prepareAudioShare() {
        guard !isPreparingAudioShare else { return }
        isPreparingAudioShare = true
        Task {
            defer { isPreparingAudioShare = false }
            do {
                let url = try await store.exportMessageAudio(message, isPictureMessage: isPictureMessage)
                audioSharePayload = AudioSharePayload(url: url)
            } catch {
                audioShareError = error.localizedDescription
                showingAudioShareError = true
            }
        }
    }
}

private struct PictureMessageVisual: View {
    let tokens: [PictureMessageToken]
    var columns = 3
    var tileWidth: CGFloat = 100

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<((tokens.count + columns - 1) / columns), id: \.self) { row in
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    ForEach((row * columns)..<min((row + 1) * columns, tokens.count), id: \.self) { index in
                        tile(tokens[index]).frame(width: tileWidth)
                    }
                    Spacer(minLength: 0)
                }
            }
            if tokens.contains(where: { $0.arasaacPictogramID != nil }) {
                Text(ARASAACPictogramService.attribution)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func tile(_ token: PictureMessageToken) -> some View {
        VStack(spacing: 6) {
            if let data = token.imageData {
                AsyncThumbnailImage(data: data, maxPixelSize: 160) {
                    Text(token.symbol ?? "💬").font(.system(size: 48))
                }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let symbol = token.symbol, !symbol.isEmpty {
                Text(symbol).font(.system(size: 48))
                    .frame(height: 64)
            }
            Text(token.text)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 105)
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(token.text)
    }
}

private struct PictureMessageShareButton: View {
    let tokens: [PictureMessageToken]
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview("Picture message", image: image)) {
                    Label("Share picture", systemImage: "photo")
                }
                .accessibilityIdentifier("share-picture-message")
            } else {
                Label("Share picture", systemImage: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: render)
        .onChange(of: tokens) { _, _ in render() }
    }

    private func render() {
        guard !tokens.isEmpty else { image = nil; return }
        let message = tokens.map(\.text).joined(separator: " ")
        let renderer = ImageRenderer(content:
            VStack(spacing: 24) {
                PictureMessageVisual(tokens: tokens, columns: 4, tileWidth: 180)
                Text(message)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(32)
            .frame(width: 900)
            .background(Color.white))
        renderer.scale = 1
        image = renderer.uiImage.map(Image.init(uiImage:))
    }
}
