import Foundation

/// "1.2.3" (or "v1.2.3"), compared number by number.
public struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init?(_ text: String) {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") { trimmed.removeFirst() }
        // Ignore anything after a pre-release or build marker.
        let core = trimmed.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (1...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        major = parts[0]!
        minor = parts.count > 1 ? parts[1]! : 0
        patch = parts.count > 2 ? parts[2]! : 0
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}

/// The parts of GitHub's "latest release" answer the updater needs.
public struct ReleaseInfo: Equatable, Sendable {
    public var version: SemanticVersion
    public var diskImage: URL
    /// A text file holding the disk image's SHA-256, published next to it.
    public var checksum: URL?
    public var page: URL

    public static func == (lhs: ReleaseInfo, rhs: ReleaseInfo) -> Bool {
        lhs.version == rhs.version && lhs.diskImage == rhs.diskImage && lhs.checksum == rhs.checksum && lhs.page == rhs.page
    }

    public static let diskImageName = "DynamicNotch.dmg"

    /// Reads https://api.github.com/repos/<owner>/<repo>/releases/latest. Nil if it isn't usable.
    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let version = SemanticVersion(tag),
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)),
              let assets = json["assets"] as? [[String: Any]] else { return nil }
        func asset(_ name: String) -> URL? {
            assets.first { $0["name"] as? String == name }
                .flatMap { $0["browser_download_url"] as? String }
                .flatMap(URL.init(string:))
        }
        guard let image = asset(diskImageName) else { return nil }
        return ReleaseInfo(version: version, diskImage: image, checksum: asset(diskImageName + ".sha256"), page: page)
    }
}
