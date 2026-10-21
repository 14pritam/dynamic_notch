import CoreGraphics

/// How the shape relates to the notch.
public enum NotchStyle: String, CaseIterable, Sendable, Codable, Identifiable {
    /// The notch itself grows: flat top fused to the screen edge, content beside the camera.
    case notch
    /// A separate capsule floating below the notch, like the iPhone island.
    case island

    public var id: String { rawValue }
}

/// Overall size of everything the notch shows. Large is the original design.
public enum NotchSize: String, CaseIterable, Sendable, Codable, Identifiable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    /// Multiplier applied to ears, alerts, expanded views and all content inside them.
    public var scale: CGFloat {
        switch self {
        case .small: 0.8
        case .medium: 0.9
        case .large: 1
        }
    }
}

/// The user's size and position choices.
public struct NotchAppearance: Equatable, Sendable, Codable {
    public var style: NotchStyle
    /// Notch style: how far the shape reaches either side of the camera.
    /// Island style: width of the idle pill.
    public var width: Double
    /// Thickness of the compact shape. In notch style it never goes below the notch height.
    public var height: Double
    /// Island style only: gap between the notch (or menu bar) and the pill. Negative pulls it up.
    public var verticalOffset: Double
    /// Island style only: shift from the notch centre. Positive moves right.
    public var horizontalOffset: Double
    /// Pure black with no shadow or outline, so the shape is indistinguishable from the notch.
    public var pitchBlack: Bool
    /// Small, medium or large. Width and thickness fine-tune on top of it.
    public var size: NotchSize

    public init(
        style: NotchStyle = .notch,
        width: Double,
        height: Double,
        verticalOffset: Double,
        horizontalOffset: Double,
        pitchBlack: Bool = true,
        size: NotchSize = .large
    ) {
        self.style = style
        self.width = width
        self.height = height
        self.verticalOffset = verticalOffset
        self.horizontalOffset = horizontalOffset
        self.pitchBlack = pitchBlack
        self.size = size
    }

    public static let standard = NotchAppearance(
        style: .notch,
        width: 200,
        height: 32,
        verticalOffset: 6,
        horizontalOffset: 0,
        pitchBlack: true,
        size: .large
    )

    public static let widthRange: ClosedRange<Double> = 120...420
    public static let heightRange: ClosedRange<Double> = 24...52
    public static let verticalOffsetRange: ClosedRange<Double> = -40...60
    public static let horizontalOffsetRange: ClosedRange<Double> = -600...600

    /// Brings every value into its supported range, replacing non-finite values with defaults.
    public func clamped() -> NotchAppearance {
        NotchAppearance(
            style: style,
            width: Self.clamp(width, to: Self.widthRange, fallback: Self.standard.width),
            height: Self.clamp(height, to: Self.heightRange, fallback: Self.standard.height),
            verticalOffset: Self.clamp(verticalOffset, to: Self.verticalOffsetRange, fallback: Self.standard.verticalOffset),
            horizontalOffset: Self.clamp(horizontalOffset, to: Self.horizontalOffsetRange, fallback: Self.standard.horizontalOffset),
            pitchBlack: pitchBlack,
            size: size
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
