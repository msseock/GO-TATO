import UIKit

enum GTTColor {

    // MARK: - Brand & Accent
    static let brand        = UIColor(hex: "#F07A58")
    static let brandAmber   = UIColor(hex: "#F5B748")
    static let black        = UIColor(hex: "#000000")
    static let white        = UIColor(hex: "#FFFFFF")

    // MARK: - Text
    static let textPrimary   = UIColor(hex: "#2C1F14")
    static let textSecondary = UIColor(hex: "#9A8778")
    static let textSubtle    = UIColor(hex: "#BEB0A3")
    static let textMuted     = UIColor(hex: "#C4B5A5")

    // MARK: - Background & Surface
    static let bgPrimary  = UIColor(hex: "#FFF8EE")
    static let bgCard     = UIColor(hex: "#FFF8EE")
    static let bgLight    = UIColor(hex: "#FFFAF4")
    static let surface    = UIColor(hex: "#F5EFE6")
    static let divider    = UIColor(hex: "#EDE4D8")

    // MARK: - Success
    static let success       = UIColor(hex: "#79BF8B")
    static let successLight  = UIColor(hex: "#E8F5E9")
    static let successBorder = UIColor(hex: "#BBF7D0")
    static let successMid    = UIColor(hex: "#A8D5BA")
    static let successBg     = UIColor(hex: "#E5F5E8")
    static let successDark   = UIColor(hex: "#2D5E3A")
    static let successText   = UIColor(hex: "#4A9B5E")

    // MARK: - Sage
    static let sage       = UIColor(hex: "#A8C4A0")
    static let sageLight  = UIColor(hex: "#EDF0EB")
    static let sageBg     = UIColor(hex: "#D8E8D4")
    static let sageBorder = UIColor(hex: "#B8D4B0")
    static let greenDark  = UIColor(hex: "#7BAB61")

    // MARK: - Warning
    static let warning      = UIColor(hex: "#FFD233")
    static let warningDark  = UIColor(hex: "#E8A800")
    static let warningText  = UIColor(hex: "#B8860B")
    static let warningBg    = UIColor(hex: "#FFF4D4")
    static let streakToday  = UIColor(hex: "#F5B748")

    // MARK: - Info
    static let info      = UIColor(hex: "#5B8DEF")
    static let infoLight = UIColor(hex: "#EEF4F8")
    static let infoText  = UIColor(hex: "#6A7FC0")

    // MARK: - Error
    static let error      = UIColor(hex: "#F44336")
    static let errorLight = UIColor(hex: "#FBE4E0")

    // MARK: - Neutral
    static let tan       = UIColor(hex: "#D4C4B4")
    static let grayLight = UIColor(hex: "#F5F5F5")
}

// MARK: - UIColor+Hex
extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: alpha
        )
    }
}
