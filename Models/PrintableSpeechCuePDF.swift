import UIKit

enum PrintableSpeechCuePDF {
    private static let margin: CGFloat = 36
    private static let topicsPerPage = 12

    static func makeData(profileName: String, letters: [String], language: String,
                         topics: [SpeechTopic],
                         paperSize: PrintableBoardPDF.PaperSize = .local) -> Data {
        let bounds = paperSize.bounds
        let topicPageCount = max(1, (topics.count + topicsPerPage - 1) / topicsPerPage)
        let pageCount = 1 + topicPageCount
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            drawHeader(title: language == "es" ? "Letras y números" : "Letters and numbers",
                       subtitle: language == "es"
                           ? "Señala la primera letra o deletrea una palabra."
                           : "Point to a first letter or spell a word.",
                       profileName: profileName, language: language, bounds: bounds)
            drawLetterBoard(AppSettings.cleanedLetters(letters, language: language), language: language, bounds: bounds)
            drawFooter(pageNumber: 1, pageCount: pageCount, language: language, bounds: bounds)

            for part in 0..<topicPageCount {
                context.beginPage()
                drawHeader(title: language == "es" ? "Temas de conversación" : "Conversation topics",
                           subtitle: language == "es"
                               ? "Señala un tema para ayudar a tu compañero a comprenderte."
                               : "Point to a topic to help your partner understand you.",
                           profileName: profileName, language: language, bounds: bounds)
                let start = part * topicsPerPage
                let end = min(start + topicsPerPage, topics.count)
                drawTopicBoard(Array(topics[start..<end]), bounds: bounds)
                drawFooter(pageNumber: part + 2, pageCount: pageCount,
                           language: language, bounds: bounds)
            }
        }
    }

    private static func drawHeader(title: String, subtitle: String, profileName: String,
                                   language: String, bounds: CGRect) {
        drawText(language == "es" ? "OPEN VOICE  /  PISTAS PARA HABLAR" : "OPEN VOICE  /  SPEECH CUES",
                 in: CGRect(x: margin, y: 26, width: bounds.width - margin * 2, height: 16),
                 font: .boldSystemFont(ofSize: 10), color: .darkGray)
        drawText(title, in: CGRect(x: margin, y: 47, width: bounds.width - margin * 2, height: 37),
                 font: .boldSystemFont(ofSize: 27), color: .black)
        drawText("\(profileName)  ·  \(subtitle)",
                 in: CGRect(x: margin, y: 94, width: bounds.width - margin * 2, height: 19),
                 font: .systemFont(ofSize: 11), color: .darkGray)
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: 121, width: bounds.width - margin * 2, height: 1)).fill()
    }

    private static func drawLetterBoard(_ letters: [String], language: String, bounds: CGRect) {
        let gap: CGFloat = 8
        let width = (bounds.width - margin * 2 - gap * 5) / 6
        for (index, letter) in letters.enumerated() {
            let rect = CGRect(x: margin + CGFloat(index % 6) * (width + gap),
                              y: 139 + CGFloat(index / 6) * 76, width: width, height: 68)
            drawCell(rect)
            drawText(letter, in: rect.insetBy(dx: 3, dy: 3),
                     font: .boldSystemFont(ofSize: 37), color: .black, alignment: .center)
        }

        drawText(language == "es" ? "NÚMEROS" : "NUMBERS",
                 in: CGRect(x: margin, y: 520, width: bounds.width - margin * 2, height: 18),
                 font: .boldSystemFont(ofSize: 11), color: .darkGray)
        let numberGap: CGFloat = 5
        let numberWidth = (bounds.width - margin * 2 - numberGap * 9) / 10
        for number in 0..<10 {
            let rect = CGRect(x: margin + CGFloat(number) * (numberWidth + numberGap),
                              y: 545, width: numberWidth, height: 54)
            drawCell(rect)
            drawText(String(number), in: rect.insetBy(dx: 2, dy: 2),
                     font: .boldSystemFont(ofSize: 26), color: .black, alignment: .center)
        }

        let responses = language == "es"
            ? ["SÍ", "NO", "OTRA COSA", "TERMINÉ"]
            : ["YES", "NO", "SOMETHING ELSE", "FINISHED"]
        let responseWidth = (bounds.width - margin * 2 - gap * 3) / 4
        for (index, response) in responses.enumerated() {
            let rect = CGRect(x: margin + CGFloat(index) * (responseWidth + gap),
                              y: 621, width: responseWidth, height: 67)
            drawCell(rect)
            drawFittedText(response, in: rect.insetBy(dx: 6, dy: 5),
                           maxSize: 20, minSize: 11)
        }
    }

    private static func drawTopicBoard(_ topics: [SpeechTopic], bounds: CGRect) {
        let gap: CGFloat = 10
        let width = (bounds.width - margin * 2 - gap * 2) / 3
        for index in 0..<topicsPerPage {
            let rect = CGRect(x: margin + CGFloat(index % 3) * (width + gap),
                              y: 145 + CGFloat(index / 3) * 134, width: width, height: 124)
            drawCell(rect)
            if index < topics.count {
                drawFittedText(topics[index].text, in: rect.insetBy(dx: 10, dy: 10),
                               maxSize: 24, minSize: 10)
            } else {
                UIColor(white: 0.75, alpha: 1).setStroke()
                let line = UIBezierPath()
                line.move(to: CGPoint(x: rect.minX + 16, y: rect.midY + 18))
                line.addLine(to: CGPoint(x: rect.maxX - 16, y: rect.midY + 18))
                line.lineWidth = 0.8
                line.stroke()
            }
        }
    }

    private static func drawCell(_ rect: CGRect) {
        let cell = UIBezierPath(roundedRect: rect, cornerRadius: 7)
        UIColor.white.setFill()
        cell.fill()
        UIColor(white: 0.42, alpha: 1).setStroke()
        cell.lineWidth = 1
        cell.stroke()
    }

    private static func drawFooter(pageNumber: Int, pageCount: Int, language: String,
                                   bounds: CGRect) {
        let note = language == "es"
            ? "Señala una opción o pide a tu compañero que lea las opciones."
            : "Point to a choice, or ask your partner to read the choices."
        drawText(note,
                 in: CGRect(x: margin, y: bounds.height - 38,
                            width: bounds.width - margin * 2 - 52, height: 17),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("\(pageNumber) / \(pageCount)",
                 in: CGRect(x: bounds.width - margin - 48, y: bounds.height - 38,
                            width: 48, height: 17),
                 font: .systemFont(ofSize: 9), color: .darkGray, alignment: .right)
    }

    private static func drawFittedText(_ text: String, in rect: CGRect,
                                       maxSize: CGFloat, minSize: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for size in stride(from: maxSize, through: minSize, by: -1) {
            let font = UIFont.boldSystemFont(ofSize: size)
            let widestWord = clean.split(whereSeparator: \.isWhitespace)
                .map { (String($0) as NSString).size(withAttributes: [.font: font]).width }
                .max() ?? 0
            if widestWord > rect.width && size > minSize { continue }
            let required = (clean as NSString).boundingRect(with: rect.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
            if required.height <= rect.height + 1 || size == minSize {
                let textRect = CGRect(x: rect.minX,
                                      y: rect.minY + max(0, (rect.height - required.height) / 2),
                                      width: rect.width, height: min(rect.height, required.height + 2))
                (clean as NSString).draw(in: textRect, withAttributes: [
                    .font: font, .foregroundColor: UIColor.black, .paragraphStyle: paragraph
                ])
                break
            }
        }
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont,
                                 color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}
