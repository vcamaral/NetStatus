import AppKit

/// Draws the menu bar glyph: a plain colored dot, deliberately nothing like the system Wi-Fi icon
/// so the two are never confused at a glance.
enum StatusIcon {
    private static let canvas: CGFloat = 18
    private static let diameter: CGFloat = 11

    static func dot(color: NSColor, alpha: CGFloat = 1) -> NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas))
        image.lockFocus()
        let rect = NSRect(x: (canvas - diameter) / 2, y: (canvas - diameter) / 2, width: diameter, height: diameter)
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(ovalIn: rect).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func color(for status: ConnectionStatus) -> NSColor {
        switch status {
        case .online: return NSColor(srgbRed: 0.19, green: 0.82, blue: 0.35, alpha: 1)   // systemGreen
        case .slow: return NSColor(srgbRed: 1.00, green: 0.62, blue: 0.04, alpha: 1)     // systemOrange
        case .offline: return NSColor(srgbRed: 1.00, green: 0.27, blue: 0.23, alpha: 1)  // systemRed
        case .checking: return NSColor(white: 0.56, alpha: 1)                            // systemGray
        }
    }
}
