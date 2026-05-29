//
//  VueNotesCours.swift
//  StudentHub
//
//  Vue de gestion des notes et calcul de moyenne pour un cours.
//

import SwiftUI

// MARK: - Vue principale

struct VueNotesCours: View {
    let code: String
    let niveau: String
    let quadri: String

    @Environment(AppSettings.self) private var settings
    @State private var store = CourseCreditStore.shared
    @State private var afficherFormulaire = false
    @State private var noteEnEdition: NoteEvaluation? = nil
    @State private var filtreType: TypeEvaluation? = nil

    var notesFiltrees: [NoteEvaluation] {
        let liste = store.notesFor(code)
        if let f = filtreType { return liste.filter { $0.type == f } }
        return liste
    }

    var moyenneInfo: MoyenneCours { store.moyennePour(code) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header avec moyenne ──────────────────────────────────────
            headerMoyenne
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // ── Barre d'outils ───────────────────────────────────────────
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filtreChip(label: "Toutes", actif: filtreType == nil) {
                            filtreType = nil
                        }
                        ForEach(TypeEvaluation.allCases) { type in
                            let nb = store.notesFor(code).filter { $0.type == type }.count
                            if nb > 0 {
                                filtreChip(label: "\(type.rawValue) (\(nb))",
                                           actif: filtreType == type) {
                                    filtreType = (filtreType == type) ? nil : type
                                }
                            }
                        }
                    }
                }
                Spacer()
                Button {
                    noteEnEdition = nil
                    afficherFormulaire = true
                } label: {
                    Label("Ajouter une note", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // ── Liste des notes ──────────────────────────────────────────
            if notesFiltrees.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Aucune note enregistrée")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Ajoutez vos résultats pour calculer votre moyenne.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Button("Ajouter une note") {
                        noteEnEdition = nil
                        afficherFormulaire = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(notesFiltrees.sorted(by: { $0.date > $1.date })) { note in
                        LigneNote(note: note, store: store, code: code) {
                            noteEnEdition = note
                            afficherFormulaire = true
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $afficherFormulaire) {
            FormulaireNoteView(
                code: code,
                store: store,
                noteExistante: noteEnEdition
            )
        }
    }

    // MARK: - Header moyenne

    @ViewBuilder
    private var headerMoyenne: some View {
        let info = moyenneInfo
        HStack(alignment: .top, spacing: 20) {
            // Jauge circulaire
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                    .frame(width: 72, height: 72)
                if let moy = info.moyenne {
                    Circle()
                        .trim(from: 0, to: min(moy / 20.0, 1.0))
                        .stroke(
                            couleurMention(info.mentionCouleur),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                        .animation(.easeInOut(duration: 0.5), value: moy)
                    VStack(spacing: 1) {
                        Text(String(format: "%.1f", moy))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("/20")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "minus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Moyenne")
                        .font(.title3.bold())
                    if let moy = info.moyenne {
                        Text(info.mentionTexte)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(couleurMention(info.mentionCouleur).opacity(0.15))
                            .foregroundStyle(couleurMention(info.mentionCouleur))
                            .clipShape(Capsule())
                        let _ = moy  // silence warning
                    }
                }

                // Barre pondérations
                if info.nbNotes > 0 {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Pondérations couvertes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", info.pondsTotal * 100))
                                .font(.caption.bold())
                                .foregroundStyle(info.estValide ? .green : .orange)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.15))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(info.estValide ? Color.green : Color.orange)
                                    .frame(width: geo.size.width * min(info.pondsTotal, 1.0))
                                    .animation(.easeInOut, value: info.pondsTotal)
                            }
                        }
                        .frame(height: 6)

                        if !info.estValide && info.nbNotes > 0 {
                            Text("⚠️ Les pondérations ne totalisent pas 100% — moyenne partielle")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Text("\(info.nbNotes) évaluation(s) enregistrée(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func filtreChip(label: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(actif ? settings.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(actif ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func couleurMention(_ nom: String) -> Color {
        switch nom {
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .secondary
        }
    }
}

// MARK: - Ligne note

struct LigneNote: View {
    let note: NoteEvaluation
    let store: CourseCreditStore
    let code: String
    let onEdit: () -> Void

    @Environment(AppSettings.self) private var settings

    var couleurType: Color {
        switch note.type {
        case .examen:  return .red
        case .partiel: return .orange
        case .labo:    return .green
        case .devoir:  return .blue
        case .projet:  return .purple
        case .oral:    return .pink
        case .autre:   return .gray
        }
    }

    var noteFormatee: String {
        let n = note.note.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", note.note) : String(format: "%.1f", note.note)
        let s = note.noteSur.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", note.noteSur) : String(format: "%.1f", note.noteSur)
        return "\(n)/\(s)"
    }

    var sur20Formate: String {
        String(format: "%.2f/20", note.noteSur20)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Pastille type
            Image(systemName: note.type.icon)
                .font(.title3)
                .foregroundStyle(couleurType)
                .frame(width: 36, height: 36)
                .background(couleurType.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(note.titre)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text(note.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(couleurType.opacity(0.1))
                        .foregroundStyle(couleurType)
                        .clipShape(Capsule())
                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !note.commentaire.isEmpty {
                        Label(note.commentaire, systemImage: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Notes
            VStack(alignment: .trailing, spacing: 2) {
                Text(noteFormatee)
                    .font(.headline.bold())
                Text(sur20Formate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("× \(Int(note.ponderation * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Actions
            HStack(spacing: 6) {
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Modifier")

                Button {
                    store.supprimerNote(id: note.id, pourCours: code)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Supprimer")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formulaire ajout/édition note

struct FormulaireNoteView: View {
    @Environment(\.dismiss) private var dismiss
    let code: String
    let store: CourseCreditStore
    let noteExistante: NoteEvaluation?

    @State private var titre = ""
    @State private var type: TypeEvaluation = .examen
    @State private var noteTexte = ""
    @State private var noteSurTexte = "20"
    @State private var ponderationTexte = ""
    @State private var date = Date()
    @State private var commentaire = ""
    @State private var erreur = ""

    private var noteVal: Double { Double(noteTexte.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var noteSurVal: Double { Double(noteSurTexte.replacingOccurrences(of: ",", with: ".")) ?? 20 }
    private var ponderationVal: Double { (Double(ponderationTexte.replacingOccurrences(of: ",", with: ".")) ?? 0) / 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(noteExistante == nil ? "Ajouter une évaluation" : "Modifier l'évaluation")
                    .font(.title2.bold())
                Spacer()
                Button("Annuler") { dismiss() }
                Button("Enregistrer") { sauvegarder() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!peutSauvegarder)
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Titre
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Titre de l'évaluation").font(.headline)
                        TextField("ex : Examen de janvier, Labo 3…", text: $titre)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                            ForEach(TypeEvaluation.allCases) { t in
                                Button { type = t } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: t.icon)
                                        Text(t.rawValue)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(type == t ? couleurType(t) : Color.secondary.opacity(0.08))
                                    .foregroundStyle(type == t ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Note
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note obtenue").font(.headline)
                            HStack(spacing: 6) {
                                TextField("ex: 14.5", text: $noteTexte)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("/")
                                    .foregroundStyle(.secondary)
                                TextField("20", text: $noteSurTexte)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pondération").font(.headline)
                            HStack(spacing: 6) {
                                TextField("ex: 40", text: $ponderationTexte)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            Text("Poids de cette note dans la moyenne finale.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Aperçu /20
                    if !noteTexte.isEmpty && !noteSurTexte.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "equal.circle.fill")
                                .foregroundStyle(.blue)
                            Text(String(format: "%.2f / 20", noteSurVal > 0 ? (noteVal / noteSurVal) * 20 : 0))
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                            Text("(ramené sur 20)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date").font(.headline)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    // Commentaire
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Commentaire (optionnel)").font(.headline)
                        TextEditor(text: $commentaire)
                            .frame(height: 60)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    }

                    // Erreur
                    if !erreur.isEmpty {
                        Label(erreur, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 580)
        .onAppear { initialiser() }
    }

    private var peutSauvegarder: Bool {
        !titre.trimmingCharacters(in: .whitespaces).isEmpty
        && noteVal >= 0
        && noteSurVal > 0
        && ponderationVal > 0
    }

    private func initialiser() {
        guard let n = noteExistante else { return }
        titre = n.titre
        type = n.type
        noteTexte = String(format: n.note.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", n.note)
        noteSurTexte = String(format: n.noteSur.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", n.noteSur)
        ponderationTexte = String(format: "%.0f", n.ponderation * 100)
        date = n.date
        commentaire = n.commentaire
    }

    private func sauvegarder() {
        guard noteSurVal > 0 else { erreur = "La base de la note doit être > 0."; return }
        guard ponderationVal > 0 else { erreur = "La pondération doit être > 0%."; return }

        let nouvelle = NoteEvaluation(
            id: noteExistante?.id ?? UUID(),
            titre: titre.trimmingCharacters(in: .whitespaces),
            type: type,
            note: noteVal,
            noteSur: noteSurVal,
            ponderation: ponderationVal,
            date: date,
            commentaire: commentaire
        )
        if noteExistante != nil {
            store.modifierNote(nouvelle, pourCours: code)
        } else {
            store.ajouterNote(nouvelle, pourCours: code)
        }
        dismiss()
    }

    private func couleurType(_ t: TypeEvaluation) -> Color {
        switch t {
        case .examen:  return .red
        case .partiel: return .orange
        case .labo:    return .green
        case .devoir:  return .blue
        case .projet:  return .purple
        case .oral:    return .pink
        case .autre:   return .gray
        }
    }
}

#Preview {
    VueNotesCours(code: "LEPL1106", niveau: "BAC1", quadri: "Q1")
        .environment(AppSettings())
        .frame(width: 700, height: 500)
}
