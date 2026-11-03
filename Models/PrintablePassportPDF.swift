import UIKit

enum PrintablePassportPDF {
    private struct Block {
        let title: String
        let text: String
        let height: CGFloat
    }

    private static let margin: CGFloat = 42
    private static let contentTop: CGFloat = 147
    private static let footerHeight: CGFloat = 62
    private static let blockGap: CGFloat = 8
    private static let bodyFont = UIFont.systemFont(ofSize: 16)
    private static let ink = UIColor(red: 0.11, green: 0.17, blue: 0.28, alpha: 1)
    private static let accent = UIColor(red: 0.29, green: 0.27, blue: 0.74, alpha: 1)

    static func makeData(passport: CommunicationPassport,
                         paperSize: PrintableBoardPDF.PaperSize = .local) -> Data {
        let bounds = paperSize.bounds
        let blocks = makeBlocks(passport: passport, bounds: bounds)
        let pages = paginate(blocks, bounds: bounds)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()
                drawHeader(in: bounds)
                var y = contentTop
                for block in page {
                    drawBlock(block, at: y, in: bounds)
                    y += block.height + blockGap
                }
                drawFooter(page: index + 1, count: pages.count, in: bounds)
            }
        }
    }

    private static func makeBlocks(passport: CommunicationPassport, bounds: CGRect) -> [Block] {
        let textWidth = bounds.width - margin * 2 - 32
        let maximumBodyHeight = bounds.height - contentTop - footerHeight - 65
        if passport.entries.isEmpty {
            return [Block(title: "My communication passport",
                          text: "Add information in Open Voice before sharing this passport.",
                          height: 100)]
        }
        return passport.entries.flatMap { entry -> [Block] in
            var remaining = entry.value
            var continuation = false
            var result: [Block] = []
            repeat {
                let characters = Array(remaining)
                var end = min(characters.count,
                              max(1, fittingCharacterCount(remaining, width: textWidth,
                                                           maximumHeight: maximumBodyHeight)))
                if end < characters.count,
                   let wordBreak = characters[..<end].lastIndex(where: { $0.isWhitespace }),
                   wordBreak > end / 2 {
                    end = wordBreak + 1
                }
                let piece = String(characters[..<end])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let title = continuation ? "\(entry.title) (continued)" : entry.title
                let height = max(72, ceil(measuredHeight(piece, width: textWidth)) + 48)
                result.append(Block(title: title, text: piece, height: height))
                remaining = String(characters.dropFirst(end))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation = true
            } while !remaining.isEmpty
            return result
        }
    }

    private static func paginate(_ blocks: [Block], bounds: CGRect) -> [[Block]] {
        var pages: [[Block]] = [[]]
        var y = contentTop
        let bottom = bounds.height - footerHeight
        for block in blocks {
            if y + block.height > bottom && !pages[pages.count - 1].isEmpty {
                pages.append([])
                y = contentTop
            }
            pages[pages.count - 1].append(block)
            y += block.height + blockGap
        }
        return pages
    }

    private static func drawHeader(in bounds: CGRect) {
        drawText("OPEN VOICE  /  COMMUNICATION PASSPORT",
                 in: CGRect(x: margin, y: 28, width: bounds.width - margin * 2, height: 17),
                 font: .boldSystemFont(ofSize: 10), color: accent)
        drawText("My communication passport",
                 in: CGRect(x: margin, y: 55, width: bounds.width - margin * 2, height: 40),
                 font: .boldSystemFont(ofSize: 27), color: ink)
        drawText("Information I choose to share",
                 in: CGRect(x: margin, y: 104, width: bounds.width - margin * 2, height: 19),
                 font: .systemFont(ofSize: 12), color: .darkGray)
        accent.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: 132,
                                  width: bounds.width - margin * 2, height: 2)).fill()
    }

    private static func drawBlock(_ block: Block, at y: CGFloat, in bounds: CGRect) {
        let rect = CGRect(x: margin, y: y,
                          width: bounds.width - margin * 2, height: block.height)
        UIColor(red: 0.96, green: 0.96, blue: 0.99, alpha: 1).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        drawText(block.title.uppercased(),
                 in: CGRect(x: rect.minX + 16, y: rect.minY + 10,
                            width: rect.width - 32, height: 17),
                 font: .boldSystemFont(ofSize: 11), color: accent)
        drawText(block.text,
                 in: CGRect(x: rect.minX + 16, y: rect.minY + 34,
                            width: rect.width - 32, height: rect.height - 42),
                 font: bodyFont, color: ink)
    }

    private static func drawFooter(page: Int, count: Int, in bounds: CGRect) {
        UIColor.lightGray.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: bounds.height - 51,
                                  width: bounds.width - margin * 2, height: 1)).fill()
        drawText("Open Voice",
                 in: CGRect(x: margin, y: bounds.height - 40,
                            width: 180, height: 15),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("Page \(page) of \(count)",
                 in: CGRect(x: bounds.width - margin - 100, y: bounds.height - 40,
                            width: 100, height: 15),
                 font: .systemFont(ofSize: 9), color: .darkGray, alignment: .right)
    }

    private static func fittingCharacterCount(_ text: String, width: CGFloat,
                                              maximumHeight: CGFloat) -> Int {
        let characters = Array(text)
        guard !characters.isEmpty else { return 0 }
        var low = 1
        var high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            if measuredHeight(String(characters.prefix(middle)), width: width) <= maximumHeight {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low
    }

    private static func measuredHeight(_ text: String, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 4
        return (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: bodyFont, .paragraphStyle: paragraph], context: nil
        ).height
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont,
                                 color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 4
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}
