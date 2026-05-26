//
//  ContentView.swift
//  StudentHub
//
//  Created by Gauthier Baudelet on 5/26/26.
//

import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable{
    case cours = "Cours"
    case todo = "TO-DO"
    case cuisine = "Cuisine"
    case sport = "Sport"
    
    var id : String {self.rawValue}
    
    var iconName : String {
        switch self {
        case .cours: return "book.closed"
        case .todo : return "checkmark.circle"
        case .cuisine: return "fork.knife"
        case .sport : return "figure.run"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem : NavigationItem? = .cours
    
    var body: some View {
        NavigationSplitView{
            // -- Barre latérale --
            List(NavigationItem.allCases, selection: $selectedItem){
                item in NavigationLink(value : item){
                    Label(item.rawValue, systemImage: item.iconName)
                }
            }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Mon assistant")
            .frame(minWidth : 200)
        } detail : {
            if let item = selectedItem {
                switch item {
                case .cours:
                    GestionCoursView()
                case .todo :
                    Text("Modulo TODO (à venir)")
                case .cuisine:
                    Text("Modulo Cuisine à venir")
                case .sport :
                    Text("Modulo Sport à venir")
                }
            } else {
                Text("Sélectionner un module")
            }
        }
        .frame(minWidth:800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
