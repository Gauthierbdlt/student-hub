import Foundation
import EventKit
import Observation

@Observable
class DataManager {
    static let shared = DataManager()
    
    // Le cache en mémoire (vide à chaque lancement)
    var cacheFichiers: [String: [StatutTP]] = [:]
    
    // Dans ton DataManager
    init() {
        // On lance la synchro sans bloquer l'interface
        Task {
            await demanderAccesEtSynchroniser()
        }
    }
    
    var listeCours: [ÉvénementCours] = []
    var messageStatut: String = "Prêt 🗓️"
    
    private let eventStore = EKEventStore()
    
    // Regroupement automatique par Code Cours
    var coursRegroupes: [String: [ÉvénementCours]] {
        Dictionary(grouping: listeCours.filter { $0.typeGlobal == "COURS_GENERAL" }) { $0.code }
    }
    
    func obtenirFichiers(niveau: String, quadri: String, code: String) -> [StatutTP] {
            // Si on a déjà scanné ce cours, on renvoie le résultat stocké
            if let fichiers = cacheFichiers[code] {
                return fichiers
            }
            
            // Sinon, on scanne (cette partie ne s'exécute qu'une fois par session)
            let resultats = GestionnaireFichiers.analyserContenu(
                niveau: niveau,
                quadri: quadri,
                code: code,
                type: "TP",
                jusqua: 10
            )
            
            // On stocke dans le cache pour les prochains accès
            cacheFichiers[code] = resultats
            return resultats
        }
    
    func demanderAccesEtSynchroniser() async {
        do {
            let accorde: Bool
            if #available(macOS 14.0, *) {
                accorde = try await eventStore.requestFullAccessToEvents()
            } else {
                accorde = try await eventStore.requestAccess(to: .event)
            }
            
            if accorde {
                await chargerEvenements()
            } else {
                await MainActor.run { self.messageStatut = "❌ Accès refusé." }
            }
        } catch {
            await MainActor.run { self.messageStatut = "❌ Erreur : \(error.localizedDescription)" }
        }
    }
    
    private func chargerEvenements() async {
        let dateDebut = Date()
        let dateFin = Calendar.current.date(byAdding: .day, value: 60, to: dateDebut)!
        
        let predicat = eventStore.predicateForEvents(withStart: dateDebut, end: dateFin, calendars: nil)
        let evenementsMac = eventStore.events(matching: predicat)
        
        var temporaireList: [ÉvénementCours] = []
        let calendriersCibles = ["travail", "scout", "domicile"]
        let calendriersBannis = ["jours fériés", "birthdays", "anniversaires", "holidays"]
        
        for event in evenementsMac {
            let titre = event.title ?? "Sans titre"
            let nomCal = event.calendar.title
            let nomCalMinuscule = nomCal.lowercased()
            
            if calendriersBannis.contains(where: { nomCalMinuscule.contains($0) }) { continue }
            
            let estUnAgendaPerso = calendriersCibles.contains(where: { nomCalMinuscule.contains($0) })
            var typeFinal = "COURS_GENERAL"
            
            if estUnAgendaPerso {
                if nomCalMinuscule.contains("travail") { typeFinal = "TRAVAIL" }
                else if nomCalMinuscule.contains("scout") { typeFinal = "SCOUT" }
                else if nomCalMinuscule.contains("domicile") { typeFinal = "DOMICILE" }
            }
            
            var codeCours = "AUTRE"
            if typeFinal == "COURS_GENERAL" {
                let tousLesMots = (titre + " " + (event.notes ?? "")).components(separatedBy: CharacterSet(charactersIn: " := '()•,\n"))
                if let codeTrouve = tousLesMots.first(where: { $0.count >= 4 && $0.contains(where: { $0.isNumber }) }) {
                    let composantsSpeciaux = codeTrouve.components(separatedBy: "=")
                    codeCours = composantsSpeciaux.first?.uppercased() ?? codeTrouve.uppercased()
                } else {
                    codeCours = "GÉNÉRAL"
                }
            }
            
            let nouvelElement = ÉvénementCours(
                id: event.eventIdentifier,
                code: codeCours,
                titre: titre,
                typeGlobal: typeFinal,
                dateDebut: event.startDate,
                dateFin: event.endDate,
                emplacement: event.location ?? "",
                nomCalendrier: nomCal
            )
            
            temporaireList.append(nouvelElement)
        }
        
        await MainActor.run {
            self.listeCours = temporaireList.sorted(by: { $0.dateDebut < $1.dateDebut })
            self.messageStatut = "✅ Synchronisé."
        }
    }
}
