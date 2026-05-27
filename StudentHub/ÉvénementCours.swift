//
//  ÉvénementCours.swift
//  StudentHub
//
//  Created by Gauthier Baudelet on 5/26/26.
//


import Foundation

struct ÉvénementCours: Identifiable {
    var id: String
    var code: String
    var titre: String
    var typeGlobal: String // SCOUT, TRAVAIL, DOMICILE, COURS_GENERAL
    var dateDebut: Date
    var dateFin: Date
    var emplacement: String
    var nomCalendrier: String
}
