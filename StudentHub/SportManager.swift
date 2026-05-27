import Foundation
import SwiftUI
import Combine
import AuthenticationServices

// --- MODÈLE POUR L'ÉVOLUTION ET LES GRAPHIQUES (PROVIENT DE STRAVA) ---
struct SportStat: Identifiable, Codable {
    let id: String              // ID de l'activité Strava
    var titre: String
    var date: Date
    var typeSport: String       // Course, Vélo, Natation, etc.
    var distance: Double        // En kilomètres
    var duree: TimeInterval     // En secondes
    var vitesseMoyenne: Double  // Reçu de Strava (converti en km/h)
    
    // Allure calculée pour la course à pied (MM:SS min/km)
    var allureMoyenne: String {
        guard distance > 0 else { return "0:00" }
        let tempsParKm = duree / distance
        let minutes = Int(tempsParKm) / 60
        let secondes = Int(tempsParKm) % 60
        return String(format: "%d:%02d", minutes, secondes)
    }
}

// --- MODÈLES DE DÉCODAGE REÇUS DE L'API STRAVA ---
struct StravaActivitySummary: Codable {
    let id: Int64
    let name: String
    let distance: Double         // en mètres
    let moving_time: Double      // en secondes
    let type: String             // "Run", "Ride", etc.
    let start_date_local: String // Chaîne au format ISO8601
    let average_speed: Double    // en m/s
}

// --- MODÈLE POUR LE FUTUR PLANIFIÉ (PROVIENT DE GARMIN .ICS) ---
struct GarminFuturEvent: Identifiable, Codable {
    var id: String              // UID du fichier .ics
    var titre: String
    var dateDebut: Date
    var description: String?
}

class SportManager: ObservableObject {
    @Published var entrainementsFuturs: [GarminFuturEvent] = []
    @Published var historiqueStrava: [SportStat] = []
    @Published var estEnTrainDeConnecter = false
    
    // =================================================================
    // CONFIGURATION : REMPLACE ICI PAR TES PARAMÈTRES DE DEV STRAVA
    // =================================================================
    private let clientId = "251443"       // <--- Colle ton Client ID ici
    private let clientSecret = "2ecf53ff9f0bfe24d95b16f17c8404ed9ed7e94d" // <--- Colle ton Client Secret ici
    private let redirectUri = "studenthub://auth"
    
    init() {
        chargerDonnees()
    }
    
    // ==========================================
    // AUTHENTIFICATION OAUTH2 STRAVA (macOS)
    // ==========================================
    @MainActor
    func authentifierEtSynchroniserStrava() {
        // Utilise un schéma simple pour le redirect_uri
        let redirectUri = "studenthub://auth"
        let urlString = "https://www.strava.com/oauth/authorize?client_id=\(clientId)&redirect_uri=\(redirectUri)&response_type=code&scope=activity:read_all"
        
        guard let authURL = URL(string: urlString) else { return }
        
        self.estEnTrainDeConnecter = true
        
        // Le callbackURLScheme doit correspondre à la partie avant le "://"
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "studenthub"
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Erreur d'authentification ou annulation : \(error.localizedDescription)")
                self.estEnTrainDeConnecter = false
                return
            }
            
            guard let successURL = callbackURL,
                  let components = URLComponents(url: successURL, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                self.estEnTrainDeConnecter = false
                return
            }
            
            // Échange du code temporaire contre le Token d'accès final
            Task {
                await self.echangerCodeContreToken(code: code)
            }
        }
        
        // Indispensable sur macOS pour ancrer le pop-up Web sur l'application
        session.presentationContextProvider = NSApplication.shared.delegate as? ASWebAuthenticationPresentationContextProviding
            session.start()
        }
    
    // Requête HTTP POST pour obtenir le Token d'accès
    private func echangerCodeContreToken(code: String) async {
        guard let url = URL(string: "https://www.strava.com/oauth/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let corpsParametres: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: corpsParametres)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                // Téléchargement immédiat de tes statistiques
                await telechargerActivitesStrava(token: accessToken)
            }
        } catch {
            print("Erreur lors de l'échange de jeton : \(error.localizedDescription)")
            await MainActor.run { self.estEnTrainDeConnecter = false }
        }
    }
    
    // Téléchargement effectif des 30 dernières activités de ton profil
    private func telechargerActivitesStrava(token: String) async {
        guard let url = URL(string: "https://www.strava.com/api/v3/athlete/activities?per_page=30") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            let decoder = JSONDecoder()
            let activitesRecues = try decoder.decode([StravaActivitySummary].self, from: data)
            
            let dateFormatter = ISO8601DateFormatter()
            
            await MainActor.run {
                for act in activitesRecues {
                    let dateActivite = dateFormatter.date(from: act.start_date_local) ?? Date()
                    
                    self.ajouterActiviteStrava(
                        id: String(act.id),
                        titre: act.name,
                        date: dateActivite,
                        type: act.type,
                        distanceMetres: act.distance,
                        tempsSecondes: act.moving_time,
                        vitesseMoyenneMetresSeconde: act.average_speed
                    )
                }
                self.estEnTrainDeConnecter = false
            }
            
        } catch {
            print("Erreur lors de la récupération des activités Strava : \(error.localizedDescription)")
            await MainActor.run { self.estEnTrainDeConnecter = false }
        }
    }
    
    // ==========================================
    // 1. LE FUTUR : PARSAGE ET RECRÉATION DU .ICS
    // ==========================================
    func importerFichierICS(url: URL) {
        do {
            let contenu = try String(contentsOf: url, encoding: .utf8)
            var nouveauxFuturs: [GarminFuturEvent] = []
            let evenementsBruts = contenu.components(separatedBy: "BEGIN:VEVENT")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let maintenant = Date()
            
            for bloc in evenementsBruts {
                if bloc.contains("END:VEVENT") {
                    var titre = "Entraînement Planifié"
                    var dateDebut = Date()
                    var uid = UUID().uuidString
                    var description = ""
                    
                    let lignes = bloc.components(separatedBy: .newlines)
                    for ligne in lignes {
                        if ligne.hasPrefix("SUMMARY:") {
                            titre = ligne.replacingOccurrences(of: "SUMMARY:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if ligne.hasPrefix("DTSTART:") {
                            let dateStr = ligne.replacingOccurrences(of: "DTSTART:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if let indexZ = dateStr.firstIndex(of: "Z") {
                                let sousDate = String(dateStr[...indexZ])
                                if let dateCalculee = dateFormatter.date(from: sousDate) {
                                    dateDebut = dateCalculee
                                }
                            }
                        } else if ligne.hasPrefix("UID:") {
                            uid = ligne.replacingOccurrences(of: "UID:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if ligne.hasPrefix("DESCRIPTION:") {
                            description = ligne.replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    
                    if dateDebut >= maintenant {
                        let futurEvt = GarminFuturEvent(id: uid, titre: titre, dateDebut: dateDebut, description: description)
                        nouveauxFuturs.append(futurEvt)
                    }
                }
            }
            
            self.entrainementsFuturs = nouveauxFuturs.sorted(by: { $0.dateDebut < $1.dateDebut })
            sauvegarderDonnees()
            
        } catch {
            print("Erreur lecture .ics : \(error.localizedDescription)")
        }
    }
    
    // ==========================================
    // 2. LE PASSÉ : ENREGISTREMENT DES DONNÉES STRAVA
    // ==========================================
    func ajouterActiviteStrava(id: String, titre: String, date: Date, type: String, distanceMetres: Double, tempsSecondes: Double, vitesseMoyenneMetresSeconde: Double) {
        let distanceKm = distanceMetres / 1000.0
        let vitesseKmH = vitesseMoyenneMetresSeconde * 3.6
        
        guard !historiqueStrava.contains(where: { $0.id == id }) else { return }
        
        let nouvelleStat = SportStat(
            id: id,
            titre: titre,
            date: date,
            typeSport: type,
            distance: distanceKm,
            duree: tempsSecondes,
            vitesseMoyenne: vitesseKmH
        )
        
        self.historiqueStrava.append(nouvelleStat)
        self.historiqueStrava.sort(by: { $0.date < $1.date })
        sauvegarderDonnees()
    }
    
    // ==========================================
    // 3. PERSISTENCE LOCALES (USERDEFAULTS)
    // ==========================================
    private func sauvegarderDonnees() {
        if let encodedFutur = try? JSONEncoder().encode(entrainementsFuturs) {
            UserDefaults.standard.set(encodedFutur, forKey: "sport_entrainements_futurs")
        }
        if let encodedStrava = try? JSONEncoder().encode(historiqueStrava) {
            UserDefaults.standard.set(encodedStrava, forKey: "sport_historique_strava")
        }
    }
    
    private func chargerDonnees() {
        if let dataFutur = UserDefaults.standard.data(forKey: "sport_entrainements_futurs"),
           let decodedFutur = try? JSONDecoder().decode([GarminFuturEvent].self, from: dataFutur) {
            self.entrainementsFuturs = decodedFutur
        }
        
        if let dataStrava = UserDefaults.standard.data(forKey: "sport_historique_strava"),
           let decodedStrava = try? JSONDecoder().decode([SportStat].self, from: dataStrava) {
            self.historiqueStrava = decodedStrava
        } else {
            let baseDate = Date()
            self.historiqueStrava = [
                SportStat(id: "1", titre: "Course Paris", date: baseDate.addingTimeInterval(-86400 * 20), typeSport: "Run", distance: 8.0, duree: 2880, vitesseMoyenne: 10.0),
                SportStat(id: "2", titre: "Seuil 4x1000", date: baseDate.addingTimeInterval(-86400 * 12), typeSport: "Run", distance: 9.5, duree: 3200, vitesseMoyenne: 10.68),
                SportStat(id: "3", titre: "Sortie Dominicale", date: baseDate.addingTimeInterval(-86400 * 4), typeSport: "Run", distance: 12.0, duree: 3850, vitesseMoyenne: 11.22)
            ].sorted(by: { $0.date < $1.date })
        }
    }
}
