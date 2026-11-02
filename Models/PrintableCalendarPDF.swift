import UIKit

enum CalendarPDFRange: String, CaseIterable, Identifiable {
    case month, week, day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "This month"
        case .week: "This week"
        case .day: "This day"
        }
    }
}

enum PrintableCalendarPDF {
    private struct Entry {
        let option: ChoiceOption
        let complete: Bool
        let colorHex: String?
    }

    private struct Card {
        let entry: Entry
        let text: String
        let continuation: Bool
    }

    private enum DetailElement {
        case heading(Date)
        case card(Card)
    }

    private struct Page {
        let overview: Bool
        let elements: [DetailElement]
    }

    private static let margin: CGFloat = 35
    private static let cardHeight: CGFloat = 125
    private static let cardGap: CGFloat = 8
    private static let ink = UIColor(red: 0.12, green: 0.18, blue: 0.23, alpha: 1)
    private static let subtle = UIColor(red: 0.92, green: 0.94, blue: 0.98, alpha: 1)

    static func makeData(profileName: String, date: Date, range: CalendarPDFRange,
                         visualCalendar: VisualCalendar, weeklyPlan: WeeklyPlan,
                         items: [CommunicationItem], language: String = "en",
                         paperSize: PrintableBoardPDF.PaperSize = .local,
                         calendar: Calendar = .current) -> Data {
        let dates = dates(for: date, range: range, calendar: calendar)
        let bounds = paperSize.bounds
        let entriesByDay = dates.map { day in
            entries(on: day, visualCalendar: visualCalendar, weeklyPlan: weeklyPlan,
                    items: items, calendar: calendar)
        }
        let pages = makePages(dates: dates, entriesByDay: entriesByDay,
                              range: range, bounds: bounds, language: language)
        let period = periodTitle(dates: dates, range: range, calendar: calendar, language: language)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for (index, page) in pages.enumerated() {
                context.beginPage()
                drawHeader(profileName: profileName, period: period, range: range,
                           language: language, bounds: bounds)
                if page.overview {
                    drawOverview(dates: dates, entriesByDay: entriesByDay,
                                 range: range, bounds: bounds, calendar: calendar, language: language)
                } else {
                    drawDetails(page.elements, bounds: bounds, calendar: calendar, language: language)
                }
                drawFooter(page: index + 1, count: pages.count, bounds: bounds, language: language)
            }
        }
    }

    private static func dates(for date: Date, range: CalendarPDFRange,
                              calendar: Calendar) -> [Date] {
        let day = calendar.startOfDay(for: date)
        guard range != .day else { return [day] }
        let component: Calendar.Component = range == .month ? .month : .weekOfYear
        guard let interval = calendar.dateInterval(of: component, for: day) else { return [day] }
        var result: [Date] = []
        var current = interval.start
        while current < interval.end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current), next > current else { break }
            current = next
        }
        return result
    }

    private static func entries(on date: Date, visualCalendar: VisualCalendar,
                                weeklyPlan: WeeklyPlan, items: [CommunicationItem],
                                calendar: Calendar) -> [Entry] {
        let events = visualCalendar.events(on: date, calendar: calendar).map { event in
            Entry(option: event.option.resolved(using: items),
                  complete: event.isComplete(on: date, calendar: calendar),
                  colorHex: event.colorHex)
        }
        let weekday = calendar.component(.weekday, from: date)
        let weekly = weeklyPlan.activities(on: weekday).map { activity in
            Entry(option: activity.option.resolved(using: items),
                  complete: activity.isComplete(on: date, calendar: calendar), colorHex: nil)
        }
        return events + weekly
    }

    private static func makePages(dates: [Date], entriesByDay: [[Entry]],
                                  range: CalendarPDFRange, bounds: CGRect,
                                  language: String) -> [Page] {
        var pages: [Page] = range == .day ? [] : [Page(overview: true, elements: [])]
        var current: [DetailElement] = []
        var y: CGFloat = 142
        func finishPage() {
            guard !current.isEmpty else { return }
            pages.append(Page(overview: false, elements: current))
            current = []
            y = 142
        }
        for (day, entries) in zip(dates, entriesByDay) where !entries.isEmpty {
            if y + 34 + cardHeight > bounds.height - 61 { finishPage() }
            current.append(.heading(day))
            y += 34
            for entry in entries {
                for card in cards(for: entry, bounds: bounds, language: language) {
                    if y + cardHeight > bounds.height - 61 {
                        finishPage()
                        current.append(.heading(day))
                        y += 34
                    }
                    current.append(.card(card))
                    y += cardHeight + cardGap
                }
            }
            y += 8
        }
        finishPage()
        if pages.isEmpty { pages = [Page(overview: false, elements: [])] }
        return pages
    }

    private static func cards(for entry: Entry, bounds: CGRect, language: String) -> [Card] {
        let message = entry.option.message.trimmingCharacters(in: .whitespacesAndNewlines)
        var remaining = entry.option.label + (message == entry.option.label || message.isEmpty ? "" :
            "\n\(language == "es" ? "Decir" : "Say"): \(message)")
        var result: [Card] = []
        let width = bounds.width - 2 * margin - 107
        repeat {
            let characters = Array(remaining)
            var end = min(characters.count, max(1, fittingCount(remaining, width: width)))
            if end < characters.count,
               let space = characters[..<end].lastIndex(where: { $0.isWhitespace }), space > end / 2 {
                end = space + 1
            }
            let text = String(characters[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(Card(entry: entry, text: text, continuation: !result.isEmpty))
            remaining = String(characters.dropFirst(end)).trimmingCharacters(in: .whitespacesAndNewlines)
        } while !remaining.isEmpty
        return result
    }

    private static func fittingCount(_ text: String, width: CGFloat) -> Int {
        let characters = Array(text)
        var low = 1
        var high = characters.count
        while low < high {
            let mid = (low + high + 1) / 2
            let size = (String(characters.prefix(mid)) as NSString).boundingRect(
                with: CGSize(width: width, height: 10_000),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: UIFont.systemFont(ofSize: 14)], context: nil)
            if size.height <= 75 { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private static func periodTitle(dates: [Date], range: CalendarPDFRange,
                                    calendar: Calendar, language: String) -> String {
        guard let first = dates.first, let last = dates.last else { return "" }
        switch range {
        case .month: return dateString(first, format: "MMMM yyyy", calendar: calendar, language: language)
        case .week:
            return "\(dateString(first, format: "MMM d", calendar: calendar, language: language)) - " +
                dateString(last, format: "MMM d, yyyy", calendar: calendar, language: language)
        case .day:
            return dateString(first, format: "EEEE, MMMM d, yyyy", calendar: calendar, language: language)
        }
    }

    private static func dateString(_ date: Date, format: String, calendar: Calendar,
                                   language: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: language == "es" ? "es" : "en")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private static func drawHeader(profileName: String, period: String, range: CalendarPDFRange,
                                   language: String, bounds: CGRect) {
        drawText(language == "es" ? "OPEN VOICE  /  CALENDARIO VISUAL" : "OPEN VOICE  /  VISUAL CALENDAR",
                 in: CGRect(x: margin, y: 27, width: bounds.width - 2 * margin, height: 16),
                 font: .boldSystemFont(ofSize: 10), color: ink)
        drawText(period, in: CGRect(x: margin, y: 48, width: bounds.width - 2 * margin, height: 39),
                 font: .boldSystemFont(ofSize: 26), color: ink)
        let kind: String
        switch range {
        case .month: kind = language == "es" ? "Mes" : "Month"
        case .week: kind = language == "es" ? "Semana" : "Week"
        case .day: kind = language == "es" ? "Día" : "Day"
        }
        drawText("\(profileName)  |  \(kind)",
                 in: CGRect(x: margin, y: 100, width: bounds.width - 2 * margin, height: 18),
                 font: .systemFont(ofSize: 11), color: .darkGray)
        ink.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: 126, width: bounds.width - 2 * margin, height: 1)).fill()
    }

    private static func drawOverview(dates: [Date], entriesByDay: [[Entry]],
                                     range: CalendarPDFRange, bounds: CGRect,
                                     calendar: Calendar, language: String) {
        let columns = 7
        let gap: CGFloat = 4
        let cellWidth = (bounds.width - 2 * margin - CGFloat(columns - 1) * gap) / 7
        let startWeekday = calendar.component(.weekday, from: dates[0])
        let leading = range == .month ? (startWeekday - calendar.firstWeekday + 7) % 7 : 0
        let rowCount = max(1, (leading + dates.count + 6) / 7)
        let cellHeight = min(94, (bounds.height - 270 - CGFloat(rowCount - 1) * gap) / CGFloat(rowCount))
        for column in 0..<columns {
            let weekday = (calendar.firstWeekday - 1 + column) % 7
            drawText(calendar.shortStandaloneWeekdaySymbols[weekday],
                     in: CGRect(x: margin + CGFloat(column) * (cellWidth + gap), y: 143,
                                width: cellWidth, height: 22),
                     font: .boldSystemFont(ofSize: 10), color: ink, alignment: .center)
        }
        for (index, day) in dates.enumerated() {
            let position = leading + index
            let column = position % 7
            let row = position / 7
            let rect = CGRect(x: margin + CGFloat(column) * (cellWidth + gap),
                              y: 170 + CGFloat(row) * (cellHeight + gap),
                              width: cellWidth, height: cellHeight)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 5)
            let eventTint = entriesByDay[index].compactMap { color($0.colorHex) }.first
            (eventTint?.withAlphaComponent(0.18) ?? (entriesByDay[index].isEmpty ? UIColor.white : subtle)).setFill()
            path.fill()
            UIColor.lightGray.setStroke()
            path.lineWidth = 0.6
            path.stroke()
            drawText("\(calendar.component(.day, from: day))",
                     in: CGRect(x: rect.minX + 5, y: rect.minY + 5, width: 25, height: 17),
                     font: .boldSystemFont(ofSize: 12), color: ink)
            let entries = entriesByDay[index]
            if let first = entries.first {
                drawPicture(first.option, in: CGRect(x: rect.midX - 17, y: rect.minY + 22,
                                                     width: 34, height: 34))
                drawText("\(entries.count) \(language == "es" ? "planes" : "planned")",
                         in: CGRect(x: rect.minX + 3, y: rect.maxY - 23,
                                    width: rect.width - 6, height: 18),
                         font: .systemFont(ofSize: 9), color: ink, alignment: .center)
            }
        }
        let hasEntries = entriesByDay.contains { !$0.isEmpty }
        let note: String
        if hasEntries {
            note = language == "es" ? "Los detalles de cada día siguen en las páginas siguientes." :
                "Daily event details follow on the next pages."
        } else {
            note = language == "es" ? "No hay planes para este período." :
                "Nothing planned for this period."
        }
        drawText(note, in: CGRect(x: margin, y: bounds.height - 77,
                                  width: bounds.width - 2 * margin, height: 18),
                 font: .systemFont(ofSize: 10), color: .darkGray)
    }

    private static func drawDetails(_ elements: [DetailElement], bounds: CGRect,
                                    calendar: Calendar, language: String) {
        guard !elements.isEmpty else {
            drawText(language == "es" ? "No hay planes para este día." : "Nothing planned for this day.",
                     in: CGRect(x: margin, y: 165, width: bounds.width - 2 * margin, height: 50),
                     font: .systemFont(ofSize: 18), color: ink)
            return
        }
        var y: CGFloat = 142
        for element in elements {
            switch element {
            case .heading(let date):
                drawText(dateString(date, format: "EEEE, MMMM d", calendar: calendar, language: language),
                         in: CGRect(x: margin, y: y, width: bounds.width - 2 * margin, height: 26),
                         font: .boldSystemFont(ofSize: 17), color: ink)
                y += 34
            case .card(let card):
                drawCard(card, at: y, bounds: bounds, language: language)
                y += cardHeight + cardGap
            }
        }
    }

    private static func drawCard(_ card: Card, at y: CGFloat, bounds: CGRect, language: String) {
        let rect = CGRect(x: margin, y: y, width: bounds.width - 2 * margin, height: cardHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor.white.setFill()
        path.fill()
        UIColor(red: 0.72, green: 0.76, blue: 0.81, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()
        if let accent = color(card.entry.colorHex) {
            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: rect.minX + 3, y: rect.minY + 3,
                                             width: 5, height: rect.height - 6), cornerRadius: 2).fill()
        }
        if card.continuation {
            drawText(language == "es" ? "CONT." : "CONT.",
                     in: CGRect(x: rect.minX + 17, y: y + 31, width: 55, height: 19),
                     font: .boldSystemFont(ofSize: 10), color: ink)
        } else {
            drawPicture(card.entry.option,
                        in: CGRect(x: rect.minX + 14, y: y + 22, width: 62, height: 62))
        }
        drawText(card.text, in: CGRect(x: rect.minX + 91, y: y + 12,
                                      width: rect.width - 107, height: 82),
                 font: .systemFont(ofSize: 14), color: ink)
        drawText(card.entry.complete ? (language == "es" ? "Hecho" : "Done") :
                    (language == "es" ? "Por hacer" : "To do"),
                 in: CGRect(x: rect.minX + 91, y: y + 102,
                            width: rect.width - 107, height: 14),
                 font: .systemFont(ofSize: 10), color: .darkGray)
    }

    private static func drawPicture(_ option: ChoiceOption, in rect: CGRect) {
        if let data = option.imageData, let image = UIImage(data: data),
           image.size.width > 0, image.size.height > 0 {
            let scale = min(rect.width / image.size.width, rect.height / image.size.height)
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(in: CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2,
                                  width: width, height: height))
        } else {
            drawText(option.symbol, in: rect, font: .systemFont(ofSize: min(36, rect.height * 0.75)),
                     color: ink, alignment: .center)
        }
    }

    private static func color(_ hex: String?) -> UIColor? {
        guard let hex, let value = ButtonColorValue(text: hex) else { return nil }
        return UIColor(red: CGFloat(value.red) / 255, green: CGFloat(value.green) / 255,
                       blue: CGFloat(value.blue) / 255, alpha: CGFloat(value.alpha) / 255)
    }

    private static func drawFooter(page: Int, count: Int, bounds: CGRect, language: String) {
        ink.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: bounds.height - 51,
                                  width: bounds.width - 2 * margin, height: 1)).fill()
        drawText(language == "es" ? "Hecho con Open Voice - las grabaciones se reproducen en la app" :
                    "Made with Open Voice - recordings play in the app",
                 in: CGRect(x: margin, y: bounds.height - 39,
                            width: bounds.width - 2 * margin - 55, height: 14),
                 font: .systemFont(ofSize: 9), color: .darkGray)
        drawText("\(page) / \(count)",
                 in: CGRect(x: bounds.width - margin - 55, y: bounds.height - 39,
                            width: 55, height: 14),
                 font: .systemFont(ofSize: 9), color: .darkGray, alignment: .right)
    }

    private static func drawText(_ text: String, in rect: CGRect, font: UIFont,
                                 color: UIColor, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ])
    }
}
