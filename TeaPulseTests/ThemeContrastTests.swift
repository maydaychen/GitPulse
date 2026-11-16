import SwiftUI
import UIKit
import Testing
@testable import TeaPulse

@MainActor
@Suite("Theme contrast")
struct ThemeContrastTests {
    @Test("Primary button text adapts to light mode and stays legible when pressed")
    func primaryButtonContrast() throws {
        #expect(try luminance(TeaPulseTheme.onPrimary, style: .light) > 0.95)
        #expect(try luminance(TeaPulseTheme.onPrimary, style: .dark) < 0.05)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let foreground = try luminance(TeaPulseTheme.onPrimary, style: style)
            for color in [TeaPulseTheme.primaryAction, TeaPulseTheme.primaryHover] {
                let background = try luminance(color, style: style)
                let ratio = (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
                #expect(ratio >= 4.5)
            }
        }
    }

    @Test("All semantic foregrounds pass WCAG AA across adaptive surfaces")
    func semanticSurfaceContrast() throws {
        let foregrounds: [(String, Color)] = [
            ("onSurface", TeaPulseTheme.onSurface),
            ("secondary", TeaPulseTheme.secondary),
            ("primary", TeaPulseTheme.primary),
            ("tertiary", TeaPulseTheme.tertiary),
            ("warning", TeaPulseTheme.warning),
            ("error", TeaPulseTheme.error),
        ]
        let backgrounds: [(String, Color)] = [
            ("surface", TeaPulseTheme.surface),
            ("surfaceCard", TeaPulseTheme.surfaceCard),
            ("surfaceElevated", TeaPulseTheme.surfaceElevated),
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (fgName, fgColor) in foregrounds {
                for (bgName, bgColor) in backgrounds {
                    let ratio = try contrastRatio(fgColor, over: bgColor, style: style)
                    #expect(ratio >= 4.5, "\(fgName) on \(bgName) in \(style == .light ? "light" : "dark") was \(ratio)")
                }
            }
        }
    }

    @Test("Always-dark code and terminal colors stay legible regardless of system appearance")
    func codeAndTerminalContrast() throws {
        let foregrounds: [(String, Color)] = [
            ("codeText", TeaPulseTheme.codeText),
            ("codeMuted", TeaPulseTheme.codeMuted),
            ("codePrimary", TeaPulseTheme.codePrimary),
            ("codeTertiary", TeaPulseTheme.codeTertiary),
            ("codeWarning", TeaPulseTheme.codeWarning),
            ("codeError", TeaPulseTheme.codeError),
        ]
        let backgrounds: [(String, Color)] = [
            ("codeSurface", TeaPulseTheme.codeSurface),
            ("terminalSurface", TeaPulseTheme.terminalSurface),
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (fgName, fgColor) in foregrounds {
                for (bgName, bgColor) in backgrounds {
                    let ratio = try contrastRatio(fgColor, over: bgColor, style: style)
                    #expect(ratio >= 4.5, "\(fgName) on \(bgName) in \(style == .light ? "light" : "dark") was \(ratio)")
                }
            }
        }
    }

    private func contrastRatio(_ fg: Color, over bg: Color, style: UIUserInterfaceStyle) throws -> Double {
        let l1 = try luminance(fg, style: style)
        let l2 = try luminance(bg, style: style)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func luminance(_ color: Color, style: UIUserInterfaceStyle) throws -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        try #require(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        let linear = [red, green, blue].map { value in
            let channel = Double(value)
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
