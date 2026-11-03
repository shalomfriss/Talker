import ImageIO
import SwiftUI

@MainActor
enum ThumbnailImageCache {
    nonisolated static let defaultPixelSize = 240
    struct Decoded: @unchecked Sendable {
        let image: UIImage
        let cost: Int
    }

    private final class Entry {
        // Retain the source to verify cache hits if an address is reused.
        let data: Data
        let image: UIImage

        init(data: Data, image: UIImage) {
            self.data = data
            self.image = image
        }
    }

    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 250
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func key(for data: Data, maxPixelSize: Int = defaultPixelSize) -> String {
        data.withUnsafeBytes { bytes in
            "\(maxPixelSize):\(bytes.count):\(String(describing: bytes.baseAddress))"
        }
    }

    static func cachedImage(for data: Data, maxPixelSize: Int = defaultPixelSize) -> UIImage? {
        guard let entry = cache.object(forKey: key(for: data, maxPixelSize: maxPixelSize) as NSString),
              entry.data == data else { return nil }
        return entry.image
    }

    static func image(for data: Data, maxPixelSize: Int = defaultPixelSize) -> UIImage? {
        if let cached = cachedImage(for: data, maxPixelSize: maxPixelSize) { return cached }
        guard let decoded = decode(data, maxPixelSize: maxPixelSize) else { return nil }
        store(decoded, for: data, maxPixelSize: maxPixelSize)
        return decoded.image
    }

    static func store(_ decoded: Decoded, for data: Data, maxPixelSize: Int = defaultPixelSize) {
        cache.setObject(Entry(data: data, image: decoded.image),
                        forKey: key(for: data, maxPixelSize: maxPixelSize) as NSString,
                        cost: decoded.cost + data.count)
    }

    nonisolated static func decode(_ data: Data, maxPixelSize: Int) -> Decoded? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return Decoded(image: UIImage(cgImage: thumbnail), cost: thumbnail.bytesPerRow * thumbnail.height)
    }
}

struct AsyncThumbnailImage<Placeholder: View>: View {
    let data: Data
    let maxPixelSize: Int
    let contentMode: ContentMode
    let placeholder: Placeholder
    @State private var loadedKey: String?
    @State private var image: UIImage?

    init(data: Data, maxPixelSize: Int = ThumbnailImageCache.defaultPixelSize,
         contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.data = data
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        let key = ThumbnailImageCache.key(for: data, maxPixelSize: maxPixelSize)
        Group {
            if loadedKey == key, let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: key) {
            if let cached = ThumbnailImageCache.cachedImage(for: data, maxPixelSize: maxPixelSize) {
                image = cached
                loadedKey = key
                return
            }
            image = nil
            loadedKey = nil
            let decoded = await Task.detached(priority: .userInitiated) {
                ThumbnailImageCache.decode(data, maxPixelSize: maxPixelSize)
            }.value
            guard !Task.isCancelled, let decoded else { return }
            ThumbnailImageCache.store(decoded, for: data, maxPixelSize: maxPixelSize)
            image = decoded.image
            loadedKey = key
        }
    }
}

struct PointerDwellState {
    private(set) var anchor: CGPoint?
    private(set) var generation = 0
    private(set) var activated = false

    var isWaiting: Bool { anchor != nil && !activated }

    @discardableResult
    mutating func moved(to location: CGPoint, tolerance: CGFloat = 16) -> Bool {
        guard !activated else { return false }
        if let anchor, hypot(location.x - anchor.x, location.y - anchor.y) <= tolerance {
            return false
        }
        anchor = location
        generation += 1
        return true
    }

    @discardableResult
    mutating func activate(generation expected: Int) -> Bool {
        guard isWaiting, generation == expected else { return false }
        activated = true
        return true
    }

    mutating func leave() {
        anchor = nil
        activated = false
        generation += 1
    }
}

struct PointerDwellModifier: ViewModifier {
    let duration: Double
    let highContrast: Bool
    let action: () -> Void
    @State private var state = PointerDwellState()
    @State private var progress = 0.0
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if duration > 0 && state.isWaiting {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(highContrast ? Color.black : Color.indigo,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 24, height: 24)
                        .padding(8)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .onContinuousHover { phase in
                guard duration > 0 else { return }
                switch phase {
                case .active(let point):
                    start(at: point)
                case .ended:
                    cancel()
                }
            }
            .onHover { hovering in
                guard duration > 0 else { return }
                if hovering {
                    if state.anchor == nil { start(at: .zero) }
                } else {
                    cancel()
                }
            }
            .onChange(of: duration) { _, _ in cancel() }
            .onDisappear { cancel() }
    }

    private func start(at point: CGPoint) {
        guard state.moved(to: point) else { return }
        pending?.cancel()
        let generation = state.generation
        progress = 0
        withAnimation(.linear(duration: duration)) { progress = 1 }
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, state.activate(generation: generation) else { return }
            progress = 0
            action()
        }
    }

    private func cancel() {
        pending?.cancel()
        pending = nil
        state.leave()
        progress = 0
    }
}

extension View {
    @ViewBuilder
    func pointerDwell(duration: Double, highContrast: Bool, action: @escaping () -> Void) -> some View {
        if duration > 0 {
            modifier(PointerDwellModifier(duration: duration, highContrast: highContrast, action: action))
        } else {
            self
        }
    }
}

struct CommunicationTile: View {
    let item: CommunicationItem
    let size: TileSize
    let highContrast: Bool
    let grammarColorScheme: GrammarColorScheme
    let isScanHighlighted: Bool
    let isFocusHighlighted: Bool
    let isSuggested: Bool
    let isRecentlyUsed: Bool
    let isTimeOfDayHighlighted: Bool
    let isFinderHighlighted: Bool
    let holdDuration: Double
    let pointerDwellDuration: Double
    let contentOpacity: Double
    let minimumHeight: CGFloat?
    let displayLabel: String?
    let showsLabel: Bool
    let action: () -> Void

    init(item: CommunicationItem, size: TileSize, highContrast: Bool,
         grammarColorScheme: GrammarColorScheme = .board,
         isScanHighlighted: Bool, isFocusHighlighted: Bool = false, isSuggested: Bool = false,
         isRecentlyUsed: Bool = false, isTimeOfDayHighlighted: Bool = false,
         isFinderHighlighted: Bool = false,
         holdDuration: Double = 0, pointerDwellDuration: Double = 0,
         contentOpacity: Double = 1, minimumHeight: CGFloat? = nil,
         displayLabel: String? = nil, showsLabel: Bool = true, action: @escaping () -> Void) {
        self.item = item
        self.size = size
        self.highContrast = highContrast
        self.grammarColorScheme = grammarColorScheme
        self.isScanHighlighted = isScanHighlighted
        self.isFocusHighlighted = isFocusHighlighted
        self.isSuggested = isSuggested
        self.isRecentlyUsed = isRecentlyUsed
        self.isTimeOfDayHighlighted = isTimeOfDayHighlighted
        self.isFinderHighlighted = isFinderHighlighted
        self.holdDuration = holdDuration
        self.pointerDwellDuration = pointerDwellDuration
        self.contentOpacity = contentOpacity
        self.minimumHeight = minimumHeight
        self.displayLabel = displayLabel
        self.showsLabel = showsLabel
        self.action = action
    }

    private var large: Bool { size == .large }
    private var symbolSize: CGFloat { large ? 42 : (size == .compact ? 27 : 32) }
    private var labelSize: CGFloat {
        item.labelFontSize.map(CGFloat.init) ?? (large ? 18 : (size == .compact ? 14 : 16))
    }
    private var imageHeight: CGFloat { large ? 78 : (size == .compact ? 42 : 52) }
    private var tileHeight: CGFloat { minimumHeight ?? size.minimumTileHeight }
    private var scanColor: Color { isScanHighlighted ? (highContrast ? .black : .orange) : .clear }
    private var focusColor: Color { isFocusHighlighted ? (highContrast ? .black : .purple) : .clear }
    private var suggestionColor: Color { isSuggested ? (highContrast ? .black : .teal) : .clear }
    private var recentColor: Color {
        (isRecentlyUsed || isTimeOfDayHighlighted)
            ? (highContrast ? .black : Color(red: 0.70, green: 0.46, blue: 0.02)) : .clear
    }
    private var finderColor: Color { isFinderHighlighted ? (highContrast ? .black : .pink) : .clear }
    private var customBackground: ButtonColorValue? {
        (item.backgroundColorHex ?? GrammarColorCoding.colors(for: item, scheme: grammarColorScheme).background)
            .flatMap(ButtonColorValue.init(text:))
    }
    private var customBorder: ButtonColorValue? {
        (item.borderColorHex ?? GrammarColorCoding.colors(for: item, scheme: grammarColorScheme).border)
            .flatMap(ButtonColorValue.init(text:))
    }
    private var tileBackground: Color {
        if highContrast { return .white }
        return customBackground.map(ButtonColorAppearance.color) ?? colorForCategory(item.category)
    }
    private var tileForeground: Color {
        if highContrast { return .black }
        return customBackground?.prefersDarkText == false ? .white : .black
    }
    private var tileBorder: Color {
        if highContrast { return .black }
        return customBorder.map(ButtonColorAppearance.color) ?? .clear
    }

    private var hasMeaningfulVisual: Bool {
        item.imageData != nil || item.videoPosterData != nil ||
            (!item.symbol.isEmpty && item.symbol != "💬")
    }

    private var tileContent: some View {
        VStack(spacing: 8) {
            if let data = item.effectiveAction == .playVideo ? item.videoPosterData : item.imageData {
                AsyncThumbnailImage(data: data) {
                    Text(item.symbol)
                        .font(.system(size: symbolSize))
                        .accessibilityHidden(true)
                }
                .frame(height: imageHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if item.effectiveAction == .typeText, item.label.count == 1 {
                Text(displayLabel ?? item.label)
                    .font(.system(size: item.labelFontSize.map(CGFloat.init) ?? (large ? 44 : 34),
                                  weight: .bold))
                    .accessibilityHidden(true)
            } else {
                Text(item.symbol)
                    .font(.system(size: symbolSize))
                    .accessibilityHidden(true)
            }
            if (showsLabel || !hasMeaningfulVisual)
                && !(item.effectiveAction == .typeText && item.label.count == 1) {
                Text(displayLabel ?? item.label)
                    .font(.system(size: labelSize, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: tileHeight)
        .padding(item.contentPadding.map(CGFloat.init) ?? 8)
        .foregroundStyle(tileForeground)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tileBorder, lineWidth: 2))
        .opacity(contentOpacity)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(recentColor, lineWidth: 3))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(focusColor, lineWidth: 4))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(suggestionColor, lineWidth: 3))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(finderColor, lineWidth: 5))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(scanColor, lineWidth: 5))
        .overlay(alignment: .topLeading) {
            if isFocusHighlighted || isSuggested || isFinderHighlighted {
                HStack(spacing: 3) {
                    if isFocusHighlighted {
                        Image(systemName: "scope")
                            .foregroundStyle(highContrast ? .black : .purple)
                    }
                    if isSuggested {
                        Image(systemName: "sparkles")
                            .foregroundStyle(highContrast ? .black : .teal)
                    }
                    if isFinderHighlighted {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(highContrast ? .black : .pink)
                    }
                }
                .font(.caption.bold())
                .padding(7)
                .accessibilityHidden(true)
            }
        }
    }

    private var button: some View {
        Button(action: action) {
            tileContent.overlay(alignment: .topTrailing) {
                if item.destinationBoard != nil {
                    Image(systemName: "arrow.right.square.fill")
                        .font(.caption)
                        .foregroundStyle(highContrast ? .black : .indigo)
                        .padding(6)
                        .accessibilityHidden(true)
                } else if item.effectiveAction == .playVideo {
                    Image(systemName: "play.rectangle.fill")
                        .font(.caption)
                        .foregroundStyle(highContrast ? .black : .indigo)
                        .padding(6)
                        .accessibilityHidden(true)
                } else if item.phraseOptions?.isEmpty == false {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(highContrast ? .black : .indigo)
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    var body: some View {
        Group {
            if holdDuration > 0 {
                button.buttonStyle(HoldToActivateStyle(duration: holdDuration))
            } else {
                button.buttonStyle(.plain)
            }
        }
        .accessibilityLabel(displayLabel ?? item.label)
        .accessibilityHint(item.effectiveAction.isTypingAction ? item.effectiveAction.title
            : item.effectiveAction == .playVideo ? "Play video" : item.destinationBoard.map {
            item.linkBehavior == .visit ? "Visit \($0) for one word" : "Open \($0) board"
        } ?? (item.phraseOptions?.isEmpty == false
              ? "Choose the word or a spoken phrase"
              : (holdDuration > 0 ? "Hold to add to message" : "Add to message")))
        .accessibilityAction { action() }
        .accessibilityAddTraits(isScanHighlighted ? .isSelected : [])
        .accessibilityValue([
            item.boardVisibility == .dimmed ? "Dimmed" : nil,
            isFocusHighlighted ? "Focus word" : nil,
            isSuggested ? "Suggested next" : nil,
            isRecentlyUsed ? "Recently used" : nil,
            isTimeOfDayHighlighted ? "Often used at this time" : nil,
            isFinderHighlighted ? "Word finder target" : nil,
            pointerDwellDuration > 0 ? "Pointer dwell \(pointerDwellDuration) seconds" : nil,
            grammarColorScheme != .board && !highContrast
                ? GrammarColorCoding.category(for: item).map { "Grammar color: \($0.title)" } : nil
        ].compactMap { $0 }.joined(separator: ", "))
        .pointerDwell(duration: pointerDwellDuration, highContrast: highContrast, action: action)
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Core": Color(red: 0.87, green: 0.91, blue: 1)
        case "Needs": Color(red: 1, green: 0.91, blue: 0.78)
        case "Feelings": Color(red: 1, green: 0.88, blue: 0.9)
        case "Sensory": Color(red: 0.88, green: 0.84, blue: 0.98)
        default: Color(red: 0.86, green: 0.95, blue: 0.89)
        }
    }
}

enum ButtonColorAppearance {
    static func color(_ value: ButtonColorValue) -> Color {
        Color(.sRGB, red: Double(value.red) / 255, green: Double(value.green) / 255,
              blue: Double(value.blue) / 255, opacity: Double(value.alpha) / 255)
    }

    static func hex(from color: Color) -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func channel(_ value: CGFloat) -> Int {
            min(255, max(0, Int((value * 255).rounded())))
        }
        return ButtonColorValue(red: channel(red), green: channel(green),
                                blue: channel(blue), alpha: channel(alpha)).hex
    }
}
