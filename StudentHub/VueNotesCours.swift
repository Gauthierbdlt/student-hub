import SwiftUI

struct VueNotesCours: View {
    let code: String
    @State private var notes: [NoteCours] = []
    @State private var nouveauTexte: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("Notes personnelles").font(.headline)
            
            List {
                ForEach(notes) { note in
                    Text(note.texte)
                        .padding(.vertical, 4)
                }
            }
            .frame(height: 200)
            
            HStack {
                TextField("Nouvelle note...", text: $nouveauTexte)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Ajouter") {
                    let nouvelleNote = NoteCours(texte: nouveauTexte, dateCreation: Date())
                    notes.append(nouvelleNote)
                    // La sauvegarde sera déclenchée automatiquement par le onChange
                    nouveauTexte = ""
                }
                .disabled(nouveauTexte.isEmpty)
            }
        }
        .onAppear {
            // Chargement initial
            self.notes = NoteManager.chargerNotes(pour: code)
        }
        // Correction ici pour Xcode récent :
        .onChange(of: notes) { oldVal, newVal in
            NoteManager.sauvegarderNotes(pour: code, notes: newVal)
        }
    }
}
