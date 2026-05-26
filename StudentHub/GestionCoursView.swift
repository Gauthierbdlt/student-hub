//
//  GestionCoursView.swift
//  StudentHub
//
//  Created by Gauthier Baudelet on 5/26/26.
//

import SwiftUI

struct GestionCoursView: View {
    @State private var codeCours: String = ""
    @State private var nomCours: String = ""
    
    // Aligné sur ton script : "BAC1", "BAC2", etc.
    @State private var niveauSelectionne: String = "BAC1"
    @State private var quadrimestreSelectionne: String = "Q1"
    
    @State private var messageStatut: String = ""
    @State private var estUneErreur: Bool = false
    
    let niveauxPossibles = ["BAC1", "BAC2", "BAC3", "M1", "M2"]
    let quadrimestresPossibles = ["Q1", "Q2"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Gestion des Cours")
                    .font(.largeTitle)
                    .bold()
                
                Text("Créez un cours pour alimenter automatiquement votre système de tri OneDrive.")
                    .foregroundColor(.secondary)
                
                Divider()
                
                // --- SECTION PÉRIODE ---
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Niveau d'études")
                            .font(.headline)
                        Picker("", selection: $niveauSelectionne) {
                            ForEach(niveauxPossibles, id: \.self) { niveau in
                                Text(niveau).tag(niveau)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quadrimestre")
                            .font(.headline)
                        Picker("", selection: $quadrimestreSelectionne) {
                            ForEach(quadrimestresPossibles, id: \.self) { quadri in
                                Text(quadri).tag(quadri)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                }
                
                Divider()
                
                // --- SECTION INFOS DU COURS ---
                VStack(alignment: .leading, spacing: 12) {
                    Text("Code du cours (Majuscules automatiques)")
                        .font(.headline)
                    TextField("ex: LEPL1103", text: $codeCours)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 300)
                        .onChange(of: codeCours) { _, newValue in
                            codeCours = newValue.uppercased() // Force les majuscules
                        }
                    
                    Text("Nom du cours")
                        .font(.headline)
                    TextField("ex: Physique", text: $nomCours)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 400)
                }
                
                // Bouton d'action
                Button(action: executionCreationDossiers) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Créer le cours sur le OneDrive")
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(codeCours.isEmpty || nomCours.isEmpty)
                
                // Message de statut
                if !messageStatut.isEmpty {
                    Text(messageStatut)
                        .foregroundColor(estUneErreur ? .red : .green)
                        .padding()
                        .background(estUneErreur ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
    
    // La vraie fonction qui manipule les dossiers du Mac
    func executionCreationDossiers() {
        // 1. Définition du chemin de base (récupéré de ton script)
        let basePath = "/Users/gauthierbaudelet/Library/CloudStorage/OneDrive-UCL/Drive_perso/"
        
        // 2. Construction des noms de dossiers selon tes règles
        let nomDossierCours = "\(codeCours)-\(nomCours)"
        let cheminCompletCours = "\(basePath)\(niveauSelectionne)/\(quadrimestreSelectionne)/\(nomDossierCours)"
        
        let fileManager = FileManager.default
        
        // 3. Liste des sous-dossiers configurés dans ton AppleScript
        let sousDossiers = ["CM", "TP", "Synthèses", "Syllabus", "Devoirs"]
        
        do {
            // Création du dossier principal du cours
            try fileManager.createDirectory(atPath: cheminCompletCours, withIntermediateDirectories: true, attributes: nil)
            
            // Création des sous-dossiers préfixés (ex: LEPL1103-CM)
            for sub in sousDossiers {
                let cheminSousDossier = "\(cheminCompletCours)/\(codeCours)-\(sub)"
                try fileManager.createDirectory(atPath: cheminSousDossier, withIntermediateDirectories: true, attributes: nil)
            }
            
            estUneErreur = false
            messageStatut = "✅ Succès ! Le cours et ses 5 sous-dossiers ont été créés dans \(niveauSelectionne)/\(quadrimestreSelectionne)."
            
            // Réinitialisation des champs pour le prochain cours
            codeCours = ""
            nomCours = ""
            
        } catch {
            estUneErreur = true
            messageStatut = "❌ Erreur lors de la création : \(error.localizedDescription)"
        }
    }
}

#Preview {
    GestionCoursView()
}
