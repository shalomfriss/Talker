import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class PrintableCalendarPDFTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 1
        return value
    }

    private var selectedDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 31))!
    }

    func testMonthWeekAndDayPrintEventsWeeklyActivitiesAndCompletion() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }
        var event = CalendarEvent(option: ChoiceOption(label: "Family visit", symbol: "🏠",
                                                      message: "Tell me about the visit",
                                                      imageData: photo.pngData()),
                                  startDate: selectedDate, colorHex: "#3CA95B")
        event.completedOn = [selectedDate]
        var events = VisualCalendar()
        XCTAssertTrue(events.add(event))
        var weekly = WeeklyPlan()
        XCTAssertTrue(weekly.add(WeeklyActivity(option: ChoiceOption(label: "Library time", symbol: "📚")),
                                 on: 7))
        for range in CalendarPDFRange.allCases {
            for (paper, expectedSize) in [
                (PrintableBoardPDF.PaperSize.letter, CGSize(width: 612, height: 792)),
                (.a4, CGSize(width: 595, height: 842))
            ] {
                let data = PrintableCalendarPDF.makeData(
                    profileName: "Avery", date: selectedDate, range: range,
                    visualCalendar: events, weeklyPlan: weekly, items: [],
                    paperSize: paper, calendar: calendar)
                let document = try XCTUnwrap(PDFDocument(data: data))
                XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, expectedSize)
                XCTAssertGreaterThanOrEqual(document.pageCount, range == .day ? 1 : 2)
                let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
                    .joined(separator: " ")
                for expected in ["Avery", "Family visit", "Tell me about the visit",
                                 "Library time", "Done"] {
                    XCTAssertTrue(text.contains(expected), "Missing \(expected) in \(range)")
                }
                if range == .month {
                    XCTAssertTrue(text.contains("October 2026"))
                    XCTAssertTrue(text.contains("Saturday, October 31"))
                    XCTAssertFalse(text.contains("September 2026"))
                }
                XCTAssertGreaterThan(data.count, 3_000)
                if range == .month && paper == .letter {
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
                    attachment.name = "Open Voice Calendar Sample"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    func testLongCalendarContentPaginatesWithoutLosingWords() throws {
        let message = Array(repeating: "slowly", count: 140).joined(separator: " ")
        let event = CalendarEvent(option: ChoiceOption(label: "Long preparation", message: message),
                                  startDate: selectedDate)
        var events = VisualCalendar()
        XCTAssertTrue(events.add(event))
        for index in 0..<18 {
            let extra = CalendarEvent(option: ChoiceOption(label: "EVENT\(index)"),
                                      startDate: selectedDate)
            XCTAssertTrue(events.add(extra))
        }
        let data = PrintableCalendarPDF.makeData(
            profileName: "Alex", date: selectedDate, range: .day,
            visualCalendar: events, weeklyPlan: WeeklyPlan(), items: [],
            language: "es", paperSize: .letter, calendar: calendar)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 2)
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            .joined(separator: " ")
        XCTAssertEqual(text.components(separatedBy: "slowly").count - 1, 140)
        for index in 0..<18 { XCTAssertTrue(text.contains("EVENT\(index)")) }
        XCTAssertTrue(text.contains("Decir"))
        for page in 0..<document.pageCount {
            let pageText = try XCTUnwrap(document.page(at: page)?.string)
            XCTAssertGreaterThanOrEqual(pageText.components(separatedBy: "sábado, octubre 31").count - 1, 2)
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Open Voice Long Calendar"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEmptyDayStillHasPrintablePage() throws {
        let data = PrintableCalendarPDF.makeData(
            profileName: "Avery", date: selectedDate, range: .day,
            visualCalendar: VisualCalendar(), weeklyPlan: WeeklyPlan(),
            items: [], paperSize: .letter, calendar: calendar)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(try XCTUnwrap(document.page(at: 0)?.string).contains("Nothing planned"))
    }

    func testSixRowMonthFitsOnOneOverviewPage() throws {
        let may = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 15)))
        let data = PrintableCalendarPDF.makeData(
            profileName: "Avery", date: may, range: .month,
            visualCalendar: VisualCalendar(), weeklyPlan: WeeklyPlan(),
            items: [], paperSize: .letter, calendar: calendar)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        let text = try XCTUnwrap(document.page(at: 0)?.string)
        XCTAssertTrue(text.contains("May 2026"))
        XCTAssertTrue(text.contains("31"))
        XCTAssertTrue(text.contains("Nothing planned for this period"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Open Voice Six Row Month"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
