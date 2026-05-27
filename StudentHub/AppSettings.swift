//
//  AppSettings.swift
//  StudentHub
//
//  Modèle de préférences partagées via @AppStorage / UserDefaults
//

import SwiftUI

/// Singleton observable qui centralise toutes les préférences utilisateur.
/// Injecté dans l'environnement depuis StudentHubApp afin que chaque vue puisse y accéder.
@Observable
class AppSettings {

    // MARK: - Apparence
    var accentColorName: String {
        get { UserDefaults.standard.string(forKey: "accentColorName") ?? "Bleu" }
        set { UserDefaults.standard.set(newValue, forKey: "accentColorName") }
    }

    var colorSchemePreference: String {
        get { UserDefaults.standard.string(forKey: "colorSchemePreference") ?? "Système" }
        set { UserDefaults.standard.set(newValue, forKey: "colorSchemePreference") }
    }

    // MARK: - OneDrive
    var oneDrivePath: String {
        get { UserDefaults.standard.string(forKey: "oneDrivePath") ?? "/Users/gauthierbaudelet/Library/CloudStorage/OneDrive-UCL/Drive_perso/" }
        set { UserDefaults.standard.set(newValue, forKey: "oneDrivePath") }
    }

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

    // MARK: - Helpers

    var resolvedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "Clair":  return .light
        case "Sombre": return .dark
        default:       return nil   // Système
        }
    }

    var accentColor: Color {
        switch accentColorName {
        case "Rouge":   return .red
        case "Vert":    return .green
        case "Orange":  return .orange
        case "Violet":  return .purple
        case "Rose":    return .pink
        case "Jaune":   return .yellow
        default:        return .blue
        }
    }

    static let accentOptions   = ["Bleu", "Rouge", "Vert", "Orange", "Violet", "Rose", "Jaune"]
    static let schemeOptions   = ["Système", "Clair", "Sombre"]
    static let levelOptions    = ["BAC1", "BAC2", "BAC3", "M1", "M2"]
    static let quadOptions     = ["Q1", "Q2"]
}
