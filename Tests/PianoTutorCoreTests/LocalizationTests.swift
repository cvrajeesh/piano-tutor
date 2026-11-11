import Foundation
import XCTest
@testable import PianoTutorCore

/// Checks the translations in Sources/PianoTutor/Resources/<language>.lproj. Every language
/// has its own files; English is the source and holds every key. See docs/localization.md.
final class LocalizationTests: XCTestCase {
    /// The languages the app ships in, as named by their .lproj folders.
    static let languages: [String] = ["en", "es", "fr", "de", "it", "pt-BR", "ja", "zh-Hans", "ko"]
    static let tables: [String] = ["Localizable", "Course", "InfoPlist"]

    static let resources: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/PianoTutor/Resources")

    static func table(_ name: String, _ language: String) throws -> [String: String] {
        let url: URL = resources.appendingPathComponent("\(language).lproj/\(name).strings")
        let data: Data = try Data(contentsOf: url)
        let plist: Any = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let strings = plist as? [String: String] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        return strings
    }

    static func pluralTable(_ language: String) throws -> [String: Any] {
        let url: URL = resources.appendingPathComponent("\(language).lproj/Localizable.stringsdict")
        let data: Data = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
    }

    /// The format specifiers in a string, ignoring their positions: "%1$@ %2$lld" and
    /// "%lld %@" have the same ones.
    static func placeholders(_ text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|ld|d|@|f|%)")
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range)
            .map { (text as NSString).substring(with: $0.range(at: 1)) }
            .filter { $0 != "%" }
            .sorted()
    }

    /// Every piece of English text in the course and the song library that the app shows.
    static var courseText: Set<String> {
        var text: Set<String> = []
        for unit in Curriculum.units {
            text.insert(unit.title)
            text.insert(unit.summary)
            for lesson in unit.lessons {
                text.insert(lesson.title)
                text.insert(lesson.summary)
                for step in lesson.steps {
                    switch step {
                    case .info(let card):
                        text.insert(card.title)
                        text.formUnion(card.paragraphs)
                        for mark in card.marks {
                            if case .text(let words) = mark.label {
                                text.insert(words)
                            }
                        }
                    case .find(let task):
                        text.insert(task.title)
                        text.insert(task.detail)
                    case .practice(let spec), .play(let spec):
                        text.insert(spec.title)
                        text.insert(spec.instruction)
                    }
                }
            }
        }
        for song in SongLibrary.songs {
            text.insert(song.title)
            text.insert(song.credit)
        }
        return text
    }

    func testEnglishCourseTableMatchesTheContent() throws {
        let english: [String: String] = try Self.table("Course", "en")
        let content: Set<String> = Self.courseText
        let missing: [String] = content.subtracting(english.keys).sorted()
        let unused: [String] = Set(english.keys).subtracting(content).sorted()
        XCTAssertEqual(missing, [], "Add these to en.lproj/Course.strings and translate them")
        XCTAssertEqual(unused, [], "No longer in the course; remove them from every Course.strings")
    }

    func testEveryLanguageHasEveryString() throws {
        for table in Self.tables {
            let english: [String: String] = try Self.table(table, "en")
            XCTAssertFalse(english.isEmpty, table)
            for language in Self.languages where language != "en" {
                let translated: [String: String] = try Self.table(table, language)
                let missing: [String] = Set(english.keys).subtracting(translated.keys).sorted()
                let extra: [String] = Set(translated.keys).subtracting(english.keys).sorted()
                XCTAssertEqual(missing, [], "\(language).lproj/\(table).strings is missing translations")
                XCTAssertEqual(extra, [], "\(language).lproj/\(table).strings has keys English doesn't")
                for (key, value) in translated {
                    XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(language) \(table): empty translation of \(key)")
                }
            }
        }
    }

    func testTranslationsKeepTheirPlaceholders() throws {
        for table in Self.tables {
            let english: [String: String] = try Self.table(table, "en")
            for language in Self.languages {
                let translated: [String: String] = try Self.table(table, language)
                for (key, value) in translated {
                    XCTAssertEqual(
                        Self.placeholders(value), Self.placeholders(english[key] ?? key),
                        "\(language) \(table): placeholders differ in \(key)"
                    )
                    // Strings with more than one placeholder must number them, so that a
                    // translation can put them in a different order.
                    if Self.placeholders(value).count > 1 {
                        XCTAssertFalse(value.contains("%@") || value.contains("%lld"), "\(language) \(table): number the placeholders in \(key)")
                    }
                }
            }
        }
    }

    func testEveryLanguageHasThePluralRules() throws {
        let english: [String: Any] = try Self.pluralTable("en")
        XCTAssertFalse(english.isEmpty)
        for language in Self.languages {
            let plurals: [String: Any] = try Self.pluralTable(language)
            XCTAssertEqual(Set(plurals.keys), Set(english.keys), language)
            for (key, value) in plurals {
                let entry = value as? [String: Any]
                let format = entry?["NSStringLocalizedFormatKey"] as? String
                XCTAssertNotNil(format, "\(language): \(key)")
                for (name, rule) in entry ?? [:] where name != "NSStringLocalizedFormatKey" {
                    // Every language needs at least the "other" form; the rest depend on its grammar.
                    XCTAssertNotNil((rule as? [String: Any])?["other"], "\(language): \(key) \(name)")
                }
            }
        }
    }

    func testNoteNamesFollowTheLanguage() {
        let fSharp = Pitch(letter: 3, alter: 1, octave: 4)
        let bFlat = Pitch(letter: 6, alter: -1, octave: 3)
        let b = Pitch(letter: 6, alter: 0, octave: 4)
        let eFlat = Pitch(letter: 2, alter: -1, octave: 4)

        XCTAssertEqual(NoteNaming(language: "en").name(fSharp), "F♯")
        XCTAssertEqual(NoteNaming(language: "zh-Hans").fullName(.middleC), "C4")
        XCTAssertEqual(NoteNaming(language: "de").name(fSharp), "Fis")
        XCTAssertEqual(NoteNaming(language: "de").name(b), "H")
        XCTAssertEqual(NoteNaming(language: "de").name(bFlat), "B")
        XCTAssertEqual(NoteNaming(language: "de").name(eFlat), "Es")
        XCTAssertEqual(NoteNaming(language: "de").headLabel(bFlat), "B")
        XCTAssertEqual(NoteNaming(language: "de").headLabel(eFlat), "E")
        XCTAssertEqual(NoteNaming(language: "fr").name(fSharp), "Fa♯")
        XCTAssertEqual(NoteNaming(language: "fr").fullName(.middleC), "Do4")
        XCTAssertEqual(NoteNaming(language: "es").name(Pitch(letter: 1, octave: 4)), "Re")
        XCTAssertEqual(NoteNaming(language: "pt-BR").name(bFlat), "Si♭")
        XCTAssertEqual(NoteNaming(language: "pt-BR").fullName(.middleC), "Dó4")
        XCTAssertEqual(NoteNaming(language: "ja").name(Pitch(letter: 3, octave: 4)), "ファ")
        XCTAssertEqual(NoteNaming(language: "ko").fullName(.middleC), "도4")
        XCTAssertEqual(NoteNaming(language: "nl"), .english)
    }
}
