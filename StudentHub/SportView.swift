import SwiftUI
import Charts
import EventKit
import UniformTypeIdentifiers

struct SportView: View {
    @StateObject private var manager = SportManager()
    @State private var montrantSélecteurFichier = false
    @State private var typeGraphiqueSelectionne = "Vitesse" // "Vitesse" ou "Distance"
    
    var body: some View {
        HStack(spacing: 0) {
            // ==========================================
            // COLONNE GAUCHE : ACTIONS & CALENDRIER FUTUR
            // ==========================================
            VStack(alignment: .leading, spacing: 16) {
                Text("Mon Espace Sport")
                    .font(.title).bold()
                
                // BOUTONS DE CONNEXION / IMPORT
                VStack(spacing: 10) {
                    // Connexion Strava
                    Button(action: connecterStrava) {
                        HStack {
                            if manager.estEnTrainDeConnecter {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            }
                            Text(manager.estEnTrainDeConnecter ? "Connexion en cours..." : "Synchroniser Strava (Passé)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange) // Couleur officielle Strava
                    .disabled(manager.estEnTrainDeConnecter)
                    
                    // Import Garmin .ics
                    Button(action: { montrantSélecteurFichier = true }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up.fill")
                            Text("Uploader Garmin .ics (Futur)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // LISTE DES ENTRAÎNEMENTS FUTURS (GARMIN)
                Text("Entraînements planifiés")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if manager.entrainementsFuturs.isEmpty {
                    VStack {
                        Spacer()
                        Text("Aucune séance future.\nImporte un fichier .ics pour mettre à jour.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .italic()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(manager.entrainementsFuturs) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.titre)
                                .font(.subheadline).bold()
                            HStack {
                                Image(systemName: "calendar")
                                Text(event.dateDebut.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            if let desc = event.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(SidebarListStyle())
                    .cornerRadius(8)
                }
            }
            .padding()
            .frame(width: 280)
            
            Divider()
            
            // ==========================================
            // COLONNE DROITE : GRAPHIQUES D'ÉVOLUTION (STRAVA)
            // ==========================================
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Évolution des performances")
                        .font(.title2).bold()
                    Spacer()
                    
                    Picker("Métrique", selection: $typeGraphiqueSelectionne) {
                        Text("Vitesse Moyenne").tag("Vitesse")
                        Text("Distance").tag("Distance")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 250)
                }
                
                // ZONE DU GRAPHIQUE SWIFT CHARTS
                if manager.historiqueStrava.isEmpty {
                    Text("Aucune donnée Strava synchronisée pour le moment.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if typeGraphiqueSelectionne == "Vitesse" {
                            Text("Vitesse Moyenne au fil des séances (km/h)")
                                .font(.subheadline).foregroundColor(.secondary)
                            
                            Chart(manager.historiqueStrava) { stat in
                                LineMark(
                                    x: .value("Date", stat.date),
                                    y: .value("Vitesse (km/h)", stat.vitesseMoyenne)
                                )
                                .interpolationMethod(.catmullRom) // Arrondit la courbe pour un effet fluide
                                .foregroundStyle(.orange)
                                .symbol(Circle())
                            }
                            .frame(height: 250)
                            
                        } else {
                            Text("Volume kilométrique par sortie (km)")
                                .font(.subheadline).foregroundColor(.secondary)
                            
                            Chart(manager.historiqueStrava) { stat in
                                BarMark(
                                    x: .value("Date", stat.date),
                                    y: .value("Distance (km)", stat.distance)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .frame(height: 250)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                // DERNIÈRES ACTIVITÉS RÉALISÉES
                Text("Dernières activités (Strava)")
                    .font(.headline)
                
                List(manager.historiqueStrava.reversed()) { stat in
                    HStack {
                        Image(systemName: stat.typeSport == "Run" ? "figure.run" : "figure.outdoor.cycle")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(stat.titre)
                                .font(.subheadline).bold()
                            Text(stat.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(String(format: "%.2f km", stat.distance))
                                .font(.subheadline).bold()
                            Text(String(format: "%.1f km/h", stat.vitesseMoyenne))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(InsetListStyle())
            }
            .padding()
        }
        // Gestionnaire d'importation de fichier natif Mac (.ics)
        .fileImporter(
            isPresented: $montrantSélecteurFichier,
            allowedContentTypes: [UTType(tag: "ics", tagClass: .filenameExtension, conformingTo: nil) ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        manager.importerFichierICS(url: url)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                print("Erreur sélection fichier : \(error.localizedDescription)")
            }
        }
    }
    
    // Action de connexion principale connectée au SportManager
    private func connecterStrava() {
        print("Lancement de la connexion Strava via OAuth2...")
        manager.authentifierEtSynchroniserStrava()
    }
}
