//
//  ContentView.swift
//  StudentHub
//

import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case accueil    = "Accueil"
    case cours      = "Cours"
    case todo       = "TO-DO"
    case cuisine    = "Cuisine"
    case sport      = "Sport"
    case parametres = "Paramètres"

    var id: String { self.rawValue }

    var iconName: String {
        switch self {
        case .accueil:    return "house"
        case .cours:      return "book.closed"
        case .todo:       return "checkmark.circle"
        case .cuisine:    return "fork.knife"
        case .sport:      return "figure.run"
        case .parametres: return "gearshape"
        }
    }

    var isUtility: Bool { self == .parametres }
}

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .accueil
    @State private var settings = AppSettings()

    // État partagé module Cours
    @State private var niveauActuel: String = UserDefaults.standard.string(forKey: "currentLevel") ?? "BAC1"
    @State private var quadriActuel: String = UserDefaults.standard.string(forKey: "currentQuadrimestre") ?? "Q1"
    @State private var sousOngletCours: String = "gestion"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section {
                    ForEach(NavigationItem.allCases.filter { !$0.isUtility }) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.iconName)
                        }
                    }
                }
                Section {
                    ForEach(NavigationItem.allCases.filter { $0.isUtility }) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.iconName)
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("StudentHub")
            .frame(minWidth: 200)
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 600)
        .tint(settings.accentColor)
        .preferredColorScheme(settings.resolvedColorScheme)
        .environment(settings)
        .onChange(of: settings.currentLevel) { _, val in niveauActuel = val }
        .onChange(of: settings.currentQuadrimestre) { _, val in quadriActuel = val }
    }

    @ViewBuilder
    private var detailView: some View {
        if let item = selectedItem {
            switch item {
            case .accueil:
                HomeView()
            case .cours:
                // Layout deux colonnes sans NavigationSplitView imbriqué
                // pour éviter la colonne vide fantôme
                HSplitView {
                    SousMenuCoursView(
                        niveauActuel: $niveauActuel,
                        quadriActuel: $quadriActuel,
                        sousOngletSelectionne: $sousOngletCours
                    )
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

                    GestionCoursView(
                        niveauActuel: niveauActuel,
                        quadriActuel: quadriActuel,
                        sousOngletSelectionne: $sousOngletCours
                    )
                    .frame(minWidth: 500)
                }
            case .todo:
                TodoView()
            case .cuisine:
                CuisineView()
            case .sport:
                SportView()
            case .parametres:
                SettingsView()
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Sélectionne un module")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
