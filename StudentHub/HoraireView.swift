import SwiftUI

struct HoraireView: View {
    // Utilisation d'une référence directe sans State pour éviter le bug de Binding
    let dataManager = DataManager.shared
    
    @State private var filtrePrincipal: String = "Tout"
    let optionsPrincipales = ["Tout", "Travail", "Domicile", "Scout"]
    
    @State private var filtreCours: String = "Tous les cours"
    let optionsCours = ["Tous les cours", "CM", "TP", "EXAM"]
    
    var evenementsFiltres: [ÉvénementCours] {
        var resultat = dataManager.listeCours
        
        if filtrePrincipal != "Tout" {
            if filtrePrincipal == "Travail" {
                resultat = resultat.filter { $0.typeGlobal == "COURS_GENERAL" || $0.typeGlobal == "TRAVAIL" }
            } else {
                resultat = resultat.filter { $0.typeGlobal == filtrePrincipal.uppercased() }
            }
        }
        
        if filtrePrincipal == "Travail" && filtreCours != "Tous les cours" {
            resultat = resultat.filter { cours in
                let titreMaj = cours.titre.uppercased()
                if filtreCours == "EXAM" {
                    return titreMaj.contains("EXAM") || titreMaj.contains("EXAMEN") || titreMaj.contains("ÉCHÉANCE")
                } else if filtreCours == "CM" {
                    return titreMaj.contains("CM") || titreMaj.contains("COURS MAGISTRAL")
                } else if filtreCours == "TP" {
                    return titreMaj.contains("TP") || titreMaj.contains("TRAVAUX PRATIQUES")
                }
                return true
            }
        }
        
        return resultat
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mon Horaire & Activités")
                .font(.largeTitle)
                .bold()
            
            HStack(spacing: 20) {
                Button(action: {
                    Task { await dataManager.demanderAccesEtSynchroniser() }
                }) {
                    Label("Mettre à jour l'agenda", systemImage: "arrow.triangle.2.circlepath")
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                
                Text(dataManager.messageStatut)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Catégorie")
                        .font(.caption).foregroundColor(.secondary).bold()
                    Picker("", selection: $filtrePrincipal) {
                        ForEach(optionsPrincipales, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).frame(width: 150)
                }
                
                if filtrePrincipal == "Travail" {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Type de cours")
                            .font(.caption).foregroundColor(.secondary).bold()
                        Picker("", selection: $filtreCours) {
                            ForEach(optionsCours, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu).frame(width: 150)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(.vertical, 5)
            
            Divider()
            
            if evenementsFiltres.isEmpty {
                ContentUnavailableView("Aucun événement", systemImage: "calendar.badge.clock")
            } else {
                List(evenementsFiltres) { cours in
                    HStack(spacing: 15) {
                        Rectangle()
                            .fill(couleurParDefaut(cours.titre, typeGlobal: cours.typeGlobal))
                            .frame(width: 5).cornerRadius(2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cours.titre).font(.headline)
                            HStack {
                                if !cours.code.isEmpty && cours.code != "AUTRE" {
                                    Text("[\(cours.code)]").bold().foregroundColor(.blue)
                                }
                                if !cours.emplacement.isEmpty {
                                    Label(cours.emplacement, systemImage: "mappin.and.ellipse")
                                }
                            }
                            .font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(badgeTexte(cours.titre, typeGlobal: cours.typeGlobal))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(couleurParDefaut(cours.titre, typeGlobal: cours.typeGlobal).opacity(0.15))
                                .foregroundColor(couleurParDefaut(cours.titre, typeGlobal: cours.typeGlobal))
                                .cornerRadius(6).font(.caption).bold()
                            
                            Text(cours.dateDebut.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(30)
        .animation(.easeInOut, value: filtrePrincipal)
        .animation(.easeInOut, value: filtreCours)
    }
    
    func badgeTexte(_ titre: String, typeGlobal: String) -> String {
        let titreMaj = titre.uppercased()
        if titreMaj.contains("EXAM") || titreMaj.contains("EXAMEN") { return "EXAM" }
        if titreMaj.contains("CM") { return "CM" }
        if titreMaj.contains("TP") { return "TP" }
        return typeGlobal
    }
    
    func couleurParDefaut(_ titre: String, typeGlobal: String) -> Color {
        let titreMaj = titre.uppercased()
        if titreMaj.contains("EXAM") || titreMaj.contains("EXAMEN") { return .red }
        if titreMaj.contains("CM") { return .orange }
        if titreMaj.contains("TP") { return .green }
        
        switch typeGlobal {
        case "SCOUT": return .purple
        case "TRAVAIL": return .blue
        case "DOMICILE": return .cyan
        default: return .gray
        }
    }
}
