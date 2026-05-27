//
//  GestionCoursView.swift
//  StudentHub
//

import SwiftUI
import EventKit

// MARK: - Modèles

struct NoteCours: Identifiable, Codable, Equatable {
    var id = UUID()
    var texte: String
    var dateCreation: Date
}

struct EvenementPerso: Identifiable, Codable {
    var id = UUID()
    var titre: String
    var type: String
    var date: Date
    var notes: String = ""
    var ekEventID: String?
}

// MARK: - Générateur dossiers

struct GenerateurDossiers {
    static let basePath = "/Users/gauthierbaudelet/Library/CloudStorage/OneDrive-UCL/Drive_perso/"

    func creerArborescence(code: String, nom: String, niveau: String, quadri: String) -> (estUnSucces: Bool, message: String) {
        let nomDossierCours = "\(code)-\(nom)"
        let cheminCompletCours = "\(GenerateurDossiers.basePath)\(niveau)/\(quadri)/\(nomDossierCours)"
        let fileManager = FileManager.default
        let sousDossiers = ["CM", "TP", "Synthèses", "Syllabus", "Devoirs"]
        do {
            try fileManager.createDirectory(atPath: cheminCompletCours, withIntermediateDirectories: true, attributes: nil)
            for sub in sousDossiers {
                try fileManager.createDirectory(atPath: "\(cheminCompletCours)/\(code)-\(sub)", withIntermediateDirectories: true, attributes: nil)
            }
            return (true, "✅ Dossier \(code) créé avec succès dans \(niveau) → \(quadri) !")
        } catch {
            return (false, "❌ Erreur : \(error.localizedDescription)")
        }
    }
}

// MARK: - SousMenuCoursView (colonne gauche)

struct SousMenuCoursView: View {
    @Binding var niveauActuel: String
    @Binding var quadriActuel: String
    @Binding var sousOngletSelectionne: String

    @State private var refreshID = UUID()

    let niveauxPossibles = ["BAC1", "BAC2", "BAC3", "MS1", "MS2"]
    let quadrimestresPossibles = ["Q1", "Q2"]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Session
            VStack(alignment: .leading, spacing: 5) {
                Text("Session (Sauvegarde Auto)")
                    .font(.caption).foregroundColor(.green).bold()
                HStack {
                    Picker("", selection: $niveauActuel) {
                        ForEach(niveauxPossibles, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("", selection: $quadriActuel) {
                        ForEach(quadrimestresPossibles, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(8)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)

            Divider()

            // Bouton Gérer
            Button(action: { sousOngletSelectionne = "gestion" }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Gérer / Ajouter un cours")
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(sousOngletSelectionne == "gestion" ? Color.blue : Color.clear)
                .foregroundColor(sousOngletSelectionne == "gestion" ? .white : .primary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Text("Mes cours de la période")
                .font(.caption2).bold().foregroundColor(.secondary)
                .padding(.top, 10)

            let coursTrouves = scannerCoursSurOneDrive()

            if coursTrouves.isEmpty {
                Text("Aucun cours trouvé.\nCréez-en un ci-dessus.")
                    .font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            } else {
                List(coursTrouves, id: \.self, selection: $sousOngletSelectionne) { dossier in
                    let code = dossier.components(separatedBy: "-").first ?? dossier
                    let nom = dossier.components(separatedBy: "-").dropFirst().joined(separator: "-")
                    let estSelectionne = sousOngletSelectionne == code
                    VStack(alignment: .leading, spacing: 2) {
                        Text(code).font(.body).bold()
                        if !nom.isEmpty {
                            Text(nom).font(.caption)
                                .foregroundColor(estSelectionne ? .white.opacity(0.85) : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(estSelectionne ? Color.blue : Color.clear)
                    .foregroundColor(estSelectionne ? .white : .primary)
                    .onTapGesture { sousOngletSelectionne = code }
                }
                .listStyle(.sidebar)
                .id(refreshID)
            }
        }
        .padding(.horizontal, 10).padding(.top, 15)
        .onChange(of: niveauActuel)  { _, _ in refreshID = UUID() }
        .onChange(of: quadriActuel)  { _, _ in refreshID = UUID() }
        .onChange(of: sousOngletSelectionne) { _, val in
            if val == "gestion" { refreshID = UUID() }
        }
    }

    func scannerCoursSurOneDrive() -> [String] {
        let chemin = "\(GenerateurDossiers.basePath)\(niveauActuel)/\(quadriActuel)/"
        guard let dossiers = try? FileManager.default.contentsOfDirectory(atPath: chemin) else { return [] }
        return dossiers.filter {
            !$0.hasPrefix(".") && !$0.lowercased().contains("icon") &&
            ($0.components(separatedBy: "-").first?.count ?? 0) >= 4
        }.sorted()
    }
}

// MARK: - GestionCoursView (colonne droite — dispatch)

struct GestionCoursView: View {
    let niveauActuel: String
    let quadriActuel: String
    @Binding var sousOngletSelectionne: String

    let dataManager = DataManager.shared

    @State private var codeCoursManuel: String = ""
    @State private var nomCoursManuel: String = ""
    @State private var messageStatut: String = ""
    @State private var estUneErreur: Bool = false
    @State private var nombreTPInitial: Int = 13
    @State private var nombreCMInitial: Int = 12

    var body: some View {
        Group {
            if sousOngletSelectionne == "gestion" {
                VueInterneConfiguration(
                    niveau: niveauActuel,
                    quadri: quadriActuel,
                    codeManuel: $codeCoursManuel,
                    nomManuel: $nomCoursManuel,
                    nombreTP: $nombreTPInitial,
                    nombreCM: $nombreCMInitial,
                    messageStatut: $messageStatut,
                    estUneErreur: $estUneErreur,
                    actionCreation: executerCreation,
                    coursIcalDetectes: listerCodesIcalDisponibles()
                )
            } else {
                let evenementsDuCours = dataManager.coursRegroupes[sousOngletSelectionne] ?? []
                VueInterneDetailCours(
                    code: sousOngletSelectionne,
                    evenementsIcalBruts: evenementsDuCours,
                    niveau: niveauActuel,
                    quadri: quadriActuel
                )
                .id(sousOngletSelectionne)
            }
        }
    }

    func listerCodesIcalDisponibles() -> [String] {
        let tousLesCodes = dataManager.listeCours
            .filter { $0.typeGlobal == "COURS_GENERAL" && $0.code != "AUTRE" && $0.code != "GÉNÉRAL" }
            .map { $0.code }
        let uniques = Array(Set(tousLesCodes))
        let chemin = "\(GenerateurDossiers.basePath)\(niveauActuel)/\(quadriActuel)/"
        let existants = (try? FileManager.default.contentsOfDirectory(atPath: chemin)) ?? []
        return uniques.filter { code in !existants.contains(where: { $0.hasPrefix(code) }) }.sorted()
    }

    func executerCreation() {
        let res = GenerateurDossiers().creerArborescence(
            code: codeCoursManuel, nom: nomCoursManuel,
            niveau: niveauActuel, quadri: quadriActuel
        )
        estUneErreur = !res.estUnSucces
        messageStatut = res.message
        if res.estUnSucces {
            UserDefaults.standard.set(nombreTPInitial, forKey: "nb_tp_\(niveauActuel)_\(quadriActuel)_\(codeCoursManuel)")
            UserDefaults.standard.set(nombreCMInitial, forKey: "nb_cm_\(niveauActuel)_\(quadriActuel)_\(codeCoursManuel)")
            let code = codeCoursManuel
            codeCoursManuel = ""; nomCoursManuel = ""
            nombreTPInitial = 13; nombreCMInitial = 12
            sousOngletSelectionne = code
        }
    }
}

// MARK: - VueInterneConfiguration

struct VueInterneConfiguration: View {
    let niveau: String
    let quadri: String
    @Binding var codeManuel: String
    @Binding var nomManuel: String
    @Binding var nombreTP: Int
    @Binding var nombreCM: Int
    @Binding var messageStatut: String
    @Binding var estUneErreur: Bool
    let actionCreation: () -> Void
    let coursIcalDetectes: [String]

    @State private var texteTP: String = ""
    @State private var texteCM: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 35) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gestion des Cours • \(niveau) \(quadri)").font(.largeTitle).bold()
                    Text("Créez vos dossiers OneDrive pour générer automatiquement l'arborescence de vos cours.")
                        .foregroundColor(.secondary)
                }
                Divider()
                if !coursIcalDetectes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Détecté dans votre Calendrier Mac", systemImage: "sparkles")
                            .font(.headline).foregroundColor(.orange)
                        Text("Ces codes apparaissent dans votre agenda mais n'ont pas encore de dossier OneDrive.")
                            .font(.caption).foregroundColor(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(coursIcalDetectes, id: \.self) { code in
                                Button(action: { codeManuel = code }) {
                                    Text(code).font(.subheadline).bold()
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(codeManuel == code ? Color.orange : Color.orange.opacity(0.15))
                                        .foregroundColor(codeManuel == code ? .white : .orange)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                }
                VStack(alignment: .leading, spacing: 20) {
                    Text("Créer une nouvelle matière").font(.title2).bold()
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Code du cours").font(.headline)
                            TextField("ex: LEPL1106", text: $codeManuel)
                                .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 250)
                                .onChange(of: codeManuel) { _, nv in codeManuel = nv.uppercased() }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nom du cours").font(.headline)
                            TextField("ex: Signaux et Systèmes", text: $nomManuel)
                                .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 400)
                        }
                        HStack(alignment: .top, spacing: 30) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nombre de CM").font(.headline)
                                HStack(spacing: 6) {
                                    TextField("ex: 12", text: $texteCM)
                                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80)
                                        .onAppear { texteCM = nombreCM > 0 ? "\(nombreCM)" : "" }
                                        .onChange(of: texteCM) { _, nv in
                                            let f = nv.filter { $0.isNumber }; texteCM = f
                                            nombreCM = Int(f) ?? 0
                                        }
                                    Text("séances").foregroundColor(.secondary).font(.subheadline)
                                }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nombre de TP").font(.headline)
                                HStack(spacing: 6) {
                                    TextField("ex: 13", text: $texteTP)
                                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(width: 80)
                                        .onAppear { texteTP = nombreTP > 0 ? "\(nombreTP)" : "" }
                                        .onChange(of: texteTP) { _, nv in
                                            let f = nv.filter { $0.isNumber }; texteTP = f
                                            nombreTP = Int(f) ?? 0
                                        }
                                    Text("séances").foregroundColor(.secondary).font(.subheadline)
                                }
                            }
                        }
                    }
                    if !codeManuel.isEmpty && !nomManuel.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill").foregroundColor(.blue)
                            Text("OneDrive / \(niveau) / \(quadri) / **\(codeManuel)-\(nomManuel)**")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(8).background(Color.blue.opacity(0.07)).cornerRadius(6)
                    }
                    Button(action: actionCreation) {
                        Label("Générer l'arborescence OneDrive", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(codeManuel.isEmpty || nomManuel.isEmpty)
                    if !messageStatut.isEmpty {
                        HStack {
                            Image(systemName: estUneErreur ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(estUneErreur ? .red : .green)
                            Text(messageStatut)
                        }
                        .padding(8)
                        .background(estUneErreur ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(30)
        }
    }
}

// MARK: - Popover Paramètres du cours

struct PopoverParametresCours: View {
    let code: String
    let niveau: String
    let quadri: String

    @Binding var maxCMs: Int
    @Binding var maxTPs: Int
    @Binding var motCleEnCours: String
    @Binding var motCleRecherche: String

    let nombreSeancesIcal: Int
    let onSaveMotCle: () -> Void
    let onRefresh: () -> Void

    @State private var texteCM: String = ""
    @State private var texteTP: String = ""

    @State private var creditsRequisTexte: String = ""
    @State private var creditsAcquisTexte: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("Paramètres du cours")
                .font(.headline)

            Divider()

            // ── Séances ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("Nombre de séances", systemImage: "number.circle")
                    .font(.subheadline).bold()

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CM").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("12", text: $texteCM)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onAppear { texteCM = maxCMs > 0 ? "\(maxCMs)" : "" }
                                .onChange(of: texteCM) { _, nv in
                                    let f = nv.filter { $0.isNumber }; texteCM = f
                                    let val = Int(f) ?? 0
                                    maxCMs = val
                                    UserDefaults.standard.set(val, forKey: "nb_cm_\(niveau)_\(quadri)_\(code)")
                                    onRefresh()
                                }
                            Text("séances").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TP").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("13", text: $texteTP)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onAppear { texteTP = maxTPs > 0 ? "\(maxTPs)" : "" }
                                .onChange(of: texteTP) { _, nv in
                                    let f = nv.filter { $0.isNumber }; texteTP = f
                                    let val = Int(f) ?? 0
                                    maxTPs = val
                                    UserDefaults.standard.set(val, forKey: "nb_tp_\(niveau)_\(quadri)_\(code)")
                                    onRefresh()
                                }
                            Text("séances").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // ── Crédits ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("Crédits du cours", systemImage: "graduationcap").font(.subheadline).bold()
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Requis").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("ex: 5", text: $creditsRequisTexte)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onAppear {
                                    let val = UserDefaults.standard.integer(forKey: "credits_requis_\(niveau)_\(quadri)_\(code)")
                                    creditsRequisTexte = val == 0 && UserDefaults.standard.object(forKey: "credits_requis_\(niveau)_\(quadri)_\(code)") == nil ? "" : String(val)
                                }
                                .onChange(of: creditsRequisTexte) { _, nv in
                                    let f = nv.filter { $0.isNumber }; creditsRequisTexte = f
                                    let val = Int(f) ?? 0
                                    UserDefaults.standard.set(val, forKey: "credits_requis_\(niveau)_\(quadri)_\(code)")
                                    onRefresh()
                                }
                            Text("ECTS").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Obtenus").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("ex: 3", text: $creditsAcquisTexte)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onAppear {
                                    let val = UserDefaults.standard.integer(forKey: "credits_acquis_\(niveau)_\(quadri)_\(code)")
                                    creditsAcquisTexte = val == 0 && UserDefaults.standard.object(forKey: "credits_acquis_\(niveau)_\(quadri)_\(code)") == nil ? "" : String(val)
                                }
                                .onChange(of: creditsAcquisTexte) { _, nv in
                                    let f = nv.filter { $0.isNumber }; creditsAcquisTexte = f
                                    let val = Int(f) ?? 0
                                    UserDefaults.standard.set(val, forKey: "credits_acquis_\(niveau)_\(quadri)_\(code)")
                                    onRefresh()
                                }
                            Text("ECTS").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            Divider()

            // ── Liaison iCal ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Label("Liaison Agenda iCal", systemImage: "calendar.badge.magnifyingglass")
                    .font(.subheadline).bold()
                Text("Mot-clé correspondant au titre dans votre calendrier.")
                    .font(.caption).foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("ex: MECANIQUE DES STRUCTURES", text: $motCleEnCours)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit { onSaveMotCle() }
                    if !motCleEnCours.isEmpty {
                        Button(action: onSaveMotCle) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                        }
                        .buttonStyle(.plain).help("Sauvegarder")
                    }
                }

                if !motCleRecherche.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Filtre actif → \(nombreSeancesIcal) séance(s)")
                            .font(.caption).foregroundColor(.green)
                        Spacer()
                        Button(action: {
                            motCleRecherche = ""; motCleEnCours = ""
                        }) {
                            Image(systemName: "xmark.circle").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain).help("Effacer le filtre")
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 340)
    }
}

// MARK: - VueInterneDetailCours

struct VueInterneDetailCours: View {
    let code: String
    let evenementsIcalBruts: [ÉvénementCours]
    let niveau: String
    let quadri: String

    @AppStorage private var motCleRecherche: String
    @State private var maxTPs: Int = 13
    @State private var maxCMs: Int = 12
    @State private var tpsTrouves: [StatutTP] = []
    @State private var cmsTrouves: [StatutTP] = []
    @State private var refreshID = UUID()
    @State private var nomDuCoursTrouve: String = ""
    @State private var evenementsPerso: [EvenementPerso] = []
    @State private var filtreType: String = "Tous"
    @State private var motCleEnCours: String = ""
    @State private var afficherSheetAjout: Bool = false
    @State private var afficherParametres: Bool = false
    @State private var notes: [NoteCours] = []
    @State private var nouveauTexte: String = ""

    @State private var creditsRequis: Int = 0
    @State private var creditsAcquis: Int = 0

    let types = ["Tous", "CM", "TP", "Devoir", "Examen"]

    init(code: String, evenementsIcalBruts: [ÉvénementCours], niveau: String, quadri: String) {
        self.code = code
        self.evenementsIcalBruts = evenementsIcalBruts
        self.niveau = niveau
        self.quadri = quadri
        self._motCleRecherche = AppStorage(wrappedValue: "", "mot_cle_ical_\(code)")
        let cleTP = "nb_tp_\(niveau)_\(quadri)_\(code)"
        let stockeTP = UserDefaults.standard.integer(forKey: cleTP)
        self._maxTPs = State(initialValue: stockeTP == 0 && UserDefaults.standard.object(forKey: cleTP) == nil ? 13 : stockeTP)
        let cleCM = "nb_cm_\(niveau)_\(quadri)_\(code)"
        let stockeCM = UserDefaults.standard.integer(forKey: cleCM)
        self._maxCMs = State(initialValue: stockeCM == 0 && UserDefaults.standard.object(forKey: cleCM) == nil ? 12 : stockeCM)
        let cReq = UserDefaults.standard.integer(forKey: "credits_requis_\(niveau)_\(quadri)_\(code)")
        self._creditsRequis = State(initialValue: cReq)
        let cAcq = UserDefaults.standard.integer(forKey: "credits_acquis_\(niveau)_\(quadri)_\(code)")
        self._creditsAcquis = State(initialValue: cAcq)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {

                // ── HEADER ───────────────────────────────────────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(niveau) — \(quadri)")
                            .font(.caption).foregroundColor(.secondary).bold()
                        Text(code).font(.largeTitle).bold()
                        if !nomDuCoursTrouve.isEmpty {
                            Text(nomDuCoursTrouve).font(.title3).foregroundColor(.secondary)
                        }
                        HStack(spacing: 8) {
                            Label("Crédits", systemImage: "graduationcap").font(.caption).foregroundColor(.secondary)
                            Text("\(creditsAcquis) / \(creditsRequis) ECTS")
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background((creditsRequis > 0 && creditsAcquis >= creditsRequis) ? Color.green.opacity(0.15) : Color.blue.opacity(0.12))
                                .foregroundColor((creditsRequis > 0 && creditsAcquis >= creditsRequis) ? .green : .blue)
                                .cornerRadius(6)
                        }
                    }
                    Spacer()

                    // Bouton paramètres du cours ⚙️
                    Button {
                        afficherParametres.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Paramètres du cours")
                    .popover(isPresented: $afficherParametres, arrowEdge: .top) {
                        PopoverParametresCours(
                            code: code,
                            niveau: niveau,
                            quadri: quadri,
                            maxCMs: $maxCMs,
                            maxTPs: $maxTPs,
                            motCleEnCours: $motCleEnCours,
                            motCleRecherche: $motCleRecherche,
                            nombreSeancesIcal: filtrerEvenements().count,
                            onSaveMotCle: sauvegarderMotCle,
                            onRefresh: rafraichirDonnees
                        )
                    }
                }

                Divider()

                // ── POST-ITS ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Post-its").font(.headline)
                    HStack {
                        TextField("Nouvelle note...", text: $nouveauTexte)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Ajouter") {
                            guard !nouveauTexte.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let note = NoteCours(texte: nouveauTexte, dateCreation: Date())
                            notes.append(note)
                            NoteManager.sauvegarderNotes(pour: code, notes: notes)
                            nouveauTexte = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(nouveauTexte.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !notes.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 8) {
                            ForEach(notes) { note in
                                ZStack(alignment: .topTrailing) {
                                    Text(note.texte)
                                        .padding()
                                        .frame(maxWidth: .infinity, minHeight: 90)
                                        .background(Color.yellow.opacity(0.35))
                                        .cornerRadius(8)
                                    Button {
                                        notes.removeAll { $0.id == note.id }
                                        NoteManager.sauvegarderNotes(pour: code, notes: notes)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain).padding(6)
                                }
                            }
                        }
                    }
                }
                .onAppear { notes = NoteManager.chargerNotes(pour: code) }

                // ── RAPPELS iCLOUD ───────────────────────────────────────
                SectionRappelsCoursView(codeCours: code)

                // ── CM ───────────────────────────────────────────────────
                if maxCMs > 0 {
                    let totalCMs = cmsTrouves.filter { $0.existe }.count
                    let cheminCM = cheminDossierSurOneDrive(type: "CM")

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Cours Magistraux (CM)", systemImage: "film.stack")
                                    .font(.title2).bold().foregroundColor(.orange)
                                Text("💡 Double-cliquez sur un CM pour l'ouvrir dans le Finder.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let ch = cheminCM {
                                Button { ouvrirDossierDansFinder(at: ch) } label: {
                                    Label("Ouvrir dossier", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                            Text("\(totalCMs) / \(maxCMs) récupérés")
                                .font(.headline)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(totalCMs == maxCMs ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                                .foregroundColor(totalCMs == maxCMs ? .green : .orange)
                                .cornerRadius(8)
                        }
                        ProgressView(value: Double(totalCMs), total: Double(maxCMs))
                            .progressViewStyle(.linear)
                            .tint(totalCMs == maxCMs ? .green : .orange)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                            ForEach(cmsTrouves, id: \.numero) { cm in
                                HStack {
                                    Image(systemName: cm.existe ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(cm.existe ? .orange : .secondary)
                                    Text("CM \(String(format: "%02d", cm.numero))").font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                                .background(cm.existe ? Color.orange.opacity(0.08) : Color(.windowBackgroundColor).opacity(0.4))
                                .cornerRadius(6)
                                .onTapGesture(count: 2) {
                                    if cm.existe, let ch = cm.cheminComplet { ouvrirDossierDansFinder(at: ch) }
                                }
                                .help(cm.existe ? "Double-cliquez pour ouvrir dans le Finder" : "Dossier absent")
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding().background(Color(.windowBackgroundColor).opacity(0.3)).cornerRadius(12)
                    .id(refreshID)
                }

                // ── TPs ──────────────────────────────────────────────────
                if maxTPs > 0 {
                    let totalTps = tpsTrouves.filter { $0.existe }.count

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Suivi des Travaux Pratiques", systemImage: "folder.badge.gearshape")
                                    .font(.title2).bold()
                                Text("💡 Double-cliquez sur un TP pour l'ouvrir dans le Finder.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(totalTps) / \(maxTPs) validés")
                                .font(.headline)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(totalTps == maxTPs ? Color.green.opacity(0.2) : Color.blue.opacity(0.15))
                                .foregroundColor(totalTps == maxTPs ? .green : .blue)
                                .cornerRadius(8)
                        }
                        ProgressView(value: Double(totalTps), total: Double(maxTPs))
                            .progressViewStyle(.linear)
                            .tint(totalTps == maxTPs ? .green : .blue)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                            ForEach(tpsTrouves, id: \.numero) { tp in
                                HStack {
                                    Image(systemName: tp.existe ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(tp.existe ? .green : .secondary)
                                    Text("TP \(String(format: "%02d", tp.numero))").font(.subheadline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                                .background(tp.existe ? Color.green.opacity(0.08) : Color(.windowBackgroundColor).opacity(0.4))
                                .cornerRadius(6)
                                .onTapGesture(count: 2) {
                                    if tp.existe, let ch = tp.cheminComplet { ouvrirDossierDansFinder(at: ch) }
                                }
                                .help(tp.existe ? "Double-cliquez → Finder\n\(tp.nomDossierTrouve ?? "")" : "Dossier absent sur OneDrive")
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding().background(Color(.windowBackgroundColor).opacity(0.3)).cornerRadius(12)
                    .id(refreshID)
                }

                Divider()

                // ── AGENDA ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Agenda & Événements", systemImage: "calendar").font(.title2).bold()
                        Spacer()
                        Button { afficherSheetAjout = true } label: {
                            Label("Ajouter", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Picker("Type", selection: $filtreType) {
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    let icalFiltres  = filtrerEvenementsParType(filtrerEvenements())
                    let persoFiltres = filtrerEvenementsPersoParType(evenementsPerso)

                    if icalFiltres.isEmpty && persoFiltres.isEmpty {
                        ContentUnavailableView(
                            "Aucun événement (\(filtreType))",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Aucune séance dans le calendrier pour ce filtre.\nAjoutez un mot-clé via ⚙️ ou créez un événement.")
                        )
                        .padding(.top, 10)
                    } else {
                        if !icalFiltres.isEmpty {
                            Text("Depuis le Calendrier Mac")
                                .font(.caption).bold().foregroundColor(.secondary)
                            ForEach(icalFiltres) { evt in LigneEvenementIcal(evt: evt) }
                        }
                        if !persoFiltres.isEmpty {
                            Text("Événements personnels")
                                .font(.caption).bold().foregroundColor(.secondary).padding(.top, 8)
                            ForEach(persoFiltres) { evt in
                                LigneEvenementPerso(evt: evt) { supprimerEvenementPerso(evt) }
                            }
                        }
                    }
                }
                .padding(.top, 5)
            }
            .padding(30)
        }
        .sheet(isPresented: $afficherSheetAjout) {
            SheetAjoutEvenement(code: code, niveau: niveau, quadri: quadri) { nouvelEvenement in
                evenementsPerso.append(nouvelEvenement)
                sauvegarderEvenementsPerso()
            }
        }
        .onAppear { rafraichirDonnees() }
        .onChange(of: maxTPs) { _, _ in rafraichirDonnees() }
        .onChange(of: maxCMs) { _, _ in rafraichirDonnees() }
    }

    // MARK: - Helpers

    func rafraichirDonnees() {
        extraireNomCoursEtPreRemplirMotCle()
        chargerEvenementsPerso()
        tpsTrouves = GestionnaireFichiers.analyserContenu(niveau: niveau, quadri: quadri, code: code, type: "TP", jusqua: maxTPs)
        cmsTrouves = GestionnaireFichiers.analyserContenu(niveau: niveau, quadri: quadri, code: code, type: "CM", jusqua: maxCMs)
        creditsRequis = UserDefaults.standard.integer(forKey: "credits_requis_\(niveau)_\(quadri)_\(code)")
        creditsAcquis = UserDefaults.standard.integer(forKey: "credits_acquis_\(niveau)_\(quadri)_\(code)")
        refreshID = UUID()
    }

    func sauvegarderMotCle() {
        let val = motCleEnCours.trimmingCharacters(in: .whitespaces)
        guard !val.isEmpty else { return }
        motCleRecherche = val
    }

    func filtrerEvenements() -> [ÉvénementCours] {
        let motCle = motCleRecherche.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let codeL  = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return DataManager.shared.listeCours.filter { evt in
            let titre   = evt.titre.lowercased()
            let codeEvt = evt.code.lowercased()
            if motCle.isEmpty { return codeEvt == codeL || titre.contains(codeL) }
            return titre.contains(motCle) || codeEvt == codeL || titre.contains(codeL)
        }.sorted(by: { $0.dateDebut < $1.dateDebut })
    }

    func filtrerEvenementsParType(_ liste: [ÉvénementCours]) -> [ÉvénementCours] {
        guard filtreType != "Tous" else { return liste }
        return liste.filter { evt in
            let t = evt.titre.uppercased()
            switch filtreType {
            case "CM":     return t.contains("CM") || t.contains("COURS MAGISTRAL")
            case "TP":     return t.contains("TP") || t.contains("TRAVAUX PRATIQUES")
            case "Examen": return t.contains("EXAM")
            case "Devoir": return t.contains("DEVOIR") || t.contains("REMISE")
            default:       return true
            }
        }
    }

    func filtrerEvenementsPersoParType(_ liste: [EvenementPerso]) -> [EvenementPerso] {
        guard filtreType != "Tous" else { return liste }
        return liste.filter { $0.type == filtreType }
    }

    func chargerEvenementsPerso() {
        let cle = "events_perso_\(code)_\(niveau)_\(quadri)"
        if let data = UserDefaults.standard.data(forKey: cle),
           let decoded = try? JSONDecoder().decode([EvenementPerso].self, from: data) {
            evenementsPerso = decoded.sorted(by: { $0.date < $1.date })
        }
    }

    func sauvegarderEvenementsPerso() {
        let cle = "events_perso_\(code)_\(niveau)_\(quadri)"
        if let data = try? JSONEncoder().encode(evenementsPerso) {
            UserDefaults.standard.set(data, forKey: cle)
        }
    }

    func supprimerEvenementPerso(_ evt: EvenementPerso) {
        evenementsPerso.removeAll { $0.id == evt.id }
        sauvegarderEvenementsPerso()
        if let ekID = evt.ekEventID {
            let store = EKEventStore()
            if let ekEvt = store.event(withIdentifier: ekID) { try? store.remove(ekEvt, span: .thisEvent) }
        }
    }

    func cheminDossierSurOneDrive(type: String) -> String? {
        let pathBase = "\(GenerateurDossiers.basePath)\(niveau)/\(quadri)/"
        guard let racines = try? FileManager.default.contentsOfDirectory(atPath: pathBase),
              let dossierCours = racines.first(where: { $0.hasPrefix(code + "-") }) else { return nil }
        let chemin = "\(pathBase)\(dossierCours)/\(code)-\(type)"
        return FileManager.default.fileExists(atPath: chemin) ? chemin : nil
    }

    func ouvrirDossierDansFinder(at chemin: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: chemin))
    }

    func extraireNomCoursEtPreRemplirMotCle() {
        let pathBase = "\(GenerateurDossiers.basePath)\(niveau)/\(quadri)/"
        guard let racines = try? FileManager.default.contentsOfDirectory(atPath: pathBase),
              let dossierCours = racines.first(where: { $0.hasPrefix(code + "-") }) else { return }
        let prefixe = "\(code)-"
        if dossierCours.hasPrefix(prefixe) {
            nomDuCoursTrouve = String(dossierCours.dropFirst(prefixe.count))
            if motCleEnCours.isEmpty {
                motCleEnCours = motCleRecherche.isEmpty ? nomDuCoursTrouve : motCleRecherche
            }
        }
    }
}

// MARK: - LigneEvenementIcal

struct LigneEvenementIcal: View {
    let evt: ÉvénementCours

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(couleurParType(evt.titre)).frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(evt.titre).font(.subheadline).bold()
                HStack(spacing: 8) {
                    if !evt.emplacement.isEmpty { Label(evt.emplacement, systemImage: "mappin.and.ellipse") }
                    Text(evt.dateDebut.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(badgeTexte(evt.titre))
                .font(.caption).bold()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(couleurParType(evt.titre).opacity(0.15))
                .foregroundColor(couleurParType(evt.titre)).cornerRadius(6)
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(Color(.windowBackgroundColor).opacity(0.3)).cornerRadius(8)
    }

    func badgeTexte(_ titre: String) -> String {
        let t = titre.uppercased()
        if t.contains("EXAM") { return "EXAM" }
        if t.contains("CM")   { return "CM" }
        if t.contains("TP")   { return "TP" }
        return "Cours"
    }
    func couleurParType(_ titre: String) -> Color {
        let t = titre.uppercased()
        if t.contains("EXAM") { return .red }
        if t.contains("CM")   { return .orange }
        if t.contains("TP")   { return .green }
        return .blue
    }
}

// MARK: - LigneEvenementPerso

struct LigneEvenementPerso: View {
    let evt: EvenementPerso
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(couleurType(evt.type)).frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(evt.titre).font(.subheadline).bold()
                if !evt.notes.isEmpty { Text(evt.notes).font(.caption).foregroundColor(.secondary) }
                Text(evt.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                if evt.ekEventID != nil {
                    Image(systemName: "calendar.badge.checkmark").foregroundColor(.green)
                        .help("Synchronisé avec le Calendrier Mac")
                }
                Text(evt.type).font(.caption).bold()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(couleurType(evt.type).opacity(0.15))
                    .foregroundColor(couleurType(evt.type)).cornerRadius(6)
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain).help("Supprimer cet événement")
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(Color(.windowBackgroundColor).opacity(0.3)).cornerRadius(8)
    }

    func couleurType(_ type: String) -> Color {
        switch type {
        case "CM": return .orange; case "TP": return .green
        case "Examen": return .red; case "Devoir": return .purple
        default: return .gray
        }
    }
}

// MARK: - SheetAjoutEvenement

struct SheetAjoutEvenement: View {
    let code: String
    let niveau: String
    let quadri: String
    let onSave: (EvenementPerso) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var titre: String = ""
    @State private var type: String = "Devoir"
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var syncCalendrier: Bool = true
    @State private var messageErreur: String = ""
    @State private var enCours: Bool = false

    let types = ["CM", "TP", "Devoir", "Examen"]
    let couleurs: [String: Color] = ["CM": .orange, "TP": .green, "Devoir": .purple, "Examen": .red]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("Nouvel événement — \(code)", systemImage: "calendar.badge.plus").font(.title2).bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Type d'événement").font(.headline)
                HStack(spacing: 10) {
                    ForEach(types, id: \.self) { t in
                        Button {
                            type = t
                            if titre.isEmpty { titre = "\(code) — \(t)" }
                        } label: {
                            Text(t).font(.subheadline).bold()
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(type == t ? (couleurs[t] ?? .blue) : Color(.windowBackgroundColor))
                                .foregroundColor(type == t ? .white : .primary).cornerRadius(8)
                        }.buttonStyle(.plain)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Titre").font(.headline)
                TextField("ex: LEPL1106 — Examen de janvier", text: $titre)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Date & heure").font(.headline)
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (optionnel)").font(.headline)
                TextEditor(text: $notes).frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor), lineWidth: 1))
            }
            Toggle(isOn: $syncCalendrier) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus").foregroundColor(.blue)
                    Text("Ajouter au Calendrier Mac")
                }
            }.toggleStyle(.switch)
            if !messageErreur.isEmpty { Text(messageErreur).foregroundColor(.red).font(.caption) }
            Divider()
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(action: sauvegarder) {
                    if enCours { ProgressView().controlSize(.small) }
                    else { Label("Enregistrer", systemImage: "checkmark.circle.fill") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(titre.trimmingCharacters(in: .whitespaces).isEmpty || enCours)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(minWidth: 500, minHeight: 480)
    }

    func sauvegarder() {
        let titreFinal = titre.trimmingCharacters(in: .whitespaces)
        guard !titreFinal.isEmpty else { return }
        enCours = true
        if syncCalendrier {
            Task {
                let ekID = await ajouterDansCalendrier(titre: titreFinal, type: type, date: date, notes: notes)
                await MainActor.run {
                    onSave(EvenementPerso(titre: titreFinal, type: type, date: date, notes: notes, ekEventID: ekID))
                    enCours = false; dismiss()
                }
            }
        } else {
            onSave(EvenementPerso(titre: titreFinal, type: type, date: date, notes: notes, ekEventID: nil))
            enCours = false; dismiss()
        }
    }

    func ajouterDansCalendrier(titre: String, type: String, date: Date, notes: String) async -> String? {
        let store = EKEventStore()
        do {
            let accorde: Bool
            if #available(macOS 14.0, *) { accorde = try await store.requestFullAccessToEvents() }
            else { accorde = try await store.requestAccess(to: .event) }
            guard accorde else { return nil }
            let event = EKEvent(eventStore: store)
            event.title = titre
            event.startDate = date
            event.endDate = Calendar.current.date(byAdding: .hour, value: 2, to: date) ?? date
            event.notes = notes.isEmpty ? nil : notes
            event.calendar = store.defaultCalendarForNewEvents
            let minutesAvant: Int
            switch type {
            case "Examen": minutesAvant = 60 * 24
            case "Devoir": minutesAvant = 60 * 48
            default:       minutesAvant = 30
            }
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutesAvant * 60)))
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            await MainActor.run { self.messageErreur = "⚠️ Calendrier : \(error.localizedDescription)" }
            return nil
        }
    }
}

// MARK: - SectionRappelsCoursView

struct SectionRappelsCoursView: View {
    let codeCours: String
    @StateObject private var reminderManager = ReminderManager()
    @State private var texteTache = ""
    @State private var inclureDateLimite = false
    @State private var dateLimite = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rappels & Échéances iCloud").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Nouveau devoir, labo, examen...", text: $texteTache)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: ajouterTache) {
                        Label("Ajouter", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(texteTache.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                HStack {
                    Toggle(isOn: $inclureDateLimite) {
                        Text("Définir une date limite (Ajoute à l'agenda 🗓️)").font(.caption)
                    }.toggleStyle(.checkbox)
                    if inclureDateLimite {
                        DatePicker("", selection: $dateLimite, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden().datePickerStyle(.stepperField).frame(width: 150)
                    }
                }
            }
            .padding(10).background(Color(NSColor.controlBackgroundColor)).cornerRadius(8)

            let listFiltrée = reminderManager.reminders(for: codeCours)
            if listFiltrée.isEmpty {
                Text("Aucune tâche planifiée pour ce cours.")
                    .font(.callout).italic().foregroundColor(.secondary).padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(listFiltrée, id: \.calendarItemIdentifier) { reminder in
                        HStack {
                            Button { reminderManager.toggleReminderCompletion(reminder) } label: {
                                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(reminder.isCompleted ? .green : .secondary)
                            }.buttonStyle(.plain)
                            Text(reminder.title ?? "").strikethrough(reminder.isCompleted)
                            Spacer()
                            if let components = reminder.dueDateComponents,
                               let date = Calendar.current.date(from: components) {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15)).foregroundColor(.orange).cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
        .padding().background(Color(NSColor.windowBackgroundColor).opacity(0.5)).cornerRadius(12)
        .onAppear { reminderManager.requestAccess() }
    }

    private func ajouterTache() {
        let cleanText = texteTache.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        reminderManager.addReminder(title: cleanText, codeCours: codeCours,
                                    dateEcheance: inclureDateLimite ? dateLimite : nil)
        texteTache = ""; inclureDateLimite = false
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                   proposal: ProposedViewSize(frame.size))
        }
    }
    struct FlowResult {
        var frames: [CGRect] = []; var size: CGSize = .zero
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 { x = 0; y += lineHeight + spacing; lineHeight = 0 }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                lineHeight = max(lineHeight, size.height); x += size.width + spacing
            }
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

