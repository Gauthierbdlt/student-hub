//
//  AppSettings.swift
//  StudentHub
//
//  Modèle de préférences partagées — apparence, OneDrive, Strava, profil.
//

import SwiftUI

// MARK: - Thème de couleur (gradient + teinte)

struct ThemeCouleur: Identifiable, Equatable {
    let id: String           // clé de persistance
    let nom: String
    let base: Color          // couleur d'accent
    let gradientStart: Color
    let gradientEnd: Color
    let gradientAngle: Double

    /// Gradient linéaire pour les headers / sidebar
    var gradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: UnitPoint(angle: gradientAngle),
            endPoint: UnitPoint(angle: gradientAngle + 180)
        )
    }

    /// Gradient subtil pour les fonds de cartes
    var softGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart.opacity(0.12), gradientEnd.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ThemeCouleur {
    static let catalogue: [ThemeCouleur] = [
        ThemeCouleur(
            id: "bleu",       nom: "Océan",
            base: Color(hex: "#2563EB"),
            gradientStart: Color(hex: "#1D4ED8"),
            gradientEnd:   Color(hex: "#7C3AED"),
            gradientAngle: 135
        ),
        ThemeCouleur(
            id: "violet",     nom: "Dusk",
            base: Color(hex: "#7C3AED"),
            gradientStart: Color(hex: "#6D28D9"),
            gradientEnd:   Color(hex: "#DB2777"),
            gradientAngle: 135
        ),
        ThemeCouleur(
            id: "vert",       nom: "Forêt",
            base: Color(hex: "#059669"),
            gradientStart: Color(hex: "#065F46"),
            gradientEnd:   Color(hex: "#0D9488"),
            gradientAngle: 145
        ),
        ThemeCouleur(
            id: "orange",     nom: "Soleil",
            base: Color(hex: "#EA580C"),
            gradientStart: Color(hex: "#DC2626"),
            gradientEnd:   Color(hex: "#D97706"),
            gradientAngle: 125
        ),
        ThemeCouleur(
            id: "rose",       nom: "Sakura",
            base: Color(hex: "#DB2777"),
            gradientStart: Color(hex: "#9D174D"),
            gradientEnd:   Color(hex: "#7C3AED"),
            gradientAngle: 140
        ),
        ThemeCouleur(
            id: "cyan",       nom: "Arctic",
            base: Color(hex: "#0891B2"),
            gradientStart: Color(hex: "#0E7490"),
            gradientEnd:   Color(hex: "#2563EB"),
            gradientAngle: 150
        ),
        ThemeCouleur(
            id: "ardoise",    nom: "Ardoise",
            base: Color(hex: "#475569"),
            gradientStart: Color(hex: "#1E293B"),
            gradientEnd:   Color(hex: "#334155"),
            gradientAngle: 160
        ),
    ]

    static func chercher(id: String) -> ThemeCouleur {
        catalogue.first { $0.id == id } ?? catalogue[0]
    }
}

// MARK: - Extension Color hex

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

extension UnitPoint {
    init(angle degrees: Double) {
        let rad = degrees * .pi / 180
        self.init(x: 0.5 + cos(rad) * 0.5, y: 0.5 + sin(rad) * 0.5)
    }
}

// MARK: - AppSettings

/// Singleton observable qui centralise toutes les préférences utilisateur.
@Observable
class AppSettings {

    // MARK: - Apparence
    var themeId: String {
        get { UserDefaults.standard.string(forKey: "themeId") ?? "bleu" }
        set { UserDefaults.standard.set(newValue, forKey: "themeId") }
    }

    var useGradient: Bool {
        get { UserDefaults.standard.object(forKey: "useGradient") == nil
              ? true
              : UserDefaults.standard.bool(forKey: "useGradient") }
        set { UserDefaults.standard.set(newValue, forKey: "useGradient") }
    }

    var colorSchemePreference: String {
        get { UserDefaults.standard.string(forKey: "colorSchemePreference") ?? "Système" }
        set { UserDefaults.standard.set(newValue, forKey: "colorSchemePreference") }
    }

    // MARK: - Profil
    var studentName: String {
        get { UserDefaults.standard.string(forKey: "studentName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "studentName") }
    }

    var university: String {
        get { UserDefaults.standard.string(forKey: "university") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "university") }
    }

    var currentLevel: String {
        get { UserDefaults.standard.string(forKey: "currentLevel") ?? "BAC1" }
        set { UserDefaults.standard.set(newValue, forKey: "currentLevel") }
    }

    var currentQuadrimestre: String {
        get { UserDefaults.standard.string(forKey: "currentQuadrimestre") ?? "Q1" }
        set { UserDefaults.standard.set(newValue, forKey: "currentQuadrimestre") }
    }

    // MARK: - OneDrive
    var oneDrivePath: String {
        get { UserDefaults.standard.string(forKey: "oneDrivePath")
              ?? "/Users/gauthierbaudelet/Library/CloudStorage/OneDrive-UCL/Drive_perso/" }
        set { UserDefaults.standard.set(newValue, forKey: "oneDrivePath") }
    }

    // MARK: - Strava
    var stravaClientId: String {
        get { UserDefaults.standard.string(forKey: "stravaClientId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "stravaClientId") }
    }

    var stravaConnected: Bool {
        get { UserDefaults.standard.bool(forKey: "stravaConnected") }
        set { UserDefaults.standard.set(newValue, forKey: "stravaConnected") }
    }

    var stravaAthleteId: String {
        get { UserDefaults.standard.string(forKey: "stravaAthleteId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "stravaAthleteId") }
    }

    // MARK: - Helpers calculés

    var resolvedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "Clair":  return .light
        case "Sombre": return .dark
        default:       return nil
        }
    }

    var theme: ThemeCouleur { ThemeCouleur.chercher(id: themeId) }

    /// Couleur d'accent principale (utilisée pour .tint)
    var accentColor: Color { theme.base }

    // Compatibilité avec l'ancien code qui utilisait accentColorName
    var accentColorName: String {
        get { themeId }
        set { themeId = newValue }
    }

    // MARK: - Options statiques

    static let schemeOptions = ["Système", "Clair", "Sombre"]
    static let levelOptions  = ["BAC1", "BAC2", "BAC3", "M1", "M2"]
    static let quadOptions   = ["Q1", "Q2"]
}
