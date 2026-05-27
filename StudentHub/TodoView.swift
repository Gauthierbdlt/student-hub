import SwiftUI
import EventKit

struct TodoView: View {
    @StateObject private var manager = ReminderManager()
    
    // États pour le formulaire d'ajout
    @State private var nouveauRappelTitre = ""
    @State private var coursAssocie: String = "Aucun"
    
    var body: some View {
        HStack(spacing: 0) {
            if manager.isAuthorized {
                // --- COLONNE GAUCHE : Les Listes de Rappels ---
                List(manager.lists, id: \.calendarIdentifier, selection: $manager.selectedList) { list in
                    HStack {
                        Circle()
                            .fill(Color(nsColor: list.color))
                            .frame(width: 10, height: 10)
                        Text(list.title)
                    }
                    .tag(list as EKCalendar?)
                }
                .frame(width: 180)
                .listStyle(SidebarListStyle())
                
                Divider()
                
                // --- COLONNE DROITE : Tâches & Formulaire d'ajout ---
                VStack(alignment: .leading, spacing: 0) {
                    
                    // --- BARRE D'AJOUT DE RAPPEL ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ajouter une tâche").font(.headline)
                        
                        HStack {
                            TextField("Ex: Préparer le laboratoire...", text: $nouveauRappelTitre)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit { ajouterTache() }
                            
                            PickerCoursAssocieView(selection: $coursAssocie)
                                .frame(width: 180)
                            
                            Button(action: ajouterTache) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .disabled(nouveauRappelTitre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // --- LISTE DES RAPPELS ---
                    if manager.reminders.isEmpty {
                        Spacer()
                        HStack { Spacer(); Text("Aucune tâche en cours.").foregroundColor(.secondary).italic(); Spacer() }
                        Spacer()
                    } else {
                        List {
                            ForEach(manager.reminders, id: \.calendarItemIdentifier) { reminder in
                                ReminderRowView(reminder: reminder, manager: manager)
                            }
                        }
                        .listStyle(InsetListStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: manager.selectedList) { _, _ in
                    manager.fetchReminders()
                }
                
            } else {
                Text("En attente d'autorisation des Rappels Apple...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Mes Rappels")
        .onAppear {
            manager.requestAccess()
        }
    }
    
    private func ajouterTache() {
        let texteNettoye = nouveauRappelTitre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texteNettoye.isEmpty else { return }
        
        let codeFiltre = (coursAssocie == "Aucun") ? nil : coursAssocie
        manager.addReminder(title: texteNettoye, codeCours: codeFiltre, dateEcheance: nil)
        
        nouveauRappelTitre = ""
        coursAssocie = "Aucun"
    }
}

// --- SOUS-VUE POUR UNE LIGNE DE RAPPEL ---
struct ReminderRowView: View {
    let reminder: EKReminder
    let manager: ReminderManager // Constante simple, évite les erreurs de type-check de SwiftUI
    
    var body: some View {
        HStack {
            Button(action: {
                manager.toggleReminderCompletion(reminder)
            }) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(reminder.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            Text(reminder.title ?? "Sans titre")
                .strikethrough(reminder.isCompleted)
            
            Spacer()
            
            // Maintenant que la méthode existe dans le manager, ceci va compiler direct !
            if let badge = manager.extraireCodeCours(de: reminder) {
                Text(badge)
                    .font(.caption2).bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 2)
    }
}

// --- SOUS-VUE POUR LE PICKER DES COURS ---
struct PickerCoursAssocieView: View {
    @Binding var selection: String
    
    var listeCodesCours: [String] {
        let cles = DataManager.shared.coursRegroupes.keys
        return Array(cles).sorted()
    }
    
    var body: some View {
        Picker("Lier au cours :", selection: $selection) {
            Text("Aucun").tag("Aucun")
            ForEach(listeCodesCours, id: \.self) { (code: String) in
                Text(code).tag(code)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
}
