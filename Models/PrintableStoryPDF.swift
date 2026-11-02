import UIKit

enum PrintableStoryPDF {
    private struct Sheet {
        let pageNumber: Int
        let isContinuation: Bool
        let text: String
        let photos: [Data]
        let symbol: String
        let isVideo: Bool
        let backgroundStyle: StoryBackgroundStyle
        let backgroundPhotoData: Data?
    }

    static func makeData(story: VisualStory,
                         paperSize: PrintableBoardPDF.PaperSize = .local) -> Data {
        let bounds = paperSize.bounds
        let sheets = makeSheets(story: story, bounds: bounds)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for (index, sheet) in sheets.enumerated() {
                context.beginPage()
                drawHeader(title: story.title, pageNumber: sheet.pageNumber,
                           storyPageCount: story.pages.count, isContinuation: sheet.isContinuation,
                           isVideo: sheet.isVideo,
                           bounds: bounds)
                drawPageBackground(style: sheet.backgroundStyle,
                                   photoData: sheet.backgroundPhotoData, bounds: bounds)
                if !sheet.isContinuation {
                    drawPicture(images: sheet.photos, symbol: sheet.symbol,
                                backgroundStyle: sheet.backgroundStyle, bounds: bounds)
                }
                let bodyRect = textRect(bounds: bounds, hasPicture: !sheet.isContinuation)
                if sheet.backgroundStyle == .photo {
                    let panelHeight = min(bodyRect.height,
                        measuredHeight(sheet.text, width: bodyRect.width) + 22)
                    UIColor.white.withAlphaComponent(0.88).setFill()
                    UIBezierPath(roundedRect: CGRect(x: bodyRect.minX - 8, y: bodyRect.minY - 8,
                        width: bodyRect.width + 16, height: panelHeight + 16),
                        cornerRadius: 10).fill()
                }
                drawText(sheet.text, in: bodyRect,
                         font: .systemFont(ofSize: 22, weight: .medium), color: .black,
                         lineSpacing: 6)
                drawFooter(sheetNumber: index + 1, sheetCount: sheets.count, bounds: bounds)
            }
        }
    }

    private static func makeSheets(story: VisualStory, bounds: CGRect) -> [Sheet] {
        if story.pages.isEmpty {
            return [Sheet(pageNumber: 0, isContinuation: true, text: "Add a page to this story.",
                          photos: [], symbol: "📖", isVideo: false,
                          backgroundStyle: .plain, backgroundPhotoData: nil)]
        }
        var sheets: [Sheet] = []
        for (index, page) in story.pages.enumerated() {
            var remaining = story.pageText(for: page).trimmingCharacters(in: .whitespacesAndNewlines)
            var continuation = false
            repeat {
                let rect = textRect(bounds: bounds, hasPicture: !continuation)
                let count = fittingCharacterCount(remaining, width: rect.width, height: rect.height)
                let characters = Array(remaining)
                var end = min(count, characters.count)
                if end < characters.count, end > 1,
                   let wordBreak = characters[..<end].lastIndex(where: { $0.isWhitespace }),
                   wordBreak > end / 2 {
                    end = wordBreak + 1
                }
                let text = String(characters[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                sheets.append(Sheet(pageNumber: index + 1, isContinuation: continuation,
                                    text: text, photos: continuation ? [] :
                                        (page.videoData == nil ? page.photos :
                                            (page.videoPosterData.map { [$0] } ?? [])),
                                    symbol: page.symbol, isVideo: page.videoData != nil,
                                    backgroundStyle: page.backgroundStyle,
                                    backgroundPhotoData: page.backgroundPhotoData))
                remaining = String(characters.dropFirst(end)).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation = true
            } while !remaining.isEmpty
        }
        return sheets
    }

    private static func fittingCharacterCount(_ text: String, width: CGFloat, height: CGFloat) -> Int {
        let characters = Array(text)
        guard !characters.isEmpty else { return 0 }
        var low = 1
        var high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            let candidate = String(characters.prefix(middle))
            if measuredHeight(candidate, width: width) <= height - 2 {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low
    }

    private static func measuredHeight(_ text: String, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        paragraph.lineBreakMode = .byWordWrapping
        return (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 22, weight: .medium),
                         .paragraphStyle: paragraph], context: nil
        ).height
    }

    private static func textRect(bounds: CGRect, hasPicture: Bool) -> CGRect {
        let top: CGFloat = hasPicture ? 520 : 165
        return CGRect(x: 49, y: top, width: bounds.width - 98,
                      height: bounds.height - top - 65)
    }

    private static func drawHeader(title: String, pageNumber: Int, storyPageCount: Int,
                                   isContinuation: Bool, isVideo: Bool, bounds: CGRect) {
        let ink = UIColor(red: 0.10, green: 0.20, blue: 0.23, alpha: 1)
        drawText("OPEN VOICE  /  PERSONAL STORY",
                 in: CGRect(x: 49, y: 34, width: bounds.width - 98, height: 16),
                 font: .boldSystemFont(ofSize: 10), color: ink)
        drawFittedTitle(title, in: CGRect(x: 49, y: 56, width: bounds.width - 98, height: 57),
                        color: ink)
        let pageLabel = storyPageCount == 0 ? "No pages yet" :
            "Story page \(pageNumber) of \(storyPageCount)\(isContinuation ? " · continued" : "")\(isVideo ? " · video in app" : "")"
        drawText(pageLabel, in: CGRect(x: 49, y: 118, width: bounds.width - 98, height: 16),
                 font: .systemFont(ofSize: 11), color: .darkGray)
        ink.setFill()
        UIBezierPath(rect: CGRect(x: 49, y: 146, width: bounds.width - 98, height: 1)).fill()
    }

    private static func drawPageBackground(style: StoryBackgroundStyle,
                                           photoData: Data?, bounds: CGRect) {
        guard style != .plain, let context = UIGraphicsGetCurrentContext() else { return }
        let rect = CGRect(x: 49, y: 165, width: bounds.width - 98,
                          height: bounds.height - 230)
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 13).addClip()
        switch style {
        case .plain: break
        case .cream:
            UIColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1).setFill()
            context.fill(rect)
        case .mint:
            UIColor(red: 0.86, green: 0.96, blue: 0.90, alpha: 1).setFill()
            context.fill(rect)
        case .sky, .sunset:
            let colors: [CGColor] = style == .sky
                ? [UIColor(red: 0.84, green: 0.94, blue: 1, alpha: 1).cgColor,
                   UIColor(red: 0.93, green: 0.89, blue: 0.99, alpha: 1).cgColor]
                : [UIColor(red: 1, green: 0.91, blue: 0.78, alpha: 1).cgColor,
                   UIColor(red: 0.99, green: 0.83, blue: 0.87, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient,
                    start: CGPoint(x: rect.minX, y: rect.minY),
                    end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
            }
        case .photo:
            if let photoData, let image = UIImage(data: photoData),
               image.size.width > 0, image.size.height > 0 {
                let scale = max(rect.width / image.size.width, rect.height / image.size.height)
                let size = CGSize(width: image.size.width * scale,
                                  height: image.size.height * scale)
                image.draw(in: CGRect(x: rect.midX - size.width / 2,
                                      y: rect.midY - size.height / 2,
                                      width: size.width, height: size.height))
            }
        }
        context.restoreGState()
    }

    private static func drawPicture(images: [Data], symbol: String,
                                    backgroundStyle: StoryBackgroundStyle, bounds: CGRect) {
        let rect = CGRect(x: 49, y: 165, width: bounds.width - 98, height: 333)
        let shape = UIBezierPath(roundedRect: rect, cornerRadius: 13)
        if backgroundStyle == .plain {
            UIColor(red: 0.94, green: 0.97, blue: 0.97, alpha: 1).setFill()
            shape.fill()
        }
        let photos = images.compactMap(UIImage.init(data:)).filter {
            $0.size.width > 0 && $0.size.height > 0
        }
        if photos.count > 1 {
            let columns = 2
            let rows = (photos.count + 1) / 2
            let gap: CGFloat = 8
            let cellWidth = (rect.width - gap) / CGFloat(columns)
            let cellHeight = (rect.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            for (index, image) in photos.enumerated() {
                let cell = photos.count == 3 && index == 2
                    ? CGRect(x: rect.minX, y: rect.minY + cellHeight + gap,
                             width: rect.width, height: cellHeight)
                    : CGRect(x: rect.minX + CGFloat(index % columns) * (cellWidth + gap),
                             y: rect.minY + CGFloat(index / columns) * (cellHeight + gap),
                             width: cellWidth, height: cellHeight)
                let crop = max(cell.width / image.size.width, cell.height / image.size.height)
                let scaled = CGSize(width: image.size.width * crop, height: image.size.height * crop)
                let drawRect = CGRect(x: cell.midX - scaled.width / 2,
                                      y: cell.midY - scaled.height / 2,
                                      width: scaled.width, height: scaled.height)
                let context = UIGraphicsGetCurrentContext()
                context?.saveGState()
                UIBezierPath(roundedRect: cell, cornerRadius: 9).addClip()
                image.draw(in: drawRect)
                context?.restoreGState()
            }
        } else if let image = photos.first {
            let scale = min(rect.width / image.size.width, rect.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: rect.midX - size.width / 2,
                                  y: rect.midY - size.height / 2,
                                  width: size.width, height: size.height))
        } else {
            drawText(symbol.isEmpty ? "📖" : symbol, in: rect.insetBy(dx: 10, dy: 83),
                     font: .systemFont(ofSize: 110), color: .black, alignment: .center)
        }
    }

    private static func drawFooter(sheetNumber: Int, sheetCount: Int, bounds: CGRect) {
        let y = bounds.height - 43
        drawText("Made with Open Voice", in: CGRect(x: 49, y: y, width: 300, height: 15),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("\(sheetNumber) / \(sheetCount)",
                 in: CGRect(x: bounds.width - 100, y: y, width: 51, height: 15),
                 font: .systemFont(ofSize: 9), color: .darkGray, alignment: .right)
    }

    private static func drawFittedTitle(_ title: String, in rect: CGRect, color: UIColor) {
        for size in stride(from: CGFloat(30), through: 16, by: -1) {
            let font = UIFont.boldSystemFont(ofSize: size)
            let height = (title as NSString).boundingRect(
                with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font], context: nil).height
            if height <= rect.height || size == 16 {
                drawText(title, in: rect, font: font, color: color)
                return
            }
        }
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor,
                                 alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}
