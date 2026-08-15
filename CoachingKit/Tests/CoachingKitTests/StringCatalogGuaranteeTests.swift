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
}
