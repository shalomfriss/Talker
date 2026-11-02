import UIKit

enum PictureMessagePDF {
    private struct Row {
        let text: String
        let imageData: Data?
        let arasaacPictogramID: Int?
        let symbol: String?
        let isContinuation: Bool
        let height: CGFloat
    }

    private static let margin: CGFloat = 42
    private static let bodyTop: CGFloat = 145
    private static let bottomMargin: CGFloat = 84
    private static let rowGap: CGFloat = 10
    private static let imagePanelWidth: CGFloat = 100
    private static let textFont = UIFont.systemFont(ofSize: 19, weight: .semibold)

    static func makeData(tokens: [PictureMessageToken], language: String = "en",
                         paperSize: PrintableBoardPDF.PaperSize = .local) -> Data {
        let bounds = paperSize.bounds
        let rows = makeRows(tokens: tokens, bounds: bounds)
        let pages = paginate(rows, bounds: bounds)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()
                drawHeader(language: language, bounds: bounds)
                var y = bodyTop
                for row in page {
                    drawRow(row, at: y, bounds: bounds)
                    y += row.height + rowGap
                }
                drawFooter(page: index + 1, count: pages.count, language: language,
                           includesARASAAC: page.contains { $0.arasaacPictogramID != nil },
                           bounds: bounds)
            }
        }
    }

    private static func makeRows(tokens: [PictureMessageToken], bounds: CGRect) -> [Row] {
        guard !tokens.isEmpty else {
            return [Row(text: "No words in this message.", imageData: nil,
                        arasaacPictogramID: nil, symbol: nil, isContinuation: false, height: 112)]
        }
        let width = textWidth(bounds: bounds)
        let maxTextHeight = bounds.height - bodyTop - bottomMargin - 30
        var rows: [Row] = []
        for token in tokens {
            var remaining = token.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if remaining.isEmpty { remaining = " " }
            var continuation = false
            repeat {
                let characters = Array(remaining)
                let fitting = fittingCharacterCount(remaining, width: width, height: maxTextHeight)
                var end = min(max(1, fitting), characters.count)
                if end < characters.count,
                   let wordBreak = characters[..<end].lastIndex(where: { $0.isWhitespace }),
                   wordBreak > end / 2 {
                    end = wordBreak + 1
                }
                let piece = String(characters[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                let height = min(bounds.height - bodyTop - bottomMargin,
                                 max(112, measuredHeight(piece, width: width) + 28))
                rows.append(Row(text: piece, imageData: continuation ? nil : token.imageData,
                                arasaacPictogramID: continuation ? nil : token.arasaacPictogramID,
                                symbol: continuation ? nil : token.symbol,
                                isContinuation: continuation, height: height))
                remaining = String(characters.dropFirst(end))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation = true
            } while !remaining.isEmpty
        }
        return rows
    }

    private static func paginate(_ rows: [Row], bounds: CGRect) -> [[Row]] {
        let available = bounds.height - bodyTop - bottomMargin
        var pages: [[Row]] = [[]]
        var used: CGFloat = 0
        for row in rows {
            let gap = pages[pages.count - 1].isEmpty ? 0 : rowGap
            if used + gap + row.height > available {
                pages.append([])
                used = 0
            } else {
                used += gap
            }
            pages[pages.count - 1].append(row)
            used += row.height
        }
        return pages
    }

    private static func drawHeader(language: String, bounds: CGRect) {
        let ink = UIColor(red: 0.10, green: 0.20, blue: 0.23, alpha: 1)
        drawText(language == "es" ? "OPEN VOICE  /  MENSAJE CON IMÁGENES" :
                    "OPEN VOICE  /  PICTURE MESSAGE",
                 in: CGRect(x: margin, y: 30, width: bounds.width - margin * 2, height: 18),
                 font: .boldSystemFont(ofSize: 10), color: ink)
        drawText(language == "es" ? "Palabras e imágenes" : "Words and pictures",
                 in: CGRect(x: margin, y: 55, width: bounds.width - margin * 2, height: 42),
                 font: .boldSystemFont(ofSize: 28), color: ink)
        drawText(language == "es" ? "Lee de arriba abajo." : "Read from top to bottom.",
                 in: CGRect(x: margin, y: 105, width: bounds.width - margin * 2, height: 18),
                 font: .systemFont(ofSize: 11), color: .darkGray)
        ink.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: 133,
                                  width: bounds.width - margin * 2, height: 1)).fill()
    }

    private static func drawRow(_ row: Row, at y: CGFloat, bounds: CGRect) {
        let rect = CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: row.height)
        let panel = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        UIColor(red: 0.96, green: 0.98, blue: 0.98, alpha: 1).setFill()
        panel.fill()
        UIColor(red: 0.72, green: 0.79, blue: 0.79, alpha: 1).setStroke()
        panel.lineWidth = 1
        panel.stroke()

        let imageRect = CGRect(x: rect.minX + 12, y: rect.minY + 14,
                               width: imagePanelWidth - 16, height: 82)
        if let data = row.imageData, let image = UIImage(data: data),
           image.size.width > 0, image.size.height > 0 {
            let scale = min(imageRect.width / image.size.width, imageRect.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: imageRect.midX - size.width / 2,
                                  y: imageRect.midY - size.height / 2,
                                  width: size.width, height: size.height))
        } else if let symbol = row.symbol, !symbol.isEmpty {
            drawText(symbol, in: imageRect, font: .systemFont(ofSize: 59),
                     color: .black, alignment: .center)
        } else {
            drawText(row.isContinuation ? "CONT." : "TEXT", in: imageRect,
                     font: .boldSystemFont(ofSize: 11), color: .darkGray,
                     alignment: .center)
        }
        let textRect = CGRect(x: rect.minX + imagePanelWidth + 20,
                              y: rect.minY + 12,
                              width: textWidth(bounds: bounds), height: rect.height - 24)
        let measured = measuredHeight(row.text, width: textRect.width)
        let centered = CGRect(x: textRect.minX,
                              y: textRect.minY + max(0, (textRect.height - measured) / 2),
                              width: textRect.width, height: min(measured + 3, textRect.height))
        drawText(row.text, in: centered, font: textFont, color: .black)
    }

    private static func drawFooter(page: Int, count: Int, language: String,
                                   includesARASAAC: Bool, bounds: CGRect) {
        let y = bounds.height - 48
        if includesARASAAC {
            drawText(ARASAACPictogramService.attribution,
                     in: CGRect(x: margin, y: y - 31,
                                width: bounds.width - margin * 2, height: 12),
                     font: .systemFont(ofSize: 6.5), color: .darkGray)
        }
        UIColor(red: 0.10, green: 0.20, blue: 0.23, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y - 11,
                                  width: bounds.width - margin * 2, height: 1)).fill()
        drawText(language == "es" ? "Creado con Open Voice" : "Made with Open Voice",
                 in: CGRect(x: margin, y: y, width: 300, height: 15),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("\(page) / \(count)",
                 in: CGRect(x: bounds.width - margin - 55, y: y, width: 55, height: 15),
                 font: .systemFont(ofSize: 9), color: .darkGray, alignment: .right)
    }

    private static func textWidth(bounds: CGRect) -> CGFloat {
        bounds.width - margin * 2 - imagePanelWidth - 32
    }

    private static func fittingCharacterCount(_ text: String, width: CGFloat, height: CGFloat) -> Int {
        let characters = Array(text)
        guard !characters.isEmpty else { return 0 }
        var low = 1
        var high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            if measuredHeight(String(characters.prefix(middle)), width: width) <= height {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low
    }

    private static func measuredHeight(_ text: String, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.lineBreakMode = .byWordWrapping
        return (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: textFont, .paragraphStyle: paragraph], context: nil
        ).height
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont,
                                 color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 3
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}
