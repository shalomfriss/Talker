import UIKit

enum PrintableBoardPDF {
    enum PaperSize {
        case letter
        case a4

        var bounds: CGRect {
            switch self {
            case .letter: CGRect(x: 0, y: 0, width: 612, height: 792)
            case .a4: CGRect(x: 0, y: 0, width: 595, height: 842)
            }
        }

        static var local: Self {
            ["US", "CA", "MX"].contains(Locale.current.region?.identifier ?? "") ? .letter : .a4
        }
    }

    private static let columns = 3
    private static let rows = 5
    private static let itemsPerPage = columns * rows

    private struct Page {
        let board: String
        let items: [CommunicationItem]
        let part: Int
        let partCount: Int
        let isChoiceBoard: Bool
    }

    static func makeData(profileName: String, categories: [String], items: [CommunicationItem],
                         choiceBoards: [ChoiceBoard] = [],
                         language: String = "en",
                         wordTranslations: [String: [String: WordTranslation]] = [:],
                         paperSize: PaperSize = .local) -> Data {
        var boards: [String] = []
        for board in categories + items.map(\.category) where !boards.contains(board) {
            boards.append(board)
        }
        if boards.isEmpty { boards = ["Core"] }
        let vocabularyPages = boards.flatMap { board -> [Page] in
            let boardItems = items.filter { $0.category == board }
            let count = max(1, (boardItems.count + itemsPerPage - 1) / itemsPerPage)
            return (0..<count).map { part in
                let start = part * itemsPerPage
                let end = min(start + itemsPerPage, boardItems.count)
                return Page(board: board, items: Array(boardItems[start..<end]),
                            part: part + 1, partCount: count, isChoiceBoard: false)
            }
        }
        let choicePages = choiceBoards.map { board in
            let options = board.options.map { $0.resolved(using: items).communicationItem }
            let alternativeOptions: [ChoiceOption] = language == "es"
                ? [ChoiceOption(label: "Otra cosa", symbol: "❓"),
                   ChoiceOption(label: "No, gracias", symbol: "✋")]
                : [ChoiceOption(label: "Something else", symbol: "❓"),
                   ChoiceOption(label: "No thanks", symbol: "✋")]
            let alternatives = alternativeOptions.map(\.communicationItem)
            return Page(board: board.title, items: options + alternatives,
                        part: 1, partCount: 1, isChoiceBoard: true)
        }
        let pages = vocabularyPages + choicePages
        let firstPages = Dictionary(boards.map { board in
            (board, 1 + pages.firstIndex(where: { $0.board == board })!)
        }, uniquingKeysWith: { first, _ in first })
        let bounds = paperSize.bounds
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        var symbolImages: [String: UIImage] = [:]

        return renderer.pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()
                drawHeader(page: page, profileName: profileName, pageNumber: index + 1,
                           totalPages: pages.count, language: language, bounds: bounds)
                drawGrid(page: page, firstPages: firstPages, bounds: bounds,
                         language: language, wordTranslations: wordTranslations,
                         symbolImages: &symbolImages)
                drawFooter(page: page, pageNumber: index + 1, totalPages: pages.count,
                           language: language, bounds: bounds)
            }
        }
    }

    private static func drawHeader(page: Page, profileName: String, pageNumber: Int,
                                   totalPages: Int, language: String, bounds: CGRect) {
        let margin: CGFloat = 36
        let title = language == "es"
            ? (page.isChoiceBoard ? "OPEN VOICE  /  TABLERO DE OPCIONES" : "OPEN VOICE  /  TABLEROS PARA IMPRIMIR")
            : (page.isChoiceBoard ? "OPEN VOICE  /  CHOICE BOARD" : "OPEN VOICE  /  PRINTABLE BOARDS")
        drawText(title,
                 in: CGRect(x: margin, y: 28,
                 width: bounds.width - margin * 2, height: 15), font: .boldSystemFont(ofSize: 10),
                 color: .darkGray)
        drawFittedText(page.board, in: CGRect(x: margin, y: 47,
                       width: bounds.width - margin * 2, height: 44),
                       maxFontSize: 27, minFontSize: 16, alignment: .left)
        let detail = page.partCount == 1 ? profileName :
            (language == "es" ? "\(profileName)  |  Página \(page.part) de \(page.partCount)" :
                "\(profileName)  |  Board page \(page.part) of \(page.partCount)")
        drawText(detail, in: CGRect(x: margin, y: 95, width: bounds.width - margin * 2,
                 height: 18), font: .systemFont(ofSize: 11), color: .darkGray)
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: 118, width: bounds.width - margin * 2,
                                  height: 1)).fill()
    }

    private static func drawGrid(page: Page, firstPages: [String: Int], bounds: CGRect,
                                 language: String,
                                 wordTranslations: [String: [String: WordTranslation]],
                                 symbolImages: inout [String: UIImage]) {
        let margin: CGFloat = 36
        let gap: CGFloat = 8
        let top: CGFloat = 134
        let bottom: CGFloat = 68
        let width = (bounds.width - 2 * margin - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let height = (bounds.height - top - bottom - gap * CGFloat(rows - 1)) / CGFloat(rows)

        for position in 0..<itemsPerPage {
            let column = position % columns
            let row = position / columns
            let rect = CGRect(x: margin + CGFloat(column) * (width + gap),
                              y: top + CGFloat(row) * (height + gap), width: width, height: height)
            let tile = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            UIColor.white.setFill()
            tile.fill()
            UIColor(white: 0.5, alpha: 1).setStroke()
            tile.lineWidth = 1
            tile.stroke()
            guard position < page.items.count else { continue }
            let item = page.items[position]
            let imageRect = CGRect(x: rect.midX - 27, y: rect.minY + 10, width: 54, height: 54)
            if let data = item.imageData, let image = UIImage(data: data) {
                drawImage(image, in: imageRect)
            } else if !item.symbol.isEmpty {
                if symbolImages[item.symbol] == nil { symbolImages[item.symbol] = symbolImage(item.symbol) }
                symbolImages[item.symbol]?.draw(in: imageRect)
            }

            let hasLink = item.destinationBoard != nil
            let labelY = rect.minY + 68
            let labelHeight: CGFloat = hasLink ? 29 : 42
            let label = wordTranslations[item.id.uuidString]?[language]?.label ?? item.label
            drawFittedText(label, in: CGRect(x: rect.minX + 7, y: labelY,
                           width: rect.width - 14, height: labelHeight),
                           maxFontSize: 15, minFontSize: 8)
            if let destination = item.destinationBoard {
                let pageReference = firstPages[destination].map { language == "es" ? " - pág. \($0)" : " - p. \($0)" } ?? ""
                let navigationText = language == "es" ? "A \(destination)\(pageReference)" : "To \(destination)\(pageReference)"
                drawText(navigationText, in: CGRect(x: rect.minX + 8,
                         y: rect.maxY - 19, width: rect.width - 16, height: 12),
                         font: .systemFont(ofSize: 8), color: .darkGray, alignment: .center)
            }
        }
    }

    private static func drawFooter(page: Page, pageNumber: Int, totalPages: Int,
                                   language: String, bounds: CGRect) {
        let margin: CGFloat = 36
        if page.items.contains(where: { $0.arasaacPictogramID != nil }) {
            drawText(ARASAACPictogramService.attribution,
                     in: CGRect(x: margin, y: bounds.height - 53,
                                width: bounds.width - margin * 2, height: 12),
                     font: .systemFont(ofSize: 6.5), color: .darkGray)
        }
        let instruction: String
        if language == "es" {
            instruction = page.isChoiceBoard ? "Señala una opción, otra cosa o no, gracias." :
                (page.items.isEmpty ? "Escribe o pega palabras en los espacios vacíos." :
                 "Señala una palabra o imagen para comunicarte.")
        } else {
            instruction = page.isChoiceBoard ? "Point to a choice, or say something else or no thanks." :
                (page.items.isEmpty ? "Write or attach words in the empty spaces." :
                 "Point to a word or picture to communicate.")
        }
        drawText(instruction, in: CGRect(x: margin, y: bounds.height - 37,
                 width: bounds.width - margin * 2 - 48, height: 17),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("\(pageNumber) / \(totalPages)", in: CGRect(x: bounds.width - 80,
                 y: bounds.height - 37, width: 44, height: 17), font: .systemFont(ofSize: 9),
                 color: .darkGray, alignment: .right)
    }

    private static func symbolImage(_ symbol: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        return renderer.image { _ in
            drawText(symbol, in: CGRect(x: 0, y: 0, width: 64, height: 64),
                     font: .systemFont(ofSize: 43), color: .black, alignment: .center)
        }
    }

    private static func drawImage(_ image: UIImage, in rect: CGRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                              width: size.width, height: size.height))
    }

    private static func drawFittedText(_ text: String, in rect: CGRect, maxFontSize: CGFloat,
                                       minFontSize: CGFloat = 10,
                                       alignment: NSTextAlignment = .center) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        for fontSize in stride(from: maxFontSize, through: minFontSize, by: -1) {
            let font = UIFont.boldSystemFont(ofSize: fontSize)
            let size = (clean as NSString).boundingRect(with: rect.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
            if size.height <= rect.height + 1 || fontSize == minFontSize {
                (clean as NSString).draw(in: rect, withAttributes: [
                    .font: font, .foregroundColor: UIColor.black, .paragraphStyle: paragraph
                ])
                break
            }
        }
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor,
                                 alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}
