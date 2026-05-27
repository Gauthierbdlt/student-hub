import Foundation
import Observation
import EventKit

// MARK: - Modèles

enum CategorieRecette: String, CaseIterable, Codable, Identifiable {
    case entree = "Entrée", plat = "Plat", dessert = "Dessert", cocktail = "Cocktail"
    var id: String { self.rawValue }
}

enum CategorieGardeManger: String, CaseIterable, Codable, Identifiable {
    case huileVinaigre = "Huiles & Vinaigres"
    case epicesHerbes  = "Épices & Herbes"
    case feculents     = "Féculents & Farines"
    case conserves     = "Conserves"
    case condiments    = "Condiments"
    case produitsSecs  = "Produits secs"
    case autres        = "Autres"
    var id: String { self.rawValue }
}

/// Article PERMANENT du garde-manger (huile, sel, épices…)
/// enStock = false → en rupture → apparaît dans les courses
struct ArticleGardeManger: Identifiable, Codable, Equatable {
    var id       = UUID()
    var nom      : String
    var categorie: CategorieGardeManger
    var enStock  : Bool = true
}

/// Article PONCTUEL du frigo/placard (poulet, poivrons, restes…)
/// Sert uniquement aux suggestions de recettes, ne génère pas de courses
struct ArticleFrigo: Identifiable, Codable, Equatable {
    var id  = UUID()
    var nom : String
}

struct Ingredient: Identifiable, Codable, Equatable {
    var id       = UUID()
    var quantite : Double
    var unite    : String
    var produit  : String
}

struct Recette: Identifiable, Codable, Equatable {
    var id             = UUID()
    var nom            : String
    var categorie      : CategorieRecette
    var ingredients    : [Ingredient]
    var instructions   : String
    var imagePath      : String?
    var dureeMinutes   : Int
    var portionsDeBase : Int
    var prixEstime     : Double
}

struct PlanificationRepas: Identifiable, Codable, Equatable {
    var id             = UUID()
    var jour           : String
    var type           : String
    var recettes       : [Recette] = []
    var portionsCibles : [UUID: Int] = [:]
}

// MARK: - Manager

@Observable
class CuisineManager {
    static let shared = CuisineManager()

    var listeRecettes              : [Recette]            = []
    var repasPlanifies             : [PlanificationRepas] = []
    var ingredientsSupplementaires : [String]             = []
    var ingredientsMasques         : Set<String>          = []
    var gardeManger                : [ArticleGardeManger] = []
    var frigo                      : [ArticleFrigo]       = []   // ← nouveau

    private let eventStore = EKEventStore()

    init() {
        chargerRecettes()
        chargerMenu()
        chargerIngredientsSupp()
        chargerIngredientsMasques()
        chargerGardeManger()
        chargerFrigo()
        initialiserSemaineSiVide()
        initialiserGardeMangerSiVide()
    }

    // MARK: - Init

    private func initialiserSemaineSiVide() {
        guard repasPlanifies.isEmpty else { return }
        for j in ["Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"] {
            for t in ["Midi","Soir"] { repasPlanifies.append(PlanificationRepas(jour: j, type: t)) }
        }
        sauvegarderMenu()
    }

    private func initialiserGardeMangerSiVide() {
        guard gardeManger.isEmpty else { return }
        let classiques: [(String, CategorieGardeManger)] = [
            ("Huile d'olive",        .huileVinaigre),
            ("Huile de tournesol",   .huileVinaigre),
            ("Vinaigre balsamique",  .huileVinaigre),
            ("Vinaigre blanc",       .huileVinaigre),
            ("Sel",                  .epicesHerbes),
            ("Poivre noir",          .epicesHerbes),
            ("Paprika",              .epicesHerbes),
            ("Cumin",                .epicesHerbes),
            ("Curry",                .epicesHerbes),
            ("Thym",                 .epicesHerbes),
            ("Laurier",              .epicesHerbes),
            ("Persil séché",         .epicesHerbes),
            ("Origan",               .epicesHerbes),
            ("Piment de Cayenne",    .epicesHerbes),
            ("Muscade",              .epicesHerbes),
            ("Cannelle",             .epicesHerbes),
            ("Farine",               .feculents),
            ("Sucre",                .feculents),
            ("Sucre vanillé",        .feculents),
            ("Levure chimique",      .feculents),
            ("Bicarbonate",          .feculents),
            ("Riz",                  .feculents),
            ("Pâtes",                .feculents),
            ("Lentilles",            .feculents),
            ("Moutarde",             .condiments),
            ("Ketchup",              .condiments),
            ("Sauce soja",           .condiments),
            ("Concentré de tomates", .conserves),
            ("Tomates pelées",       .conserves),
        ]
        gardeManger = classiques.map { ArticleGardeManger(nom: $0.0, categorie: $0.1, enStock: true) }
        sauvegarderGardeManger()
    }

    // MARK: - Garde-Manger persistance

    func sauvegarderGardeManger() {
        if let e = try? JSONEncoder().encode(gardeManger) { UserDefaults.standard.set(e, forKey: "cuisine_gardemanger_v1") }
    }
    func chargerGardeManger() {
        if let d = UserDefaults.standard.data(forKey: "cuisine_gardemanger_v1"),
           let v = try? JSONDecoder().decode([ArticleGardeManger].self, from: d) { gardeManger = v }
    }

    func toggleStock(_ article: ArticleGardeManger) {
        guard let i = gardeManger.firstIndex(where: { $0.id == article.id }) else { return }
        gardeManger[i].enStock.toggle()
        sauvegarderGardeManger()
    }

    func supprimerArticleGardeManger(_ article: ArticleGardeManger) {
        gardeManger.removeAll { $0.id == article.id }
        sauvegarderGardeManger()
    }

    // MARK: - Frigo persistance

    func sauvegarderFrigo() {
        if let e = try? JSONEncoder().encode(frigo) { UserDefaults.standard.set(e, forKey: "cuisine_frigo_v1") }
    }
    func chargerFrigo() {
        if let d = UserDefaults.standard.data(forKey: "cuisine_frigo_v1"),
           let v = try? JSONDecoder().decode([ArticleFrigo].self, from: d) { frigo = v }
    }

    func ajouterAuFrigo(_ nom: String) {
        let n = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        // Évite les doublons
        guard !frigo.contains(where: { normaliserProduit($0.nom) == normaliserProduit(n) }) else { return }
        frigo.append(ArticleFrigo(nom: n))
        sauvegarderFrigo()
    }

    func supprimerDuFrigo(_ article: ArticleFrigo) {
        frigo.removeAll { $0.id == article.id }
        sauvegarderFrigo()
    }

    func viderFrigo() {
        frigo.removeAll()
        sauvegarderFrigo()
    }

    // MARK: - Disponibilité ingrédients

    /// Noms normalisés couverts par le garde-manger EN STOCK
    var nomsGardeMangerEnStock: Set<String> {
        Set(gardeManger.filter { $0.enStock }.map { normaliserProduit($0.nom) })
    }

    /// Noms normalisés des articles du frigo
    var nomsFrigo: Set<String> {
        Set(frigo.map { normaliserProduit($0.nom) })
    }

    /// Un ingrédient est "disponible" s'il est dans le garde-manger EN STOCK ou dans le frigo
    func estDisponible(_ nomIngredient: String) -> Bool {
        let n = normaliserProduit(nomIngredient)
        let dansGardeManger = nomsGardeMangerEnStock.contains { n.contains($0) || $0.contains(n) }
        let dansFrigo       = nomsFrigo.contains              { n.contains($0) || $0.contains(n) }
        return dansGardeManger || dansFrigo
    }

    /// Uniquement garde-manger en stock (pour exclure des courses)
    func estEnStockGardeManger(_ nomIngredient: String) -> Bool {
        let n = normaliserProduit(nomIngredient)
        return nomsGardeMangerEnStock.contains { n.contains($0) || $0.contains(n) }
    }

    // MARK: - Suggestions

    func scoreFaisabilite(_ recette: Recette) -> Double {
        guard !recette.ingredients.isEmpty else { return 1.0 }
        let dispo = recette.ingredients.filter { estDisponible($0.produit) }.count
        return Double(dispo) / Double(recette.ingredients.count)
    }

    func recettesRealisables(seuilMin: Double = 0.5) -> [(recette: Recette, score: Double)] {
        listeRecettes
            .map { ($0, scoreFaisabilite($0)) }
            .filter { $0.1 >= seuilMin }
            .sorted { $0.1 > $1.1 }
    }

    /// Ingrédients manquants (ni garde-manger ni frigo)
    func ingredientsManquants(_ recette: Recette) -> [Ingredient] {
        recette.ingredients.filter { !estDisponible($0.produit) }
    }

    /// Ingrédients couverts par le frigo uniquement
    func ingredientsDuFrigo(_ recette: Recette) -> [Ingredient] {
        recette.ingredients.filter { ing in
            let n = normaliserProduit(ing.produit)
            return nomsFrigo.contains { n.contains($0) || $0.contains(n) }
        }
    }

    // MARK: - Recettes persistance

    func sauvegarderRecettes() {
        if let e = try? JSONEncoder().encode(listeRecettes) { UserDefaults.standard.set(e, forKey: "cuisine_recettes_v6") }
    }
    func chargerRecettes() {
        if let d = UserDefaults.standard.data(forKey: "cuisine_recettes_v6"),
           let v = try? JSONDecoder().decode([Recette].self, from: d) { listeRecettes = v }
    }

    // MARK: - Menu persistance

    func sauvegarderMenu() {
        if let e = try? JSONEncoder().encode(repasPlanifies) { UserDefaults.standard.set(e, forKey: "cuisine_menu_v6") }
    }
    func chargerMenu() {
        if let d = UserDefaults.standard.data(forKey: "cuisine_menu_v6"),
           let v = try? JSONDecoder().decode([PlanificationRepas].self, from: d) { repasPlanifies = v }
    }

    // MARK: - Ingrédients supp & masques

    func sauvegarderIngredientsSupp() { UserDefaults.standard.set(ingredientsSupplementaires, forKey: "cuisine_ing_supp_v6") }
    func chargerIngredientsSupp()     { ingredientsSupplementaires = UserDefaults.standard.stringArray(forKey: "cuisine_ing_supp_v6") ?? [] }

    func sauvegarderIngredientsMasques() { UserDefaults.standard.set(Array(ingredientsMasques), forKey: "cuisine_ing_masques_v6") }
    func chargerIngredientsMasques()     { ingredientsMasques = Set(UserDefaults.standard.stringArray(forKey: "cuisine_ing_masques_v6") ?? []) }

    func reinitialiserFiltreCourses() {
        ingredientsMasques.removeAll()
        sauvegarderIngredientsMasques()
    }

    // MARK: - Liste de courses

    var listeCoursesGeneree: [String] {
        struct Entry { var affiche: String; var unite: String; var qte: Double }
        var cumul: [String: Entry] = [:]

        for plan in repasPlanifies {
            for recette in plan.recettes {
                let facteur = Double(plan.portionsCibles[recette.id] ?? recette.portionsDeBase) / Double(recette.portionsDeBase)
                for ing in recette.ingredients {
                    // Exclut uniquement ce qui est dans le garde-manger EN STOCK
                    // (le frigo ne génère pas d'exclusion courses : c'est ponctuel)
                    guard !estEnStockGardeManger(ing.produit) else { continue }

                    let pn  = normaliserProduit(ing.produit)
                    let un  = ing.unite.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let cle = un.isEmpty ? pn : "\(pn)|\(un)"

                    if cumul[cle] != nil { cumul[cle]!.qte += ing.quantite * facteur }
                    else { cumul[cle] = Entry(affiche: ing.produit.trimmingCharacters(in: .whitespacesAndNewlines).capitalized,
                                              unite: ing.unite.trimmingCharacters(in: .whitespacesAndNewlines),
                                              qte: ing.quantite * facteur) }
                }
            }
        }

        var liste: [String] = cumul.values.map { e in
            let q = e.qte.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", e.qte) : String(format: "%.1f", e.qte)
            if e.qte == 0      { return e.affiche }
            if e.unite.isEmpty { return "\(q) × \(e.affiche)" }
            return "\(q) \(e.unite) \(e.affiche)"
        }

        // Articles du garde-manger EN RUPTURE → courses avec indicateur
        for a in gardeManger where !a.enStock {
            liste.append("🔴 \(a.nom)")
        }

        for s in ingredientsSupplementaires where !s.isEmpty { liste.append(s.capitalized) }

        return liste.filter { !ingredientsMasques.contains($0) }.sorted()
    }

    // MARK: - Export Rappels

    func exporterVersRappelsMac() async -> (succes: Bool, message: String) {
        let accorde: Bool
        if #available(macOS 14.0, *) { accorde = (try? await eventStore.requestFullAccessToReminders()) ?? false }
        else                          { accorde = (try? await eventStore.requestAccess(to: .reminder)) ?? false }
        guard accorde else { return (false, "Accès refusé aux Rappels.") }

        let cal = Calendar.current
        guard let lundi = cal.date(from: cal.dateComponents([.yearForWeekOfYear,.weekOfYear], from: Date()))
        else { return (false, "Erreur calendrier.") }
        let dimanche = cal.date(byAdding: .day, value: 6, to: lundi) ?? Date()
        let fmt = DateFormatter(); fmt.dateFormat = "dd/MM"
        let titre = "🛒 Courses du \(fmt.string(from: lundi)) au \(fmt.string(from: dimanche))"

        var cible: EKCalendar? = eventStore.calendars(for: .reminder).first { $0.title.hasPrefix("🛒 Courses") }
        if let ex = cible {
            let old = await withCheckedContinuation { c in
                eventStore.fetchReminders(matching: eventStore.predicateForReminders(in: [ex])) { c.resume(returning: $0 ?? []) }
            }
            old.forEach { try? eventStore.remove($0, commit: false) }
            ex.title = titre
        } else {
            cible = EKCalendar(for: .reminder, eventStore: eventStore)
            cible?.title = titre; cible?.source = eventStore.defaultCalendarForNewReminders()?.source
            if let c = cible { try? eventStore.saveCalendar(c, commit: false) }
        }
        guard let cal2 = cible else { return (false, "Erreur création liste.") }
        do {
            for ing in listeCoursesGeneree {
                let r = EKReminder(eventStore: eventStore); r.title = ing; r.calendar = cal2
                try eventStore.save(r, commit: false)
            }
            try eventStore.commit()
            return (true, "🚀 Exporté : \(titre)")
        } catch { return (false, "Erreur d'écriture.") }
    }
}

// MARK: - Helper global

func normaliserProduit(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .lowercased()
     .folding(options: .diacriticInsensitive, locale: .current)
}
