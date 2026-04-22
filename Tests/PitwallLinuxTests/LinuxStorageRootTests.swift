import Foundation
import XCTest
@testable import PitwallLinux

final class LinuxStorageRootTests: XCTestCase {
    func test_xdgConfig_honorsXdgConfigHomeOverride() {
        let root = LinuxStorageRoot.xdgConfig(
            xdgConfigHome: "/tmp/xdg-config",
            home: "/home/test",
            applicationFolderName: "pitwall"
        )

        XCTAssertEqual(root.rootDirectory.path, "/tmp/xdg-config/pitwall")
    }

    func test_xdgConfig_fallsBackToHomeDotConfig() {
        let root = LinuxStorageRoot.xdgConfig(
            xdgConfigHome: nil,
            home: "/home/test",
            applicationFolderName: "pitwall"
        )

        XCTAssertEqual(root.rootDirectory.path, "/home/test/.config/pitwall")
    }

    func test_xdgData_fallsBackToHomeLocalShare() {
        let root = LinuxStorageRoot.xdgData(
            xdgDataHome: "",
            home: "/home/test",
            applicationFolderName: "pitwall"
        )

        XCTAssertEqual(root.rootDirectory.path, "/home/test/.local/share/pitwall")
    }

    func test_fileURL_joinsUnderRootDirectory() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = LinuxStorageRoot(rootDirectory: tmp)

        let url = root.fileURL(for: "foo.json")

        XCTAssertEqual(url.lastPathComponent, "foo.json")
        XCTAssertEqual(url.deletingLastPathComponent(), tmp)
    }

    func test_ensureDirectoryExists_createsMissingDirectory() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pitwall-tests-\(UUID().uuidString)", isDirectory: true)
        let root = LinuxStorageRoot(rootDirectory: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try root.ensureDirectoryExists()

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }
}
