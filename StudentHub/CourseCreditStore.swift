//
//  CourseCreditStore.swift
//  StudentHub
//
//  Système complet de gestion des notes et calcul de moyenne.
//

import Foundation
import Observation

// MARK: - Modèles

struct NoteEvaluation: Identifiable, Codable, Equatable {
    var id = UUID()
    var titre: String           // ex: "Examen Janvier", "Labo 3"
    var type: TypeEvaluation
    var note: Double            // /20 par défaut
    var noteSur: Double         // base (20, 100, etc.)
    var ponderation: Double     // coefficient (ex: 0.4 = 40%)
    var date: Date
    var commentaire: String

    /// Note ramenée sur 20
    var noteSur20: Double {
        guard noteSur > 0 else { return 0 }
        return (note / noteSur) * 20
    }
}

enum TypeEvaluation: String, Codable, CaseIterable, Identifiable {
    case examen     = "Examen"
    case partiel    = "Partiel"
    case labo       = "Laboratoire"
    case devoir     = "Devoir"
    case projet     = "Projet"
    case oral       = "Oral"
    case autre      = "Autre"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .examen:  return "doc.text.fill"
        case .partiel: return "doc.on.doc"
        case .labo:    return "flask.fill"
        case .devoir:  return "pencil"
        case .projet:  return "folder.fill"
        case .oral:    return "mic.fill"
        case .autre:   return "ellipsis.circle"
        }
    }

    var couleurNom: String {
        switch self {
        case .examen:  return "red"
        case .partiel: return "orange"
        case .labo:    return "green"
        case .devoir:  return "blue"
        case .projet:  return "purple"
        case .oral:    return "pink"
        case .autre:   return "gray"
        }
    }
}

/// Résumé des notes pour un cours donné
struct MoyenneCours {
    let code: String
    let moyenne: Double?          // nil si aucune note
    let mentionTexte: String
    let mentionCouleur: String    // "green", "orange", "red"
    let nbNotes: Int
    let pondsTotal: Double        // somme des pondérations
    let estValide: Bool           // ponds == 1.0 (100%)
}

// MARK: - Store

@Observable
class CourseCreditStore {

    static let shared = CourseCreditStore()

    /// notes[codeCours] = [NoteEvaluation]
    private(set) var notes: [String: [NoteEvaluation]] = [:]

    private init() {
        charger()
    }

    // MARK: CRUD

    func ajouterNote(_ note: NoteEvaluation, pourCours code: String) {
        notes[code, default: []].append(note)
        sauvegarder()
    }

    func supprimerNote(id: UUID, pourCours code: String) {
        notes[code]?.removeAll { $0.id == id }
        sauvegarder()
    }

    func modifierNote(_ note: NoteEvaluation, pourCours code: String) {
        guard let idx = notes[code]?.firstIndex(where: { $0.id == note.id }) else { return }
        notes[code]?[idx] = note
        sauvegarder()
    }

    func notesFor(_ code: String) -> [NoteEvaluation] {
        notes[code] ?? []
    }

    // MARK: Calcul moyenne

    /// Calcule la moyenne pondérée /20 pour un cours.
    /// Si les pondérations ne font pas 100 %, on calcule tout de même une moyenne
    /// partielle avec les pondérations disponibles (affiche un avertissement).
    func moyennePour(_ code: String) -> MoyenneCours {
        let liste = notesFor(code)
        guard !liste.isEmpty else {
            return MoyenneCours(code: code, moyenne: nil,
                                mentionTexte: "Aucune note",
                                mentionCouleur: "gray",
                                nbNotes: 0, pondsTotal: 0, estValide: false)
        }

        // --- Calcul pondéré ---
        let somme = liste.reduce(0.0) { $0 + $1.noteSur20 * $1.ponderation }
        let ponds = liste.reduce(0.0) { $0 + $1.ponderation }
        let moy   = ponds > 0 ? somme / ponds : 0

        let estValide = abs(ponds - 1.0) < 0.001

        let mention: (String, String)
        switch moy {
        case 16...:         mention = ("Distinction", "green")
        case 14..<16:       mention = ("Satisfaisant", "green")
        case 12..<14:       mention = ("Suffisant", "orange")
        case 10..<12:       mention = ("Passable", "orange")
        default:            mention = ("Insuffisant", "red")
        }

        return MoyenneCours(code: code,
                            moyenne: moy,
                            mentionTexte: mention.0,
                            mentionCouleur: mention.1,
                            nbNotes: liste.count,
                            pondsTotal: ponds,
                            estValide: estValide)
    }

    // MARK: Persistance

    private var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("StudentHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes_cours.json")
    }

    func sauvegarder() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL)
    }

    private func charger() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [NoteEvaluation]].self, from: data)
        else { return }
        notes = decoded
    }
}
