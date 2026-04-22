import Foundation

public struct PackagingVersion: Equatable, Sendable {
    public let shortString: String
    public let build: Int

    public init(shortString: String, build: Int) {
        self.shortString = shortString
        self.build = build
    }
}

public protocol PackagingVersionProvider {
    func current() -> PackagingVersion
}

public struct StaticPackagingVersionProvider: PackagingVersionProvider {
    private let value: PackagingVersion

    public init(_ value: PackagingVersion) {
        self.value = value
    }

    public init(shortString: String, build: Int) {
        self.init(PackagingVersion(shortString: shortString, build: build))
    }

    public func current() -> PackagingVersion {
        value
    }
}

public struct BundlePackagingVersionProvider: PackagingVersionProvider {
    public static let unbundledShortString = "0.0.0-dev"
    public static let unbundledBuild = 0

    private let bundle: Bundle
    private let fallback: PackagingVersion

    public init(
        bundle: Bundle = .main,
        fallback: PackagingVersion = PackagingVersion(
            shortString: BundlePackagingVersionProvider.unbundledShortString,
            build: BundlePackagingVersionProvider.unbundledBuild
        )
    ) {
        self.bundle = bundle
        self.fallback = fallback
    }

    public func current() -> PackagingVersion {
        let shortString = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? fallback.shortString

        let build: Int
        if let raw = bundle.object(forInfoDictionaryKey: "CFBundleVersion") {
            if let intValue = raw as? Int {
                build = intValue
            } else if let stringValue = raw as? String, let parsed = Int(stringValue) {
                build = parsed
            } else {
                build = fallback.build
            }
        } else {
            build = fallback.build
        }

        return PackagingVersion(shortString: shortString, build: build)
    }
}
