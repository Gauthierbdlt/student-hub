//
//  GestionnaireFichiers.swift
//  StudentHub
//
//  Created by Gauthier Baudelet on 5/26/26.
//

import Foundation

struct StatutTP {
    let numero: Int
    let existe: Bool
    let nomDossierTrouve: String?
    let cheminComplet: String?
}

struct GestionnaireFichiers {
    static let basePath = "/Users/gauthierbaudelet/Library/CloudStorage/OneDrive-UCL/Drive_perso/"
    
    static func analyserContenu(niveau: String, quadri: String, code: String, type: String, jusqua: Int) -> [StatutTP] {
        // SÉCURITÉ : On s'assure que la plage est valide
        let nombreReel = max(0, jusqua)
        guard nombreReel > 0 else { return [] }
        
        let pathBase = "\(basePath)\(niveau)/\(quadri)/"
        let fileManager = FileManager.default
        
        guard let racines = try? fileManager.contentsOfDirectory(atPath: pathBase),
              let dossierCours = racines.first(where: { $0.hasPrefix(code + "-") }) else {
            return (1...nombreReel).map { StatutTP(numero: $0, existe: false, nomDossierTrouve: nil, cheminComplet: nil) }
        }
        
        let pathRecherche = "\(pathBase)\(dossierCours)/\(code)-\(type)"
        let contenu = (try? fileManager.contentsOfDirectory(atPath: pathRecherche)) ?? []
        
        return (1...nombreReel).map { i in
            let prefixe = String(format: "%@-%@-%02d", code, type, i)
            if let trouve = contenu.first(where: { $0.hasPrefix(prefixe) }) {
                return StatutTP(numero: i, existe: true, nomDossierTrouve: trouve,
                                cheminComplet: "\(pathRecherche)/\(trouve)")
            }
            return StatutTP(numero: i, existe: false, nomDossierTrouve: nil, cheminComplet: nil)
        }
    }
}


struct NoteManager {
    static func sauvegarderNotes(pour code: String, notes: [NoteCours]) {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: "notes_\(code)")
        }
    }
    
    static func chargerNotes(pour code: String) -> [NoteCours] {
        guard let data = UserDefaults.standard.data(forKey: "notes_\(code)"),
              let decoded = try? JSONDecoder().decode([NoteCours].self, from: data) else {
            return []
        }
        return decoded
    }
}
