import SwiftUI
import UniformTypeIdentifiers

// MARK: - Vue principale

struct CuisineView: View {
    @State private var cuisineManager = CuisineManager.shared
    @State private var sousOnglet: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sousOnglet) {
                Text("Recettes").tag(0)
                Text("Menu").tag(1)
                Text("Courses").tag(2)
                Text("Placard & Frigo").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            Divider()
            switch sousOnglet {
            case 0: CahierRecettesView(manager: cuisineManager)
            case 1: MenuSemaineView(manager: cuisineManager)
            case 2: ListeCoursesView(manager: cuisineManager)
            case 3: PlacardsView(manager: cuisineManager)
            default: EmptyView()
            }
        }
    }
}

// MARK: - Helpers image

func copierImageVersAppSupport(url source: URL) -> String? {
    let fm = FileManager.default
    guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
    let dossier = appSupport.appendingPathComponent("CuisineApp/Images", isDirectory: true)
    try? fm.createDirectory(at: dossier, withIntermediateDirectories: true)
    let dest = dossier.appendingPathComponent(source.lastPathComponent)
    try? fm.removeItem(at: dest)
    do { try fm.copyItem(at: source, to: dest); return dest.path } catch { return nil }
}

func chargerNSImage(path: String?) -> NSImage? {
    guard let path else { return nil }
    return NSImage(contentsOfFile: path)
}

// MARK: - Autocomplétion

struct AutocompleteIngredientView: View {
    @Binding var texte: String
    let suggestions: [String]
    let onSelect: (String) -> Void

    var filtrees: [String] {
        let n = normaliserProduit(texte)
        guard n.count >= 2 else { return [] }
        return suggestions.filter { normaliserProduit($0).contains(n) }.prefix(6).map { $0 }
    }

    var body: some View {
        if !filtrees.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filtrees, id: \.self) { s in
                    Button { onSelect(s) } label: {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.caption)
                            Text(s)
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).background(Color.accentColor.opacity(0.07))
                    if s != filtrees.last { Divider() }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        }
    }
}

// MARK: - Badge faisabilité

struct StockBadge: View {
    let score: Double
    var couleur: Color { score >= 0.9 ? .green : score >= 0.5 ? .orange : .red }
    var label: String {
        if score >= 0.9 { return "✓ Faisable" }
        if score >= 0.5 { return "~ \(Int(score*100))%" }
        return "\(Int(score*100))%"
    }
    var body: some View {
        Text(label).font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(couleur.opacity(0.15)).foregroundColor(couleur).cornerRadius(4)
    }
}

// MARK: - 1. Cahier de Recettes

struct CahierRecettesView: View {
    @Bindable var manager: CuisineManager
    @State private var filtreCategorie: CategorieRecette = .plat
    @State private var recetteAVisualiser: Recette? = nil
    @State private var afficherFormulaire = false
    @State private var recetteEnEdition: Recette? = nil
    @State private var afficherSuggestions = false
    @State private var recherche = ""

    var recettesFiltrees: [Recette] {
        manager.listeRecettes
            .filter { $0.categorie == filtreCategorie }
            .filter { recherche.isEmpty || normaliserProduit($0.nom).contains(normaliserProduit(recherche)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $filtreCategorie) {
                    ForEach(CategorieRecette.allCases) { cat in Text(cat.rawValue).tag(cat) }
                }.pickerStyle(.segmented)
                TextField("Rechercher…", text: $recherche).frame(width: 160)
                Toggle(isOn: $afficherSuggestions) {
                    Label("Suggestions", systemImage: "wand.and.stars").font(.subheadline)
                }
                .toggleStyle(.button)
                .help("Recettes faisables avec ce que j'ai")
                Spacer()
                Button { recetteEnEdition = nil; afficherFormulaire = true } label: {
                    Label("Nouvelle Recette", systemImage: "plus")
                }
            }.padding()
            Divider()

            if afficherSuggestions {
                SuggestionsRecettesView(manager: manager)
            } else {
                List {
                    if recettesFiltrees.isEmpty {
                        Text("Aucune recette.").foregroundColor(.secondary).padding()
                    }
                    ForEach(recettesFiltrees) { r in
                        RecetteLigneView(recette: r, manager: manager,
                            onVisualiser: { recetteAVisualiser = r },
                            onModifier:   { recetteEnEdition = r; afficherFormulaire = true })
                    }
                }
            }
        }
        .sheet(item: $recetteAVisualiser) { VisualiseurRecetteView(recette: $0) }
        .sheet(isPresented: $afficherFormulaire) {
            FormulaireRecetteView(manager: manager, recetteExistante: recetteEnEdition, categorieInitiale: filtreCategorie)
        }
    }
}

struct RecetteLigneView: View {
    let recette: Recette
    @Bindable var manager: CuisineManager
    let onVisualiser: () -> Void
    let onModifier: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            if let img = chargerNSImage(path: recette.imagePath) {
                Image(nsImage: img).resizable().scaledToFill().frame(width: 70, height: 70).cornerRadius(6).clipped()
            } else {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)).frame(width: 70, height: 70)
                    .overlay(Image(systemName: "fork.knife").foregroundColor(.secondary))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(recette.nom).font(.headline)
                Text("⏱️ \(recette.dureeMinutes) min — Pour \(recette.portionsDeBase) pers.").font(.caption).foregroundColor(.secondary)
                Text(String(format: "💰 %.2f €", recette.prixEstime)).font(.caption.bold()).foregroundColor(.green)
                StockBadge(score: manager.scoreFaisabilite(recette))
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Cuisiner") { onVisualiser() }.buttonStyle(.borderedProminent)
                Button("Modifier") { onModifier() }.buttonStyle(.bordered)
                Button(role: .destructive) {
                    manager.listeRecettes.removeAll { $0.id == recette.id }; manager.sauvegarderRecettes()
                } label: { Image(systemName: "trash") }.buttonStyle(.plain).padding(.leading, 4)
            }
        }.padding(.vertical, 6)
    }
}

// MARK: - Suggestions

struct SuggestionsRecettesView: View {
    @Bindable var manager: CuisineManager
    @State private var seuil: Double = 0.5
    @State private var recetteAVisualiser: Recette? = nil

    var suggestions: [(recette: Recette, score: Double)] { manager.recettesRealisables(seuilMin: seuil) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ingrédients disponibles minimum :").font(.subheadline).foregroundColor(.secondary)
                Slider(value: $seuil, in: 0...1, step: 0.1).frame(width: 160)
                Text("\(Int(seuil * 100))%").font(.subheadline.bold()).frame(width: 36)
                Spacer()
                // Rappel frigo actif
                if !manager.frigo.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "refrigerator").foregroundColor(.blue).font(.caption)
                        Text("Frigo : \(manager.frigo.map { $0.nom }.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.blue).lineLimit(1)
                    }
                }
                Text("\(suggestions.count) recette(s)").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.05))
            Divider()

            if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart.badge.questionmark").font(.largeTitle).foregroundColor(.secondary)
                    Text("Aucune recette faisable avec ce que vous avez.").foregroundColor(.secondary)
                    Text("Ajoutez des articles dans Placard & Frigo ou baissez le seuil.").font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else {
                List {
                    ForEach(suggestions, id: \.recette.id) { item in
                        SuggestionLigneView(recette: item.recette, score: item.score,
                            manquants: manager.ingredientsManquants(item.recette),
                            duFrigo: manager.ingredientsDuFrigo(item.recette),
                            onVisualiser: { recetteAVisualiser = item.recette })
                    }
                }
            }
        }
        .sheet(item: $recetteAVisualiser) { VisualiseurRecetteView(recette: $0) }
    }
}

struct SuggestionLigneView: View {
    let recette: Recette
    let score: Double
    let manquants: [Ingredient]
    let duFrigo: [Ingredient]
    let onVisualiser: () -> Void

    var couleur: Color { score >= 0.9 ? .green : score >= 0.5 ? .orange : .red }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 5)
                Circle().trim(from: 0, to: score)
                    .stroke(couleur, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(score * 100))%").font(.system(size: 10, weight: .bold))
            }.frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(recette.nom).font(.headline)
                Text("⏱️ \(recette.dureeMinutes) min").font(.caption).foregroundColor(.secondary)
                if !duFrigo.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "refrigerator").foregroundColor(.blue).font(.caption)
                        Text("Frigo : \(duFrigo.map { $0.produit }.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.blue)
                    }
                }
                if !manquants.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.badge.plus").foregroundColor(.orange).font(.caption)
                        Text("À acheter : \(manquants.map { $0.produit }.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.orange)
                    }
                } else {
                    Label("Tout disponible !", systemImage: "checkmark.seal.fill").font(.caption).foregroundColor(.green)
                }
            }
            Spacer()
            Button("Cuisiner") { onVisualiser() }.buttonStyle(.borderedProminent)
        }.padding(.vertical, 4)
    }
}

// MARK: - Formulaire Recette

struct FormulaireRecetteView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var manager: CuisineManager
    let recetteExistante: Recette?
    let categorieInitiale: CategorieRecette

    @State private var nom = ""
    @State private var categorie: CategorieRecette = .plat
    @State private var dureeTexte = "20"
    @State private var prixTexte = "10.0"
    @State private var portionsBase = 2
    @State private var instructions = ""
    @State private var imagePath: String? = nil
    @State private var nsImageApercu: NSImage? = nil
    @State private var ingredients: [Ingredient] = []
    @State private var qteSaisie = ""
    @State private var uniteSaisie = ""
    @State private var produitSaisi = ""
    @State private var afficherAC = false

    let unitesRapides = ["g","kg","ml","L","cl","c. à s.","c. à c.","pincée","unité"]

    var produitsConnus: [String] {
        let r = manager.listeRecettes.flatMap { $0.ingredients.map { $0.produit } }
        let g = manager.gardeManger.map { $0.nom }
        let f = manager.frigo.map { $0.nom }
        return Array(Set(r + g + f)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(recetteExistante == nil ? "Ajouter une recette" : "Modifier la recette").font(.title2).bold()
                Spacer()
                Button("Annuler") { dismiss() }
                Button("Enregistrer") { sauvegarder() }.buttonStyle(.borderedProminent)
                    .disabled(nom.isEmpty || ingredients.isEmpty)
            }.padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox(label: Label("Informations générales", systemImage: "info.circle")) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Nom de la recette *", text: $nom).font(.headline)
                            Picker("Catégorie", selection: $categorie) {
                                ForEach(CategorieRecette.allCases) { cat in Text(cat.rawValue).tag(cat) }
                            }.pickerStyle(.segmented)
                            HStack(spacing: 16) {
                                HStack { Image(systemName: "clock").foregroundColor(.secondary); TextField("Durée", text: $dureeTexte).frame(width: 60); Text("min") }
                                HStack { Image(systemName: "eurosign.circle").foregroundColor(.green); TextField("Prix", text: $prixTexte).frame(width: 60); Text("€") }
                                Stepper("Pour \(portionsBase) pers.", value: $portionsBase, in: 1...20)
                            }
                        }.padding(.vertical, 4)
                    }

                    GroupBox(label: Label("Photo", systemImage: "photo")) {
                        HStack(spacing: 12) {
                            if let img = nsImageApercu {
                                Image(nsImage: img).resizable().scaledToFill().frame(width: 80, height: 80).cornerRadius(8).clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "photo.badge.plus").font(.title2).foregroundColor(.secondary))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("Choisir une photo…") { ouvrirPanneauPhoto() }.buttonStyle(.bordered)
                                Text("ou glissez une image ici").font(.caption).foregroundColor(.secondary)
                                if imagePath != nil {
                                    Button(role: .destructive) { imagePath = nil; nsImageApercu = nil } label: {
                                        Label("Supprimer", systemImage: "trash").font(.caption)
                                    }.buttonStyle(.plain).foregroundColor(.red)
                                }
                            }
                        }.padding(.vertical, 4)
                        .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                            providers.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                                DispatchQueue.main.async { appliquerImage(url: url) }
                            }
                            return true
                        }
                    }

                    GroupBox(label: Label("Ingrédients", systemImage: "list.bullet")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 6) {
                                TextField("Qté", text: $qteSaisie).frame(width: 55)
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Unité", text: $uniteSaisie).frame(width: 90)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(unitesRapides, id: \.self) { u in
                                                Button(u) { uniteSaisie = u }.font(.caption2).buttonStyle(.bordered).controlSize(.mini)
                                            }
                                        }
                                    }.frame(width: 90)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    TextField("Produit *", text: $produitSaisi)
                                        .onChange(of: produitSaisi) { _, _ in afficherAC = produitSaisi.count >= 2 }
                                        .onSubmit { ajouterIngredient() }
                                    if afficherAC {
                                        AutocompleteIngredientView(texte: $produitSaisi, suggestions: produitsConnus) { s in
                                            produitSaisi = s; afficherAC = false
                                        }.zIndex(10)
                                    }
                                }
                                Button { ajouterIngredient() } label: {
                                    Image(systemName: "plus.circle.fill").font(.title3)
                                }.buttonStyle(.plain).foregroundColor(.accentColor)
                                    .disabled(produitSaisi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            if !ingredients.isEmpty {
                                Divider()
                                ForEach(ingredients) { ing in
                                    HStack {
                                        let q = ing.quantite.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", ing.quantite) : String(format: "%.1f", ing.quantite)
                                        Image(systemName: "circle.fill").font(.system(size: 5)).foregroundColor(.accentColor)
                                        Text("\(q) \(ing.unite) \(ing.produit)")
                                        if manager.estDisponible(ing.produit) {
                                            Text("disponible").font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(Color.green.opacity(0.15)).foregroundColor(.green).cornerRadius(4)
                                        }
                                        Spacer()
                                        Button { ingredients.removeAll { $0.id == ing.id } } label: {
                                            Image(systemName: "multiply.circle.fill").foregroundColor(.secondary)
                                        }.buttonStyle(.plain)
                                    }.padding(.vertical, 2)
                                }
                            }
                        }.padding(.vertical, 4)
                    }

                    GroupBox(label: Label("Instructions", systemImage: "text.alignleft")) {
                        TextEditor(text: $instructions).frame(minHeight: 80)
                    }
                }.padding()
            }
        }
        .frame(width: 580, height: 640)
        .onAppear { initialiser() }
    }

    private func initialiser() {
        if let r = recetteExistante {
            nom = r.nom; categorie = r.categorie; dureeTexte = String(r.dureeMinutes)
            prixTexte = String(format: "%.2f", r.prixEstime); portionsBase = r.portionsDeBase
            instructions = r.instructions; imagePath = r.imagePath
            nsImageApercu = chargerNSImage(path: r.imagePath); ingredients = r.ingredients
        } else { categorie = categorieInitiale }
    }
    private func ouvrirPanneauPhoto() {
        let p = NSOpenPanel(); p.allowsMultipleSelection = false; p.canChooseDirectories = false
        p.allowedContentTypes = [.jpeg, .png, .heic, .image]
        if p.runModal() == .OK, let url = p.url { appliquerImage(url: url) }
    }
    private func appliquerImage(url: URL) {
        if let c = copierImageVersAppSupport(url: url) { imagePath = c; nsImageApercu = NSImage(contentsOfFile: c) }
    }
    private func ajouterIngredient() {
        let p = produitSaisi.trimmingCharacters(in: .whitespacesAndNewlines); guard !p.isEmpty else { return }
        ingredients.append(Ingredient(quantite: Double(qteSaisie.replacingOccurrences(of: ",", with: ".")) ?? 0,
            unite: uniteSaisie.trimmingCharacters(in: .whitespacesAndNewlines), produit: p))
        qteSaisie = ""; uniteSaisie = ""; produitSaisi = ""; afficherAC = false
    }
    private func sauvegarder() {
        let min = Int(dureeTexte) ?? 20
        let prix = Double(prixTexte.replacingOccurrences(of: ",", with: ".")) ?? 10.0
        if let ex = recetteExistante, let i = manager.listeRecettes.firstIndex(where: { $0.id == ex.id }) {
            manager.listeRecettes[i] = Recette(id: ex.id, nom: nom, categorie: categorie, ingredients: ingredients,
                instructions: instructions, imagePath: imagePath, dureeMinutes: min, portionsDeBase: portionsBase, prixEstime: prix)
        } else {
            manager.listeRecettes.append(Recette(nom: nom, categorie: categorie, ingredients: ingredients,
                instructions: instructions, imagePath: imagePath, dureeMinutes: min, portionsDeBase: portionsBase, prixEstime: prix))
        }
        manager.sauvegarderRecettes(); dismiss()
    }
}

// MARK: - Visualiseur

struct VisualiseurRecetteView: View {
    @Environment(\.dismiss) private var dismiss
    let recette: Recette
    @State private var portionsAjustees: Int

    init(recette: Recette) { self.recette = recette; _portionsAjustees = State(initialValue: recette.portionsDeBase) }

    var body: some View {
        let f = Double(portionsAjustees) / Double(recette.portionsDeBase)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(recette.nom).font(.title).bold()
                    HStack {
                        Text("⏱️ \(recette.dureeMinutes) min"); Text("•")
                        Text(String(format: "💰 %.2f €", recette.prixEstime * f)).foregroundColor(.green).bold()
                    }.font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Fermer") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.cancelAction)
            }
            if let img = chargerNSImage(path: recette.imagePath) {
                Image(nsImage: img).resizable().scaledToFill().frame(height: 140).cornerRadius(10).clipped()
            }
            HStack {
                Text("👥 Convives :").bold()
                Stepper("\(portionsAjustees) personnes", value: $portionsAjustees, in: 1...40)
            }.padding(.vertical, 6).padding(.horizontal).background(Color.accentColor.opacity(0.1)).cornerRadius(8)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ingrédients").font(.headline)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(recette.ingredients) { ing in
                                let q = ing.quantite * f
                                let qs = q.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", q) : String(format: "%.1f", q)
                                HStack(spacing: 4) {
                                    Image(systemName: "circle.fill").font(.system(size: 5)).foregroundColor(.accentColor)
                                    Text("\(qs) \(ing.unite) \(ing.produit)")
                                }
                            }
                        }
                    }
                }.frame(width: 220, alignment: .leading)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instructions").font(.headline)
                    ScrollView { Text(recette.instructions).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
        }.padding().frame(width: 620, height: 520)
    }
}

// MARK: - 2. Menu de la Semaine

struct MenuSemaineView: View {
    @Bindable var manager: CuisineManager
    let jours = ["Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"]

    var body: some View {
        List {
            ForEach(jours, id: \.self) { jour in
                Section(header: Text(jour).font(.headline).foregroundColor(.accentColor)) {
                    ForEach(["Midi","Soir"], id: \.self) { repas in
                        if let i = manager.repasPlanifies.firstIndex(where: { $0.jour == jour && $0.type == repas }) {
                            CaseRepasUniqueView(manager: manager, indexPlanification: i, typeRepas: repas)
                        }
                    }
                }
            }
        }
    }
}

struct CaseRepasUniqueView: View {
    var manager: CuisineManager
    var indexPlanification: Int
    var typeRepas: String

    var body: some View {
        let plan = manager.repasPlanifies[indexPlanification]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(typeRepas).frame(width: 50, alignment: .leading).foregroundColor(.secondary)
                Menu("Ajouter un plat…") {
                    if manager.listeRecettes.isEmpty { Button("Aucune recette", action: {}).disabled(true) }
                    ForEach(manager.listeRecettes) { r in
                        Button(r.nom) {
                            var c = plan
                            if !c.recettes.contains(where: { $0.id == r.id }) {
                                c.recettes.append(r); c.portionsCibles[r.id] = r.portionsDeBase
                                manager.repasPlanifies[indexPlanification] = c
                                manager.sauvegarderMenu(); manager.reinitialiserFiltreCourses()
                            }
                        }
                    }
                }.menuStyle(.button).frame(width: 140)
                Spacer()
            }
            if !plan.recettes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.recettes) { r in
                        let p = plan.portionsCibles[r.id] ?? r.portionsDeBase
                        HStack(spacing: 8) {
                            Text(r.nom).font(.body).bold()
                            Text("(\(r.dureeMinutes) min)").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Stepper("\(p) pers.", value: Binding(
                                get: { p },
                                set: { n in var c = plan; c.portionsCibles[r.id] = n; manager.repasPlanifies[indexPlanification] = c; manager.sauvegarderMenu() }
                            ), in: 1...20).labelsHidden()
                            Text("\(p) pers.").font(.caption).foregroundColor(.secondary).frame(width: 45)
                            Button {
                                var c = plan; c.recettes.removeAll { $0.id == r.id }; c.portionsCibles.removeValue(forKey: r.id)
                                manager.repasPlanifies[indexPlanification] = c; manager.sauvegarderMenu(); manager.reinitialiserFiltreCourses()
                            } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.08)).cornerRadius(6)
                    }
                }.padding(.leading, 55)
            }
        }.padding(.vertical, 2)
    }
}

// MARK: - 3. Liste de Courses

struct ListeCoursesView: View {
    @Bindable var manager: CuisineManager
    @State private var nouvelIngredientManuel = ""
    @State private var statutExport = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading) {
                HStack {
                    TextField("Ajouter un article libre…", text: $nouvelIngredientManuel).onSubmit { ajouterLibre() }
                    Button("Ajouter", action: ajouterLibre)
                }.padding()
                List {
                    let articles = manager.listeCoursesGeneree
                    if articles.isEmpty {
                        Text("Panier vide — tout est en stock ou filtré.").foregroundColor(.secondary).padding()
                    }
                    ForEach(articles, id: \.self) { ing in
                        HStack {
                            if ing.hasPrefix("🔴") {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            } else {
                                Image(systemName: "cart").foregroundColor(.accentColor)
                            }
                            Text(ing)
                            Spacer()
                            Button {
                                manager.ingredientsMasques.insert(ing); manager.sauvegarderIngredientsMasques()
                            } label: { Image(systemName: "checkmark.circle").foregroundColor(.gray.opacity(0.5)) }
                            .buttonStyle(.plain).help("J'en ai déjà")
                        }.padding(.vertical, 2)
                    }
                }
            }
            Divider()
            VStack(spacing: 12) {
                Text("Actions").font(.headline)
                if !statutExport.isEmpty { Text(statutExport).font(.caption).foregroundColor(.blue).multilineTextAlignment(.center) }
                Button {
                    statutExport = "⏳…"
                    Task { let r = await manager.exporterVersRappelsMac(); statutExport = r.message }
                } label: { Label("Exporter aux Rappels", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent)
                Button("Réinitialiser filtres") { manager.reinitialiserFiltreCourses() }.buttonStyle(.bordered)
                Button("Vider liste libre") { manager.ingredientsSupplementaires.removeAll(); manager.sauvegarderIngredientsSupp() }.buttonStyle(.bordered)
            }.padding().frame(width: 200)
        }
    }

    private func ajouterLibre() {
        let c = nouvelIngredientManuel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { manager.ingredientsSupplementaires.append(c); manager.sauvegarderIngredientsSupp(); nouvelIngredientManuel = "" }
    }
}

// MARK: - 4. Placard & Frigo (vue conteneur avec deux sections)

struct PlacardsView: View {
    @Bindable var manager: CuisineManager
    @State private var section: Int = 0   // 0 = Garde-Manger, 1 = Frigo

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                Text("🧂 Garde-Manger").tag(0)
                Text("🧊 Frigo / Restes").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.top, 10).padding(.bottom, 6)
            Divider()
            if section == 0 {
                GardeMangerView(manager: manager)
            } else {
                FrigoView(manager: manager)
            }
        }
    }
}

// MARK: - 4a. Garde-Manger

struct GardeMangerView: View {
    @Bindable var manager: CuisineManager
    @State private var filtre: CategorieGardeManger? = nil
    @State private var afficherAjout = false
    @State private var recherche = ""

    var articlesFiltres: [ArticleGardeManger] {
        manager.gardeManger
            .filter { filtre == nil || $0.categorie == filtre }
            .filter { recherche.isEmpty || normaliserProduit($0.nom).contains(normaliserProduit(recherche)) }
    }
    var enRupture: [ArticleGardeManger] { manager.gardeManger.filter { !$0.enStock } }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {

                // Barre outils
                HStack {
                    TextField("Rechercher…", text: $recherche).frame(width: 160)
                    Picker("", selection: $filtre) {
                        Text("Tout").tag(nil as CategorieGardeManger?)
                        ForEach(CategorieGardeManger.allCases) { c in Text(c.rawValue).tag(c as CategorieGardeManger?) }
                    }.frame(width: 200)
                    Spacer()
                    Button { afficherAjout = true } label: { Label("Ajouter", systemImage: "plus") }
                }.padding()
                Divider()

                // Bandeau ruptures
                if !enRupture.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        Text("\(enRupture.count) en rupture → ajouté(s) aux courses").font(.caption).foregroundColor(.orange)
                        Spacer()
                        Button("Tout réapprovisionner") {
                            for i in manager.gardeManger.indices { manager.gardeManger[i].enStock = true }
                            manager.sauvegarderGardeManger()
                        }.font(.caption).buttonStyle(.bordered)
                    }
                    .padding(.horizontal).padding(.vertical, 6).background(Color.orange.opacity(0.07))
                    Divider()
                }

                // Liste par catégorie
                List {
                    let parCat = Dictionary(grouping: articlesFiltres) { $0.categorie }
                    ForEach(CategorieGardeManger.allCases) { cat in
                        if let arts = parCat[cat], !arts.isEmpty {
                            Section(header: HStack {
                                Text(cat.rawValue).font(.subheadline.bold())
                                Text("(\(arts.filter { $0.enStock }.count)/\(arts.count))").font(.caption).foregroundColor(.secondary)
                            }) {
                                ForEach(arts) { a in
                                    ArticleGardeMangerLigne(article: a, manager: manager)
                                }
                                .onDelete { offsets in
                                    let ids = offsets.map { arts[$0].id }
                                    manager.gardeManger.removeAll { ids.contains($0.id) }
                                    manager.sauvegarderGardeManger()
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Panneau latéral
            VStack(alignment: .leading, spacing: 14) {
                Text("Stock").font(.headline)
                let total   = manager.gardeManger.count
                let enStock = manager.gardeManger.filter { $0.enStock }.count
                let pct     = total > 0 ? Double(enStock) / Double(total) : 1.0
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle().trim(from: 0, to: pct)
                        .stroke(pct > 0.7 ? Color.green : pct > 0.4 ? Color.orange : Color.red,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) { Text("\(enStock)").font(.title2.bold()); Text("/ \(total)").font(.caption).foregroundColor(.secondary) }
                }.frame(width: 80, height: 80).padding(.vertical, 4)

                if !enRupture.isEmpty {
                    Text("Ruptures").font(.subheadline.bold()).foregroundColor(.orange)
                    ForEach(enRupture) { a in
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundColor(.orange)
                            Text(a.nom).font(.caption)
                        }
                    }
                }
                Spacer()
                Text("💡 Les ruptures apparaissent automatiquement dans la liste de courses.")
                    .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding().frame(width: 175)
        }
        .sheet(isPresented: $afficherAjout) {
            AjoutGardeMangerView(manager: manager)
        }
    }
}

struct ArticleGardeMangerLigne: View {
    let article: ArticleGardeManger
    @Bindable var manager: CuisineManager
    @State private var confirmerSuppression = false

    var body: some View {
        HStack(spacing: 10) {
            // Toggle stock
            Button { manager.toggleStock(article) } label: {
                Image(systemName: article.enStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(article.enStock ? .green : .red)
            }
            .buttonStyle(.plain)
            .help(article.enStock ? "Marquer en rupture" : "Réapprovisionner")

            Text(article.nom)
                .strikethrough(!article.enStock, color: .secondary)
                .foregroundColor(article.enStock ? .primary : .secondary)

            Spacer()

            Text(article.categorie.rawValue).font(.caption2)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1)).foregroundColor(.accentColor).cornerRadius(4)

            // Bouton supprimer (définitivement, pas juste marquer rupture)
            Button {
                confirmerSuppression = true
            } label: {
                Image(systemName: "trash").foregroundColor(.red.opacity(0.6)).font(.caption)
            }
            .buttonStyle(.plain)
            .help("Supprimer définitivement")
            .confirmationDialog("Supprimer « \(article.nom) » du garde-manger ?", isPresented: $confirmerSuppression, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { manager.supprimerArticleGardeManger(article) }
                Button("Annuler", role: .cancel) {}
            }
        }
        .padding(.vertical, 2)
    }
}

struct AjoutGardeMangerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var manager: CuisineManager
    @State private var nom = ""
    @State private var categorie: CategorieGardeManger = .epicesHerbes

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajouter au Garde-Manger").font(.title2).bold()
            TextField("Nom de l'article (ex: Paprika fumé)", text: $nom).onSubmit { sauvegarder() }
            Picker("Catégorie", selection: $categorie) {
                ForEach(CategorieGardeManger.allCases) { c in Text(c.rawValue).tag(c) }
            }
            HStack {
                Button("Annuler") { dismiss() }
                Spacer()
                Button("Ajouter") { sauvegarder() }.buttonStyle(.borderedProminent)
                    .disabled(nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding().frame(width: 360)
    }

    private func sauvegarder() {
        let n = nom.trimmingCharacters(in: .whitespacesAndNewlines); guard !n.isEmpty else { return }
        manager.gardeManger.append(ArticleGardeManger(nom: n, categorie: categorie, enStock: true))
        manager.sauvegarderGardeManger(); dismiss()
    }
}

// MARK: - 4b. Frigo / Restes

struct FrigoView: View {
    @Bindable var manager: CuisineManager
    @State private var saisie = ""
    @State private var afficherAC = false

    var produitsConnus: [String] {
        let r = manager.listeRecettes.flatMap { $0.ingredients.map { $0.produit } }
        return Array(Set(r)).sorted()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {

                // Champ ajout
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("Ex: poulet, poivrons, œufs…", text: $saisie)
                                .onChange(of: saisie) { _, _ in afficherAC = saisie.count >= 2 }
                                .onSubmit { ajouterArticle() }
                            if afficherAC {
                                AutocompleteIngredientView(texte: $saisie, suggestions: produitsConnus) { s in
                                    saisie = s; afficherAC = false
                                }.zIndex(10)
                            }
                        }
                        Button("Ajouter") { ajouterArticle() }.buttonStyle(.borderedProminent)
                            .disabled(saisie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Ces articles comptent pour les suggestions de recettes mais n'apparaissent pas dans les courses.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding()
                Divider()

                if manager.frigo.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "refrigerator").font(.largeTitle).foregroundColor(.secondary)
                        Text("Frigo vide").foregroundColor(.secondary)
                        Text("Ajoutez ce qui traîne dans votre frigo ou placard (restes, produits frais…)").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                } else {
                    List {
                        ForEach(manager.frigo) { article in
                            HStack {
                                Image(systemName: "refrigerator").foregroundColor(.blue).font(.caption)
                                Text(article.nom)
                                Spacer()
                                Button {
                                    manager.supprimerDuFrigo(article)
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Retirer (utilisé ou périmé)")
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { manager.frigo[$0].id }
                            manager.frigo.removeAll { ids.contains($0.id) }
                            manager.sauvegarderFrigo()
                        }
                    }
                }
            }

            Divider()

            // Panneau latéral
            VStack(alignment: .leading, spacing: 12) {
                Text("Frigo").font(.headline)
                Text("\(manager.frigo.count) article(s)").font(.subheadline).foregroundColor(.secondary)

                Divider()

                Text("💡 Usages").font(.caption.bold())
                VStack(alignment: .leading, spacing: 6) {
                    Label("Suggestions de recettes", systemImage: "wand.and.stars").font(.caption)
                    Label("Badge « disponible » dans les recettes", systemImage: "checkmark.circle").font(.caption)
                }
                .foregroundColor(.secondary)

                Spacer()

                if !manager.frigo.isEmpty {
                    Button(role: .destructive) { manager.viderFrigo() } label: {
                        Label("Vider le frigo", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            .padding()
            .frame(width: 175)
        }
    }

    private func ajouterArticle() {
        let n = saisie.trimmingCharacters(in: .whitespacesAndNewlines); guard !n.isEmpty else { return }
        manager.ajouterAuFrigo(n); saisie = ""; afficherAC = false
    }
}
