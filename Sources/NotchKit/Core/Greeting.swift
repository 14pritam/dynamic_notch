import Foundation

/// The first-launch hello: "Hi Swagat", from the name on the Mac's user account.
public enum Greeting {
    /// The first word of the account's full name, or nil when there isn't one.
    public static func firstName(fromFullName fullName: String) -> String? {
        fullName.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    }

    public static func text(fullName: String) -> String {
        guard let name = firstName(fromFullName: fullName) else { return String(localized: "Hi there") }
        return String(localized: "Hi \(name)")
    }
}
