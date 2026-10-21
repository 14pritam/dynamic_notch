import Foundation

/// Which microphone users count as calls, and which to ignore.
public enum CallClassifier {
    public static let callApps: Set<String> = [
        "com.apple.FaceTime",
        "com.apple.mobilephone",
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.cisco.webexmeetingsapp",
        "Cisco-Systems.Spark",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "net.whatsapp.WhatsApp",
        "desktop.WhatsApp",
        "ru.keepcoder.Telegram",
        "org.telegram.desktop",
        "com.skype.skype",
        "com.microsoft.SkypeForBusiness",
        "com.ringcentral.glip",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan", // Google Meet web app
        "com.signal.Signal",
        "org.whispersystems.signal-desktop",
    ]

    /// System services that use the microphone briefly or in the background.
    private static let ignoredPrefixes: [String] = [
        "com.apple.SpeechRecognitionCore",
        "com.apple.speech",
        "com.apple.corespeech",
        "com.apple.CoreSpeech",
        "com.apple.assistant",
        "com.apple.Siri",
        "com.apple.siri",
        "com.apple.dictation",
        "com.apple.DictationIM",
        "com.apple.accessibility",
        "com.apple.controlcenter",
        "com.apple.audio",
        "com.apple.coreaudiod",
        "com.apple.systemsoundserverd",
        "com.apple.SoundAnalysis",
        "com.apple.mediaanalysisd",
        "com.apple.universalaccess",
    ]

    public static func isCallApp(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return callApps.contains(bundleIdentifier)
    }

    public static func shouldIgnore(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
        return ignoredPrefixes.contains { bundleIdentifier.hasPrefix($0) }
    }

    /// Strips helper suffixes so "com.google.Chrome.helper" maps to "com.google.Chrome".
    public static func appBundleIdentifier(forHelper bundleIdentifier: String) -> String {
        let suffixes = [".helper.Renderer", ".helper.GPU", ".helper.Plugin", ".helper.Alerts", ".helper"]
        for suffix in suffixes where bundleIdentifier.hasSuffix(suffix) {
            return String(bundleIdentifier.dropLast(suffix.count))
        }
        return bundleIdentifier
    }
}

public enum HeadphoneSymbol {
    /// The SF Symbol that best matches a Bluetooth audio device name.
    public static func symbol(forDeviceName name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("airpods max") { return "airpodsmax" }
        if lowered.contains("airpods pro") { return "airpodspro" }
        if lowered.contains("airpods") { return "airpods" }
        if lowered.contains("beats") { return "beats.headphones" }
        return "headphones"
    }
}

/// Numbers for the liquid effect.
public enum GooMath {
    /// Blur radius at full strength. Small enough that a 24 pt pill never blurs away.
    public static let maximumBlur: Double = 7

    public static func blurRadius(strength: Double) -> Double {
        maximumBlur * min(max(strength, 0), 1)
    }

    /// Alpha multiplier that turns the blurred edge back into a sharp one about 1.5 px wide.
    /// At zero blur it is 1, so the effect fades out without a visible jump.
    public static func alphaSlope(blurRadius: Double, displayScale: Double) -> Double {
        max(1, 1.67 * blurRadius * max(displayScale, 1))
    }

    /// Bias that keeps the visible edge at half coverage for any slope.
    public static func alphaBias(slope: Double) -> Double {
        0.5 - 0.5 * slope
    }
}
