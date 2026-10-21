import CoreGraphics

/// The parts of a display the layout needs. All rects use a top-left origin, in points,
/// relative to the display itself.
public struct ScreenMetrics: Equatable, Sendable {
    public var size: CGSize
    /// The camera housing, if the display has one.
    public var notch: CGRect?
    public var menuBarHeight: CGFloat

    public init(size: CGSize, notch: CGRect?, menuBarHeight: CGFloat) {
        self.size = size
        self.notch = notch
        self.menuBarHeight = menuBarHeight
    }

    public var hasNotch: Bool { notch != nil }

    /// Bottom edge of the notch, or of the menu bar on displays without one.
    public var topInset: CGFloat { notch?.maxY ?? menuBarHeight }

    public var centerX: CGFloat { notch?.midX ?? size.width / 2 }

    /// A 14" MacBook-like display, used for previews and tests.
    public static let sample = ScreenMetrics(
        size: CGSize(width: 1512, height: 982),
        notch: CGRect(x: 666, y: 0, width: 180, height: 32),
        menuBarHeight: 33
    )
}
