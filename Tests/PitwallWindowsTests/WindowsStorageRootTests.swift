import Foundation
import XCTest
@testable import PitwallWindows

final class WindowsStorageRootTests: XCTestCase {
    func test_roaming_appendsApplicationFolderToAppDataPath() {
        let root = WindowsStorageRoot.roaming(
            appDataPath: "C:/Users/test/AppData/Roaming",
            applicationFolderName: "Pitwall"
        )

        XCTAssertTrue(root.rootDirectory.path.hasSuffix("Pitwall"))
    }

    func test_fileURL_joinsUnderRootDirectory() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = WindowsStorageRoot(rootDirectory: tmp)

        let url = root.fileURL(for: "foo.json")

        XCTAssertEqual(url.lastPathComponent, "foo.json")
        XCTAssertEqual(url.deletingLastPathComponent(), tmp)
    }

    func test_ensureDirectoryExists_createsMissingDirectory() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-tests-\(UUID().uuidString)", isDirectory: true)
        let root = WindowsStorageRoot(rootDirectory: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try root.ensureDirectoryExists()

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }
}
