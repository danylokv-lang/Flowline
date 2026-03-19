/*
    Flowline Design System
    Matches the website exactly — same tokens, same palette.

    Website tokens → App names:
      --bg        → mainBg      #080810  Deep navy black
      --bg-s      → secondBg   #0e0e1c  Card / panel surface
      --bg-t      → tertiaryBg #14142a  Input / elevated surface
      --txt       → mainTxt    #eeeef5  Primary text
      --txt2      → secondTxt  #7a7a9a  Secondary / muted text
      --txt3      → dimTxt     #44445a  Placeholder / disabled
      --accent    → accent     #6d4cfa  Purple — buttons, links
      --accent-hi → accentHi   #8b6dff  Lighter purple — hover, glow
      --border    → border     7% white  Subtle separator
      --border-hi → borderHi  13% white  Emphasized separator
*/

import SwiftUI

enum FlowLineTheme {

    // ── Backgrounds ───────────────────────────────────────────────────────
    static let mainBg      = Color(hex: "#080810")   // deepest bg
    static let secondBg    = Color(hex: "#0e0e1c")   // panel / card
    static let tertiaryBg  = Color(hex: "#14142a")   // input field / elevated

    // ── Text ──────────────────────────────────────────────────────────────
    static let mainTxt     = Color(hex: "#eeeef5")   // primary
    static let secondTxt   = Color(hex: "#7a7a9a")   // secondary
    static let dimTxt      = Color(hex: "#44445a")   // placeholder / disabled

    // ── Accent ────────────────────────────────────────────────────────────
    static let accent      = Color(hex: "#6d4cfa")   // brand purple
    static let accentHi    = Color(hex: "#8b6dff")   // lighter purple

    // ── Borders ───────────────────────────────────────────────────────────
    static let border      = Color.white.opacity(0.07)
    static let borderHi    = Color.white.opacity(0.13)

    // ── Accent tint (for backgrounds behind accent elements) ──────────────
    static let accentBg    = Color(hex: "#6d4cfa").opacity(0.10)
}

// MARK: - Color(hex:) initialiser

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: h).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >>  8) & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
