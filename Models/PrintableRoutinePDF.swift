import UIKit

enum PrintableRoutinePDF {
    private struct Row {
        let number: Int
        let text: String
        let imageData: Data?
        let isVideo: Bool
        let hasChoiceBoard: Bool
        let symbol: String
        let durationSeconds: Int?
        let isComplete: Bool
        let isContinuation: Bool
        let height: CGFloat
    }

    private static let margin: CGFloat = 38
    private static let gap: CGFloat = 9
    private static let textFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
    private static let ink = UIColor(red: 0.10, green: 0.20, blue: 0.23, alpha: 1)

    static func makeData(profileName: String, steps: [RoutineStep], language: String = "en",
                         paperSize: PrintableBoardPDF.PaperSize = .local) -> Data {
        let bounds = paperSize.bounds
        let rows = makeRows(steps: steps, language: language, bounds: bounds)
        let pages = paginate(rows, bounds: bounds)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for (index, pageRows) in pages.enumerated() {
                context.beginPage()
                drawHeader(profileName: profileName, language: language, bounds: bounds)
                if index == 0 { drawOverview(steps: steps, language: language, bounds: bounds) }
                drawSectionTitle(language == "es" ? "PASOS" : "STEPS",
                                 at: index == 0 ? 317 : 147, bounds: bounds)
                var y: CGFloat = index == 0 ? 345 : 175
                for row in pageRows {
                    drawRow(row, at: y, language: language, bounds: bounds)
                    y += row.height + gap
                }
                drawFooter(page: index + 1, count: pages.count, language: language, bounds: bounds)
            }
        }
    }

    private static func makeRows(steps: [RoutineStep], language: String, bounds: CGRect) -> [Row] {
        let width = textWidth(bounds: bounds)
        return steps.enumerated().flatMap { index, step -> [Row] in
            let message = step.spokenMessage
            var remaining = step.title + (message == step.title ? "" :
                "\n\(language == "es" ? "Decir" : "Say"): \(message)")
            var continuation = false
            var result: [Row] = []
            repeat {
                let characters = Array(remaining)
                var end = min(characters.count,
                              max(1, fittingCharacterCount(remaining, width: width, height: 156)))
                if end < characters.count,
                   let wordBreak = characters[..<end].lastIndex(where: { $0.isWhitespace }),
                   wordBreak > end / 2 {
                    end = wordBreak + 1
                }
                let piece = String(characters[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                let height = max(102, measuredHeight(piece, width: width) + 50)
                result.append(Row(number: index + 1, text: piece,
                                  imageData: continuation ? nil : step.displayImageData,
                                  isVideo: !continuation && step.videoData != nil,
                                  hasChoiceBoard: !continuation && step.choiceBoardID != nil,
                                  symbol: continuation ? "" : step.symbol,
                                  durationSeconds: continuation ? nil : step.durationSeconds,
                                  isComplete: step.isComplete,
                                  isContinuation: continuation, height: height))
                remaining = String(characters.dropFirst(end))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation = true
            } while !remaining.isEmpty
            return result
        }
    }

    private static func paginate(_ rows: [Row], bounds: CGRect) -> [[Row]] {
        var pages: [[Row]] = [[]]
        var y: CGFloat = 345
        for row in rows {
            if y + row.height > bounds.height - 66 {
                pages.append([])
                y = 175
            }
            pages[pages.count - 1].append(row)
            y += row.height + gap
        }
        return pages
    }

    private static func drawHeader(profileName: String, language: String, bounds: CGRect) {
        drawText(language == "es" ? "OPEN VOICE  /  RUTINA VISUAL" : "OPEN VOICE  /  VISUAL ROUTINE",
                 in: CGRect(x: margin, y: 27, width: bounds.width - margin * 2, height: 16),
                 font: .boldSystemFont(ofSize: 10), color: ink)
        drawText(language == "es" ? "Mi rutina" : "My routine",
                 in: CGRect(x: margin, y: 48, width: bounds.width - margin * 2, height: 42),
                 font: .boldSystemFont(ofSize: 29), color: ink)
        drawText(profileName, in: CGRect(x: margin, y: 99,
                 width: bounds.width - margin * 2, height: 19),
                 font: .systemFont(ofSize: 12), color: .darkGray)
        rule(at: 125, bounds: bounds)
    }

    private static func drawOverview(steps: [RoutineStep], language: String, bounds: CGRect) {
        drawSectionTitle(language == "es" ? "PRIMERO / DESPUÉS" : "FIRST / THEN",
                         at: 143, bounds: bounds)
        let active = steps.filter { !$0.isComplete }
        if active.isEmpty {
            let message = steps.isEmpty
                ? (language == "es" ? "Añade pasos en Open Voice para crear una rutina." :
                    "Add steps in Open Voice to make a routine.")
                : (language == "es" ? "¡Todos los pasos terminados!" : "All steps done!")
            drawText(message, in: CGRect(x: margin, y: 192,
                     width: bounds.width - margin * 2, height: 55),
                     font: .boldSystemFont(ofSize: 20), color: ink, alignment: .center)
            return
        }
        let cardGap: CGFloat = 14
        let width = (bounds.width - margin * 2 - cardGap) / 2
        for column in 0..<2 {
            let rect = CGRect(x: margin + CGFloat(column) * (width + cardGap),
                              y: 166, width: width, height: 135)
            let panel = UIBezierPath(roundedRect: rect, cornerRadius: 11)
            UIColor(red: 0.94, green: 0.97, blue: 0.98, alpha: 1).setFill()
            panel.fill()
            UIColor(red: 0.70, green: 0.78, blue: 0.79, alpha: 1).setStroke()
            panel.lineWidth = 1
            panel.stroke()
            drawText(column == 0 ? (language == "es" ? "PRIMERO" : "FIRST") :
                        (language == "es" ? "DESPUÉS" : "THEN"),
                     in: CGRect(x: rect.minX + 10, y: rect.minY + 8,
                                width: rect.width - 20, height: 15),
                     font: .boldSystemFont(ofSize: 10), color: ink, alignment: .center)
            guard column < active.count else { continue }
            let step = active[column]
            drawPicture(data: step.displayImageData, symbol: step.symbol,
                        in: CGRect(x: rect.midX - 30, y: rect.minY + 26, width: 60, height: 60))
            drawFittedText(step.title, in: CGRect(x: rect.minX + 10, y: rect.minY + 91,
                             width: rect.width - 20, height: 37))
        }
    }

    private static func drawSectionTitle(_ title: String, at y: CGFloat, bounds: CGRect) {
        drawText(title, in: CGRect(x: margin, y: y,
                 width: bounds.width - margin * 2, height: 18),
                 font: .boldSystemFont(ofSize: 11), color: ink)
    }

    private static func drawRow(_ row: Row, at y: CGFloat, language: String, bounds: CGRect) {
        let rect = CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: row.height)
        let panel = UIBezierPath(roundedRect: rect, cornerRadius: 9)
        UIColor.white.setFill()
        panel.fill()
        UIColor(red: 0.72, green: 0.78, blue: 0.79, alpha: 1).setStroke()
        panel.lineWidth = 1
        panel.stroke()
        drawText(row.isContinuation ? "CONT." : "\(row.number)",
                 in: CGRect(x: rect.minX + 10, y: rect.minY + 8, width: 45, height: 18),
                 font: .boldSystemFont(ofSize: row.isContinuation ? 10 : 14), color: ink)
        if !row.isContinuation {
            drawPicture(data: row.imageData, symbol: row.symbol,
                        in: CGRect(x: rect.minX + 25, y: rect.minY + 26, width: 54, height: 54))
        }
        drawText(row.text, in: CGRect(x: rect.minX + 94, y: rect.minY + 12,
                 width: textWidth(bounds: bounds), height: rect.height - 42),
                 font: textFont, color: ink)
        if !row.isContinuation {
            let duration = row.durationSeconds.map { "\($0 / 60) min" }
            let status = row.isComplete ? (language == "es" ? "Hecho" : "Done") :
                (language == "es" ? "Por hacer" : "To do")
            let videoNote = row.isVideo ? (language == "es" ? "Vídeo en la app" : "Video in app") : nil
            let choiceNote = row.hasChoiceBoard ? (language == "es" ? "Opciones en la app" : "Choices in app") : nil
            drawText([status, duration, videoNote, choiceNote].compactMap { $0 }.joined(separator: "  |  "),
                     in: CGRect(x: rect.minX + 94, y: rect.maxY - 25,
                                width: textWidth(bounds: bounds), height: 15),
                     font: .systemFont(ofSize: 10), color: .darkGray)
            drawCheckbox(checked: row.isComplete,
                         in: CGRect(x: rect.maxX - 34, y: rect.midY - 11, width: 22, height: 22))
        }
    }

    private static func drawCheckbox(checked: Bool, in rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
        ink.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        guard checked else { return }
        let check = UIBezierPath()
        check.move(to: CGPoint(x: rect.minX + 4, y: rect.midY))
        check.addLine(to: CGPoint(x: rect.minX + 9, y: rect.maxY - 5))
        check.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + 5))
        check.lineWidth = 2.2
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()
    }

    private static func drawFooter(page: Int, count: Int, language: String, bounds: CGRect) {
        rule(at: bounds.height - 55, bounds: bounds)
        drawText(language == "es" ? "Creado con Open Voice - audio y vídeo en la app" :
                    "Made with Open Voice - audio and video play in the app",
                 in: CGRect(x: margin, y: bounds.height - 44,
                            width: bounds.width - margin * 2 - 60, height: 16),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("\(page) / \(count)",
                 in: CGRect(x: bounds.width - margin - 55, y: bounds.height - 44,
                            width: 55, height: 16),
                 font: .systemFont(ofSize: 9), color: .darkGray, alignment: .right)
    }

    private static func rule(at y: CGFloat, bounds: CGRect) {
        ink.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y,
                                  width: bounds.width - margin * 2, height: 1)).fill()
    }

    private static func drawPicture(data: Data?, symbol: String, in rect: CGRect) {
        if let data, let image = UIImage(data: data),
           image.size.width > 0, image.size.height > 0 {
            let scale = min(rect.width / image.size.width, rect.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                  width: size.width, height: size.height))
        } else {
            drawText(symbol, in: rect, font: .systemFont(ofSize: 40),
                     color: .black, alignment: .center)
        }
    }

    private static func drawFittedText(_ text: String, in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        for size in stride(from: CGFloat(16), through: 9, by: -1) {
            let font = UIFont.boldSystemFont(ofSize: size)
            let measured = (text as NSString).boundingRect(
                with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
            if measured.height <= rect.height + 1 || size == 9 {
                (text as NSString).draw(in: rect, withAttributes: [
                    .font: font, .foregroundColor: ink, .paragraphStyle: paragraph
                ])
                break
            }
        }
    }

    private static func textWidth(bounds: CGRect) -> CGFloat {
        bounds.width - margin * 2 - 94 - 44
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
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
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
        paragraph.lineSpacing = 2
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}
