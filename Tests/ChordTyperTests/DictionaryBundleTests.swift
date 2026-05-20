import XCTest

final class DictionaryBundleTests: XCTestCase {

    // MARK: - Bundle Resource Tests

    func testOpenDictionaryFolder_bundleContainsDictionaries_filesAreValidJSON() throws {
        // The dictionaries folder is a folder reference copied into the host app
        // bundle (ChordTyper.app/Contents/Resources/dictionaries/). When running
        // unit tests, Bundle.main points to the host app.
        guard let resourceURL = Bundle.main.resourceURL else {
            XCTFail("Bundle.main.resourceURL is nil")
            return
        }
        let dictionariesURL = resourceURL.appendingPathComponent("dictionaries")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: dictionariesURL.path),
            "dictionaries folder must exist in bundle at \(dictionariesURL.path)"
        )

        // Verify english.json is valid JSON with at least one entry
        let englishURL = dictionariesURL.appendingPathComponent("english.json")
        let englishData = try Data(contentsOf: englishURL)
        let englishDict = try JSONDecoder().decode([String: String].self, from: englishData)
        XCTAssertFalse(englishDict.isEmpty, "english.json must contain at least one chord entry")
        XCTAssertEqual(englishDict["eht"], "the", "english.json must map 'eht' to 'the'")

        // Verify thai.json is valid JSON
        let thaiURL = dictionariesURL.appendingPathComponent("thai.json")
        let thaiData = try Data(contentsOf: thaiURL)
        let thaiDict = try JSONDecoder().decode([String: String].self, from: thaiData)
        XCTAssertNotNil(thaiDict, "thai.json must be a valid JSON object")
    }
}
