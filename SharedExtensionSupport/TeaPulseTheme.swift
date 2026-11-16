import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum TeaPulseSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
}

public enum TeaPulseRadius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20
    public static let full: CGFloat = 9999
}

public enum TeaPulseTheme {
    public static let surface = adaptiveColor(dark: 0x0B0D13, light: 0xF8FAFC)
    public static let surfaceCard = adaptiveColor(dark: 0x12151E, light: 0xFFFFFF)
    public static let surfaceElevated = adaptiveColor(dark: 0x1A1E2B, light: 0xF1F5F9)
    public static let neutral = adaptiveColor(dark: 0x23293A, light: 0xE2E8F0)
    public static let onSurface = adaptiveColor(dark: 0xF1F5F9, light: 0x0F172A)
    public static let secondary = adaptiveColor(dark: 0x94A3B8, light: 0x475569)
    public static let primary = adaptiveColor(dark: 0x10B981, light: 0x047857)
    public static let primaryAction = adaptiveColor(dark: 0x10B981, light: 0x047857)
    public static let primaryHover = adaptiveColor(dark: 0x34D399, light: 0x065F46)
    public static let onPrimary = adaptiveColor(dark: 0x04130D, light: 0xFFFFFF)
    public static let tertiary = adaptiveColor(dark: 0xA78BFA, light: 0x6D28D9)
    public static let warning = adaptiveColor(dark: 0xFBBF24, light: 0xB45309)
    public static let error = adaptiveColor(dark: 0xF87171, light: 0xB91C1C)

    // Always-dark code & ANSI surfaces per DESIGN.md
    public static let codeSurface = fixedColor(hex: 0x0B0D13)
    public static let terminalSurface = fixedColor(hex: 0x050608)
    public static let codeText = fixedColor(hex: 0xF1F5F9)
    public static let codeMuted = fixedColor(hex: 0x94A3B8)
    public static let codePrimary = fixedColor(hex: 0x10B981)
    public static let codeTertiary = fixedColor(hex: 0xA78BFA)
    public static let codeWarning = fixedColor(hex: 0xFBBF24)
    public static let codeError = fixedColor(hex: 0xF87171)
    public static let diffAddHighlight = Color(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0, opacity: 0.14)
    public static let diffDeleteHighlight = Color(red: 248.0 / 255.0, green: 113.0 / 255.0, blue: 113.0 / 255.0, opacity: 0.14)

    public static let cardBorder = adaptiveColor(dark: 0xFFFFFF, darkAlpha: 0.08, light: 0x0F172A, lightAlpha: 0.08)

    private static func fixedColor(hex: UInt32, alpha: Double = 1.0) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    private static func adaptiveColor(
        dark: UInt32,
        darkAlpha: Double = 1.0,
        light: UInt32,
        lightAlpha: Double = 1.0
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let alpha = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: alpha
            )
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            let alpha = isDark ? darkAlpha : lightAlpha
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: alpha
            )
        })
        #else
        return fixedColor(hex: dark, alpha: darkAlpha)
        #endif
    }
}

public enum TeaPulseTypography {
    public static let headlineLg = Font.system(size: 24, weight: .semibold, design: .default)
    public static let headlineMd = Font.system(size: 18, weight: .semibold, design: .default)
    public static let bodyMd = Font.system(size: 15, weight: .regular, design: .default)
    public static let bodySm = Font.system(size: 13, weight: .regular, design: .default)
    public static let labelMd = Font.system(size: 12, weight: .medium, design: .default)
    public static let codeMd = Font.system(size: 13, weight: .regular, design: .monospaced)
    public static let codeSm = Font.system(size: 12, weight: .medium, design: .monospaced)
}
