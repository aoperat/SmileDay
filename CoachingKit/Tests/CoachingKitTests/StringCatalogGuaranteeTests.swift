import XCTest
@testable import CoachingKit

/// 앱 타깃의 String Catalog(JSON)를 상대 경로로 읽어 문구 보증을 검사한다.
///
/// 앱 타깃에는 문구 테스트가 없고 CoachingKit에서는 문구가 사라졌다. 금지어·누락·id 대응 같은
/// 보증이 그 사이에서 증발하지 않게 여기서 파일을 직접 읽는다 — 번들 리소스가 아니라 파일이므로
/// SwiftPM이 카탈로그를 컴파일하지 못하는 제약(스펙 4.3절)을 타지 않는다.
final class StringCatalogGuaranteeTests: XCTestCase {
    struct Catalog {
        let name: String
        /// key → (lang → value)
        let strings: [String: [String: String]]
    }

    private static let catalogNames = ["Localizable", "Home", "Onboarding", "Settings", "Coaching"]

    private static var resourcesDirectory: URL {
        // CoachingKit/Tests/CoachingKitTests/이파일.swift → 저장소 루트/SmileDay/Resources
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CoachingKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // CoachingKit
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("SmileDay/Resources")
    }

    private static func loadCatalog(_ name: String) throws -> Catalog {
        let url = resourcesDirectory.appendingPathComponent("\(name).xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any], "\(name): not a JSON object")
        let strings = try XCTUnwrap(root["strings"] as? [String: Any], "\(name): no 'strings'")
        var out: [String: [String: String]] = [:]
        for (key, entry) in strings {
            let locs = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            var perLang: [String: String] = [:]
            for (lang, loc) in locs {
                if let unit = (loc as? [String: Any])?["stringUnit"] as? [String: Any],
                   let value = unit["value"] as? String {
                    perLang[lang] = value
                } else if let variations = (loc as? [String: Any])?["variations"] as? [String: Any],
                          let plural = variations["plural"] as? [String: Any] {
                    // 복수형은 카테고리별 값을 이어 붙여 검사한다 (금지어·누락 검사용)
                    let joined = plural.values.compactMap {
                        (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
                    }.joined(separator: " | ")
                    perLang[lang] = joined
                }
            }
            out[key] = perLang
        }
        return Catalog(name: name, strings: out)
    }

    private static func loadAll() throws -> [Catalog] {
        try catalogNames.map(loadCatalog)
    }

    func test_allCatalogsExistAndParse() throws {
        let catalogs = try Self.loadAll()
        XCTAssertEqual(catalogs.count, Self.catalogNames.count)
    }

    // MARK: - 보증

    /// 한국어 금지어. 기존 SmileCueTests·ReminderMessageTests의 목록을 합쳤다.
    private static let bannedKorean = ["사랑받", "예뻐", "인상 개선", "교정", "치료", "더 크게", "잘 웃", "리프팅", "젊어진"]
    /// 영어 금지어. 스펙 2절 — 영어권 심사(1.4.1)에서 직접 걸리는 말.
    private static let bannedEnglish = [
        "lift", "tone", "firm", "anti-aging", "rejuvenat", "wrinkle", "therap",
        "treatment", "cure", "heal", "depression", "anxiety", "mood disorder", "clinical",
    ]

    func test_koreanValues_avoidBannedWording() throws {
        for catalog in try Self.loadAll() {
            for (key, langs) in catalog.strings {
                guard let ko = langs["ko"] else { continue }
                for word in Self.bannedKorean {
                    XCTAssertFalse(ko.contains(word), "\(catalog.name).\(key) ko contains banned '\(word)'")
                }
            }
        }
    }

    func test_englishValues_avoidBannedWording() throws {
        for catalog in try Self.loadAll() {
            for (key, langs) in catalog.strings {
                guard let en = langs["en"]?.lowercased() else { continue }
                for word in Self.bannedEnglish {
                    // 단어 경계를 대충 본다 — "lift"가 "uplifting"에 걸리면 그것도 잡는 게 맞다.
                    XCTAssertFalse(en.contains(word), "\(catalog.name).\(key) en contains banned '\(word)'")
                }
            }
        }
    }

    func test_everyKey_hasNonEmptyKoreanAndEnglish() throws {
        for catalog in try Self.loadAll() {
            for (key, langs) in catalog.strings {
                let ko = langs["ko"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let en = langs["en"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                XCTAssertFalse(ko.isEmpty, "\(catalog.name).\(key): ko is empty")
                XCTAssertFalse(en.isEmpty, "\(catalog.name).\(key): en is empty")
            }
        }
    }

    /// 제품 불변식 — 큐 중 하나는 "떠올릴 게 없어도 괜찮다"고 말해야 한다.
    /// SmileCueTests.test_catalog_allowsHavingNothingPositiveToRecall 을 여기로 옮겼다.
    func test_cues_allowHavingNothingPositiveToRecall() throws {
        let coaching = try Self.loadCatalog("Coaching")
        let koValues = coaching.strings.values.compactMap { $0["ko"] }
        XCTAssertTrue(
            koValues.contains { $0.contains("떠오르는 장면이 없어도 괜찮아요") },
            "Coaching catalog lost the 'nothing needed' cue"
        )
    }

    /// id는 CoachingKit, 문구는 앱 카탈로그로 갈라졌다. 큐를 추가하며 한쪽만 손대면 가이드
    /// 화면에 키 문자열이 뜬다 — 카탈로그에 **키가 있는지**는 여기서, **실제로 해석되는지**는
    /// 앱 타깃의 `SmileCueTextTests`가 본다. 이 테스트는 JSON만 읽으므로 후자를 대신하지 못한다.
    func test_everySmileCue_hasACatalogEntry() throws {
        let coaching = try Self.loadCatalog("Coaching")
        for cue in SmileCueCatalog.all {
            let key = "smileCue.\(cue.id)"
            XCTAssertNotNil(coaching.strings[key], "Coaching catalog missing '\(key)'")
        }
    }
}
