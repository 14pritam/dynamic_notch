import CoreGraphics

/// Every size used by the shape. DESIGN.md documents these numbers; keep the two in sync.
public enum IslandMetrics {
    /// Width of each leading/trailing slot in island style.
    public static func slotWidth(height: CGFloat) -> CGFloat {
        (height * 1.15).rounded()
    }

    /// Notch style: width of each region beside the camera ("ear"). The width setting widens it.
    public static func earWidth(_ appearance: NotchAppearance, height: CGFloat) -> CGFloat {
        let slot = slotWidth(height: height)
        return max((slot * 0.8).rounded(), (slot + (appearance.width - 180) / 2).rounded())
    }

    /// Island style compact size.
    public static func compactSize(_ appearance: NotchAppearance) -> CGSize {
        let height = appearance.height
        return CGSize(width: appearance.width + 2 * slotWidth(height: height), height: height)
    }

    public static func idleSize(_ appearance: NotchAppearance) -> CGSize {
        CGSize(width: appearance.width, height: appearance.height)
    }

    public static func bubbleGap(_ appearance: NotchAppearance) -> CGFloat {
        max(6, (appearance.height * 0.24).rounded())
    }

    /// Island style alert size.
    public static func alertSize(_ appearance: NotchAppearance) -> CGSize {
        CGSize(
            width: max(compactSize(appearance).width + 70, 300),
            height: appearance.height + 16
        )
    }

    public static func expandedWidth(_ appearance: NotchAppearance) -> CGFloat {
        min(max(appearance.width + 190, 360), 560)
    }

    /// Height of the content area of each expanded view. The shape adds padding (island) or the
    /// notch strip (notch) around it.
    public enum ContentHeight {
        public static let nowPlaying: CGFloat = 140
        public static let timer: CGFloat = 72
        public static let call: CGFloat = 72
        public static let home: CGFloat = 84
        public static let homeWithMedia: CGFloat = 144
        public static let drop: CGFloat = 100
        public static let timerFinished: CGFloat = 72
        public static let maximum: CGFloat = 144
    }

    /// Island style: vertical padding above and below expanded content.
    public static let islandExpandedPadding: CGFloat = 14
    public static let islandExpandedRadius: CGFloat = 36
    /// Notch style: space between the notch strip and the content, and below the content.
    public static let notchContentGap: CGFloat = 2
    public static let notchBottomPadding: CGFloat = 14
    public static let notchExpandedRadius: CGFloat = 30
    /// Concave shoulders where the shape meets the top edge, like the real notch.
    public static let compactFlare: CGFloat = 6
    public static let expandedFlare: CGFloat = 10
    /// Notch style: minimum width of each alert ear, so "Low Battery" fits beside the camera.
    public static let alertEarWidth: CGFloat = 128

    /// Room around the content for the shadow.
    public static let windowMargin: CGFloat = 48
    /// Closest the widest view may come to a screen edge.
    public static let screenEdgeInset: CGFloat = 8
    /// How much a hovered compact shape grows (horizontal each side, vertical).
    public static let hoverGrowth = CGSize(width: 3, height: 2)
    /// Extra hit area around the shape so the pointer doesn't have to be pixel-perfect.
    public static let hitSlop: CGFloat = 4
    /// Width of the virtual notch on displays without one.
    public static let virtualNotchWidth: CGFloat = 180
}
