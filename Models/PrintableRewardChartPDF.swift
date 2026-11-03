import UIKit

enum PrintableRewardChartPDF {
    private static let margin: CGFloat = 40
    private static let ink = UIColor(red: 0.12, green: 0.16, blue: 0.23, alpha: 1)
    private static let accent = UIColor(red: 0.89, green: 0.43, blue: 0.15, alpha: 1)
    private static let pale = UIColor(red: 1, green: 0.96, blue: 0.90, alpha: 1)

    static func makeData(chart: RewardChart, profileName: String, language: String = "en",
                         paperSize: PrintableBoardPDF.PaperSize = .local) -> Data {
        let bounds = paperSize.bounds
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            drawHeader(chart: chart, profileName: profileName, language: language, bounds: bounds)
            drawReward(chart: chart, language: language, bounds: bounds)
            drawProgress(chart: chart, language: language, bounds: bounds)
            drawTokens(chart: chart, bounds: bounds)
            drawFooter(language: language, bounds: bounds)
        }
    }

    private static func drawHeader(chart: RewardChart, profileName: String,
                                   language: String, bounds: CGRect) {
        drawText(language == "es" ? "OPEN VOICE  /  TABLA DE RECOMPENSAS" :
                 "OPEN VOICE  /  REWARD CHART",
                 in: CGRect(x: margin, y: 29, width: bounds.width - margin * 2, height: 16),
                 font: .boldSystemFont(ofSize: 10), color: accent)
        drawFittedText(chart.title,
                       in: CGRect(x: margin, y: 52, width: bounds.width - margin * 2, height: 48),
                       maxFontSize: 31, minFontSize: 17)
        drawText(profileName,
                 in: CGRect(x: margin, y: 108, width: bounds.width - margin * 2, height: 19),
                 font: .systemFont(ofSize: 12), color: .darkGray)
        rule(at: 137, bounds: bounds)
    }

    private static func drawReward(chart: RewardChart, language: String, bounds: CGRect) {
        let panel = CGRect(x: margin, y: 155, width: bounds.width - margin * 2, height: 140)
        pale.setFill()
        UIBezierPath(roundedRect: panel, cornerRadius: 14).fill()
        let picture = CGRect(x: panel.minX + 17, y: panel.minY + 17, width: 106, height: 106)
        UIColor.white.setFill()
        UIBezierPath(roundedRect: picture, cornerRadius: 12).fill()
        if let data = chart.photoData, let image = UIImage(data: data),
           image.size.width > 0, image.size.height > 0 {
            let scale = min((picture.width - 12) / image.size.width,
                            (picture.height - 12) / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: picture.midX - size.width / 2,
                                  y: picture.midY - size.height / 2,
                                  width: size.width, height: size.height))
        } else {
            drawText(chart.symbol,
                     in: CGRect(x: picture.minX + 6, y: picture.minY + 18,
                                width: picture.width - 12, height: 70),
                     font: .systemFont(ofSize: 55), color: ink, alignment: .center)
        }
        let textX = picture.maxX + 19
        let textWidth = panel.maxX - textX - 16
        drawText(language == "es" ? "MI RECOMPENSA" : "MY REWARD",
                 in: CGRect(x: textX, y: panel.minY + 24, width: textWidth, height: 18),
                 font: .boldSystemFont(ofSize: 11), color: accent)
        drawFittedText(chart.reward,
                       in: CGRect(x: textX, y: panel.minY + 50, width: textWidth, height: 70),
                       maxFontSize: 23, minFontSize: 12)
    }

    private static func drawProgress(chart: RewardChart, language: String, bounds: CGRect) {
        let heading = language == "es" ? "MI PROGRESO" : "MY PROGRESS"
        drawText(heading,
                 in: CGRect(x: margin, y: 318, width: bounds.width - margin * 2, height: 18),
                 font: .boldSystemFont(ofSize: 11), color: accent)
        let count = language == "es"
            ? "\(chart.earnedTokens) de \(chart.targetTokens) estrellas ganadas"
            : "\(chart.earnedTokens) of \(chart.targetTokens) stars earned"
        drawText(count,
                 in: CGRect(x: margin, y: 337, width: bounds.width - margin * 2, height: 24),
                 font: .systemFont(ofSize: 16, weight: .semibold), color: ink)
    }

    private static func drawTokens(chart: RewardChart, bounds: CGRect) {
        let columns = 5
        let rows = (chart.targetTokens + columns - 1) / columns
        let gap: CGFloat = 9
        let width = (bounds.width - margin * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let availableHeight = bounds.height - 375 - 91
        let height = min(100, (availableHeight - gap * CGFloat(rows - 1)) / CGFloat(rows))
        let usedHeight = height * CGFloat(rows) + gap * CGFloat(rows - 1)
        let top = 375 + max(0, (availableHeight - usedHeight) / 2)
        for index in 0..<chart.targetTokens {
            let row = index / columns
            let column = index % columns
            let rect = CGRect(x: margin + CGFloat(column) * (width + gap),
                              y: top + CGFloat(row) * (height + gap),
                              width: width, height: height)
            drawToken(index: index, earned: index < chart.earnedTokens, in: rect)
        }
    }

    private static func drawToken(index: Int, earned: Bool, in rect: CGRect) {
        let panel = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        (earned ? pale : UIColor.white).setFill()
        panel.fill()
        UIColor(red: 0.74, green: 0.75, blue: 0.77, alpha: 1).setStroke()
        panel.lineWidth = 1
        panel.stroke()

        let diameter = min(49, rect.height - 26)
        let circle = CGRect(x: rect.midX - diameter / 2, y: rect.minY + 8,
                            width: diameter, height: diameter)
        let outline = UIBezierPath(ovalIn: circle)
        if earned {
            accent.setFill()
            outline.fill()
            UIColor.white.setFill()
            star(in: circle.insetBy(dx: diameter * 0.23, dy: diameter * 0.23)).fill()
        } else {
            accent.setStroke()
            outline.lineWidth = 2
            outline.stroke()
        }
        drawText(String(index + 1),
                 in: CGRect(x: rect.minX + 4, y: rect.maxY - 17,
                            width: rect.width - 8, height: 13),
                 font: .systemFont(ofSize: 9, weight: .medium), color: ink, alignment: .center)
    }

    private static func star(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        for point in 0..<10 {
            let angle = CGFloat(point) * .pi / 5 - .pi / 2
            let radius = (point.isMultiple(of: 2) ? rect.width : rect.width * 0.44) / 2
            let position = CGPoint(x: rect.midX + cos(angle) * radius,
                                   y: rect.midY + sin(angle) * radius)
            if point == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        path.close()
        return path
    }

    private static func drawFooter(language: String, bounds: CGRect) {
        rule(at: bounds.height - 77, bounds: bounds)
        let instruction = language == "es"
            ? "Marca un espacio vacío cada vez que ganes una estrella."
            : "Mark one empty space each time you earn a star."
        drawText(instruction,
                 in: CGRect(x: margin, y: bounds.height - 65,
                            width: bounds.width - margin * 2, height: 20),
                 font: .systemFont(ofSize: 11), color: ink)
        drawText(language == "es" ? "Progreso al imprimir" : "Progress at print time",
                 in: CGRect(x: margin, y: bounds.height - 42,
                            width: bounds.width - margin * 2, height: 16),
                 font: .systemFont(ofSize: 9), color: .darkGray)
    }

    private static func rule(at y: CGFloat, bounds: CGRect) {
        UIColor(red: 0.76, green: 0.77, blue: 0.78, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y,
                                  width: bounds.width - margin * 2, height: 1)).fill()
    }

    private static func drawFittedText(_ text: String, in rect: CGRect,
                                       maxFontSize: CGFloat, minFontSize: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        for size in stride(from: maxFontSize, through: minFontSize, by: -1) {
            let font = UIFont.boldSystemFont(ofSize: size)
            let measured = (text as NSString).boundingRect(with: rect.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
            if measured.height <= rect.height || size == minFontSize {
                (text as NSString).draw(in: rect, withAttributes: [
                    .font: font, .foregroundColor: ink, .paragraphStyle: paragraph
                ])
                return
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
