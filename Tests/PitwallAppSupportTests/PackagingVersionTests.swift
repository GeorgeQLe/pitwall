import XCTest
@testable import PitwallAppSupport

final class PackagingVersionTests: XCTestCase {
    func testStaticProviderReturnsConfiguredValue() {
        let value = PackagingVersion(shortString: "1.2.3", build: 42)
        let provider = StaticPackagingVersionProvider(value)

        XCTAssertEqual(provider.current(), value)
        XCTAssertEqual(provider.current().shortString, "1.2.3")
        XCTAssertEqual(provider.current().build, 42)
    }

    func testStaticProviderConvenienceInitializerMatchesValueInitializer() {
        let fromValue = StaticPackagingVersionProvider(
            PackagingVersion(shortString: "2.0.0", build: 7)
        )
        let fromFields = StaticPackagingVersionProvider(shortString: "2.0.0", build: 7)

        XCTAssertEqual(fromValue.current(), fromFields.current())
    }

    func testBundleProviderFallsBackWhenInfoDictionaryMissingKeys() {
        let emptyBundle = Bundle(for: PackagingVersionTests.self)
        let provider = BundlePackagingVersionProvider(bundle: emptyBundle)

        let current = provider.current()

        XCTAssertEqual(current.shortString, BundlePackagingVersionProvider.unbundledShortString)
        XCTAssertEqual(current.build, BundlePackagingVersionProvider.unbundledBuild)
    }

    func testBundleProviderUsesCustomFallbackWhenBundleIsUnprimed() {
        let emptyBundle = Bundle(for: PackagingVersionTests.self)
        let primed = PackagingVersion(shortString: versionFileContent(), build: 1)
        let provider = BundlePackagingVersionProvider(bundle: emptyBundle, fallback: primed)

        let current = provider.current()

        XCTAssertEqual(current, primed)
        XCTAssertTrue(
            current.shortString.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil,
            "shortString '\(current.shortString)' should match semver major.minor.patch"
        )
        XCTAssertGreaterThan(current.build, 0)
    }

    func testPackagingVersionEquality() {
        XCTAssertEqual(
            PackagingVersion(shortString: "1.0.0", build: 5),
            PackagingVersion(shortString: "1.0.0", build: 5)
        )
        XCTAssertNotEqual(
            PackagingVersion(shortString: "1.0.0", build: 5),
            PackagingVersion(shortString: "1.0.0", build: 6)
        )
    }

    private func versionFileContent() -> String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let versionURL = repoRoot.appendingPathComponent("VERSION")
        guard let data = try? Data(contentsOf: versionURL),
              let raw = String(data: data, encoding: .utf8) else {
            XCTFail("VERSION file not readable at \(versionURL.path)")
            return "0.0.0"
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
