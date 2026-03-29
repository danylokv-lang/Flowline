/*
    Flowline Design System — Cool Slate + Electric Blue

    Tokens:
      mainBg      #0a0a0f  Deep slate black
      secondBg    #111118  Card / panel surface
      tertiaryBg  #16161f  Input / elevated surface
      mainTxt     #e8e8f0  Cool white
      secondTxt   #6b6b80  Muted slate
      dimTxt      #3a3a4a  Placeholder / disabled
      accent      #3b82f6  Electric blue
      accentHi    #60a5fa  Lighter blue
      border      6% white  Subtle separator
      borderHi    10% white  Emphasized separator
*/

import SwiftUI

enum FlowLineTheme {

    // ── Backgrounds ───────────────────────────────────────────────────────
    static let mainBg      = Color(hex: "#0a0a0f")   // deepest bg
    static let secondBg    = Color(hex: "#111118")   // panel / card
    static let tertiaryBg  = Color(hex: "#16161f")   // input field / elevated

    // ── Text ──────────────────────────────────────────────────────────────
    static let mainTxt     = Color(hex: "#e8e8f0")   // primary
    static let secondTxt   = Color(hex: "#6b6b80")   // secondary
    static let dimTxt      = Color(hex: "#3a3a4a")   // placeholder / disabled

    // ── Accent ────────────────────────────────────────────────────────────
    static let accent      = Color(hex: "#3b82f6")   // electric blue
    static let accentHi    = Color(hex: "#60a5fa")   // lighter blue

    // ── Borders ───────────────────────────────────────────────────────────
    static let border      = Color.white.opacity(0.06)
    static let borderHi    = Color.white.opacity(0.10)

    // ── Accent tint ───────────────────────────────────────────────────────
    static let accentBg    = Color(hex: "#3b82f6").opacity(0.10)
}

// MARK: - Keyboard dismiss helper (iOS only)

#if os(iOS)
import UIKit
#endif

extension View {
    func hideKeyboardOnTap() -> some View {
        #if os(iOS)
        return self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        #else
        return self
        #endif
    }
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
