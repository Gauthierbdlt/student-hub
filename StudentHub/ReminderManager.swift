import Foundation
import Combine
import EventKit

class ReminderManager: ObservableObject {
    private let eventStore = EKEventStore()
    
    @Published var reminders: [EKReminder] = []
    @Published var lists: [EKCalendar] = []
    @Published var selectedList: EKCalendar?
    @Published var isAuthorized = false
    
    func requestAccess() {
        // Demande d'accès aux Rappels et aux Événements (Calendrier)
        eventStore.requestFullAccessToReminders { grantedReminders, _ in
            if grantedReminders {
                self.eventStore.requestWriteOnlyAccessToEvents { grantedEvents, _ in
                    DispatchQueue.main.async {
                        self.isAuthorized = grantedReminders
                        if grantedReminders {
                            self.fetchLists()
                        }
                    }
                }
            }
        }
    }
    
    func fetchLists() {
        let allLists = eventStore.calendars(for: .reminder)
        DispatchQueue.main.async {
            self.lists = allLists
            if self.selectedList == nil {
                self.selectedList = allLists.first
            }
            self.fetchReminders()
        }
    }
    
    func fetchReminders() {
        guard let currentList = selectedList else { return }
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [currentList])
        
        eventStore.fetchReminders(matching: predicate) { ekReminders in
            DispatchQueue.main.async {
                self.reminders = ekReminders ?? []
            }
        }
    }
    
    // --- CRÉATION AVEC LIEN COURS + SYNCHRO AGENDA SATIONNAIRE ---
    // --- DANS REMINDERMANAGER.SWIFT ---

    func addReminder(title: String, codeCours: String? = nil, dateEcheance: Date? = nil) {
        guard let currentList = selectedList else { return }
        
        let newReminder = EKReminder(eventStore: eventStore)
        newReminder.title = title
        newReminder.calendar = currentList
        
        // Dépliage sécurisé du code de cours pour éviter l'avertissement d'optionalité
        if let code = codeCours, !code.isEmpty {
            newReminder.notes = "[COURS:\(code)]"
        }
        
        if let echeance = dateEcheance {
            let calendar = Calendar.current
            newReminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: echeance)
            
            let newEvent = EKEvent(eventStore: eventStore)
            
            // Dépliage ici aussi pour construire un titre propre sans "Optional(...)"
            if let code = codeCours, !code.isEmpty {
                newEvent.title = "🔔 [\(code)] \(title)"
                newEvent.notes = "Généré automatiquement depuis ton StudentHub pour le cours \(code)."
            } else {
                newEvent.title = "🔔 \(title)"
                newEvent.notes = "Généré automatiquement depuis ton StudentHub."
            }
            
            newEvent.startDate = echeance
            newEvent.endDate = echeance.addingTimeInterval(1800)
            newEvent.calendar = eventStore.defaultCalendarForNewEvents
            
            try? eventStore.save(newEvent, span: .thisEvent, commit: false)
        }
        
        do {
            try eventStore.save(newReminder, commit: true)
            fetchReminders()
        } catch {
            print("Erreur écriture Rappel : \(error.localizedDescription)")
        }
    }
    
    func toggleReminderCompletion(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        try? eventStore.save(reminder, commit: true)
        fetchReminders()
    }
    
    // Filtrer les rappels en mémoire pour un cours spécifique
    func reminders(for codeCours: String) -> [EKReminder] {
        return reminders.filter { reminder in
            guard let notes = reminder.notes else { return false }
            return notes.contains("[COURS:\(codeCours)]")
        }
    }
    
    // À AJOUTER DANS LE FICHIER ReminderManager.swift (à la fin de la classe)
    func extraireCodeCours(de reminder: EKReminder) -> String? {
        guard let notes = reminder.notes else { return nil }
        // Si la note contient [COURS:LEPL1106], on extrait "LEPL1106"
        if notes.contains("[COURS:") {
            let composants = notes.components(separatedBy: "[COURS:")
            if composants.count > 1 {
                let suite = composants[1]
                if let finCrochet = suite.firstIndex(of: "]") {
                    return String(suite[..<finCrochet])
                }
            }
        }
        return nil
    }
}
