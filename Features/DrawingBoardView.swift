import SwiftUI

struct DrawingBoardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [DrawingStroke] = []
    @State private var currentStroke: DrawingStroke?
    @State private var undoneStrokes: [DrawingStroke] = []
    @State private var ink: DrawingInk = .black
    @State private var lineWidth: Double = 5
    @State private var showingDisplay = false
    @State private var confirmingClear = false
    @State private var showingWritingReview = false
    @State private var isReadingWriting = false
    @State private var recognizedWriting = ""
    @State private var recognitionNotice: String?
    @State private var recognitionFeedback: String?
    @State private var recognitionError: String?
    @State private var recognitionAttemptID = UUID()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Draw something to show another person. Your drawing stays with this profile.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(DrawingInk.allCases, id: \.self) { option in
                            Button {
                                ink = option
                            } label: {
                                Label(option.name, systemImage: option == .eraser ? "eraser.fill" : "pencil.tip")
                            }
                            .buttonStyle(.bordered)
                            .tint(ink == option ? (store.settings.highContrast ? .black : .indigo) : .gray)
                            .accessibilityValue(ink == option ? "Selected" : "")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                HStack {
                    Menu {
                        Button("Thin") { lineWidth = 3 }
                        Button("Medium") { lineWidth = 5 }
                        Button("Thick") { lineWidth = 10 }
                    } label: {
                        Label("Width", systemImage: "line.diagonal")
                    }
                    .accessibilityValue(lineWidth == 3 ? "Thin" : (lineWidth == 10 ? "Thick" : "Medium"))
                    Spacer()
                    Button("Undo", systemImage: "arrow.uturn.backward") { undo() }
                        .disabled(strokes.isEmpty)
                    Button("Redo", systemImage: "arrow.uturn.forward") { redo() }
                        .disabled(undoneStrokes.isEmpty)
                    Button("Clear", systemImage: "trash") { confirmingClear = true }
                        .disabled(strokes.isEmpty)
                }
                GeometryReader { proxy in
                    let size = CGSize(width: min(proxy.size.width, proxy.size.height * 4 / 3),
                                      height: min(proxy.size.height, proxy.size.width * 3 / 4))
                    DrawingSurface(strokes: strokes, activeStroke: currentStroke)
                        .frame(width: size.width, height: size.height)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in draw(at: value.location, start: value.startLocation, size: size) }
                            .onEnded { value in finishDrawing(at: value.location, start: value.startLocation, size: size) })
                        .accessibilityLabel("Drawing canvas, \(strokes.count) marks")
                        .accessibilityHint("Draw with a finger or Apple Pencil. Use Undo, Redo, or Clear to edit.")
                        .accessibilityIdentifier("drawing-canvas")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: 12) {
                    Button("Show partner", systemImage: "rectangle.expand.vertical") { showingDisplay = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(strokes.isEmpty)
                        .accessibilityIdentifier("show-drawing")
                    DrawingShareButton(strokes: strokes)
                        .buttonStyle(.bordered)
                }
                .controlSize(.large)
                Button("Read handwriting", systemImage: "text.viewfinder") {
                    readHandwriting()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(strokes.isEmpty || isReadingWriting)
                .accessibilityIdentifier("read-drawing-writing")
                if isReadingWriting { ProgressView("Reading writing") }
                if let recognitionFeedback {
                    Text(recognitionFeedback)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("drawing-recognition-feedback")
                }
            }
            .padding(16)
            .navigationTitle("Drawing board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingDisplay) { DrawingDisplayView(strokes: strokes) }
            .sheet(isPresented: $showingWritingReview) {
                NavigationStack {
                    Form {
                        Section("Recognized words") {
                            TextField("Correct the words here", text: $recognizedWriting, axis: .vertical)
                                .lineLimit(3...8)
                                .accessibilityIdentifier("recognized-drawing-text")
                            Text(recognitionNotice ??
                                 "Check and edit these words before speaking or adding them to your message.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Section {
                            Button("Speak reviewed words", systemImage: "speaker.wave.2") {
                                store.speak(recognizedWriting, saveToHistory: true)
                            }
                            .disabled(recognizedWriting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("speak-drawing-text")
                            Button("Add to typed message", systemImage: "text.badge.plus") {
                                if store.appendTypedPhrase(recognizedWriting) {
                                    recognitionFeedback = "Added to the typed message. Open Type in Speak to review it."
                                    showingWritingReview = false
                                }
                            }
                            .disabled(recognizedWriting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("add-drawing-text")
                        }
                    }
                    .navigationTitle("Review writing")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingWritingReview = false }
                        }
                    }
                }
            }
            .alert("Could not read writing", isPresented: Binding(
                get: { recognitionError != nil }, set: { if !$0 { recognitionError = nil } }
            )) {
                Button("OK") { recognitionError = nil }
            } message: {
                Text(recognitionError ?? "Try writing larger, or use Type in Speak.")
            }
            .confirmationDialog("Clear this drawing?", isPresented: $confirmingClear) {
                Button("Clear drawing", role: .destructive) {
                    strokes = []
                    currentStroke = nil
                    undoneStrokes = []
                    store.updateDrawing(strokes)
                }
            }
            .onAppear { loadProfileDrawing() }
            .onChange(of: store.activeProfileID) { _, _ in loadProfileDrawing() }
            .onChange(of: strokes) { _, _ in invalidateRecognition() }
        }
    }

    private func loadProfileDrawing() {
        strokes = store.drawingStrokes
        currentStroke = nil
        undoneStrokes = []
        invalidateRecognition()
    }

    private func invalidateRecognition() {
        recognitionAttemptID = UUID()
        isReadingWriting = false
        recognitionFeedback = nil
        recognitionError = nil
        recognitionNotice = nil
        showingWritingReview = false
    }

    private func readHandwriting() {
        guard !strokes.isEmpty else { return }
        let renderer = ImageRenderer(content:
            DrawingSurface(strokes: strokes)
                .frame(width: 960, height: 720)
                .background(.white))
        renderer.scale = 1
        guard let imageData = renderer.uiImage?.pngData() else {
            recognitionError = "Could not prepare the drawing. Try again."
            return
        }
        let attemptID = UUID()
        recognitionAttemptID = attemptID
        recognitionError = nil
        recognitionFeedback = nil
        isReadingWriting = true
        Task { @MainActor in
            do {
                let words = try await Task.detached(priority: .userInitiated) {
                    try DrawingTextRecognition.recognize(imageData: imageData)
                }.value
                guard recognitionAttemptID == attemptID else { return }
                recognizedWriting = words
                recognitionNotice = nil
                showingWritingReview = true
            } catch DrawingTextRecognitionError.noWriting {
                guard recognitionAttemptID == attemptID else { return }
                recognizedWriting = ""
                recognitionNotice = "No words were recognized. Type what you wrote, then speak or add it."
                showingWritingReview = true
            } catch {
                guard recognitionAttemptID == attemptID else { return }
                recognitionError = error.localizedDescription
            }
            isReadingWriting = false
        }
    }

    private func draw(at location: CGPoint, start: CGPoint, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let point = DrawingPoint(location, in: size)
        if currentStroke == nil {
            currentStroke = DrawingStroke(points: [DrawingPoint(start, in: size)], ink: ink,
                                          width: ink == .eraser ? 20 : lineWidth)
        }
        if currentStroke?.points.last != point { currentStroke?.points.append(point) }
    }

    private func finishDrawing(at location: CGPoint, start: CGPoint, size: CGSize) {
        draw(at: location, start: start, size: size)
        guard let currentStroke else { return }
        strokes.append(currentStroke)
        self.currentStroke = nil
        undoneStrokes = []
        store.updateDrawing(strokes)
    }

    private func undo() {
        guard let stroke = strokes.popLast() else { return }
        undoneStrokes.append(stroke)
        store.updateDrawing(strokes)
    }

    private func redo() {
        guard let stroke = undoneStrokes.popLast() else { return }
        strokes.append(stroke)
        store.updateDrawing(strokes)
    }
}
