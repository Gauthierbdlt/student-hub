//
//  HomeView.swift
//  StudentHub
//

import SwiftUI

struct HomeView: View {
    @Environment(AppSettings.self) private var settings

    // Stats lues depuis les vraies sources
    @State private var nbCoursOneDrive: Int = 0
    @State private var nbCMRecuperes: Int = 0
    @State private var nbCMTotal: Int = 0
    @State private var nbTPValides: Int = 0
    @State private var nbTPTotal: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                greetingHeader
                statsRow
                progressSection
                sessionCard
                Spacer(minLength: 30)
            }
            .padding(32)
        }
        .onAppear { chargerStats() }
        .onChange(of: settings.currentLevel)         { _, _ in chargerStats() }
        .onChange(of: settings.currentQuadrimestre)  { _, _ in chargerStats() }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.system(size: 34, weight: .bold))
                Text(formattedDate)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            Spacer()
            // Badge session
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                    Text("\(settings.currentLevel) • \(settings.currentQuadrimestre)")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())

                if !settings.university.isEmpty {
                    Text(settings.university)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
            statCard(
                value: "\(nbCoursOneDrive)",
                label: "Cours ce quadri",
                icon: "book.closed.fill",
                color: .blue
            )
            statCard(
                value: nbCMTotal > 0 ? "\(nbCMRecuperes)/\(nbCMTotal)" : "–",
                label: "CM récupérés",
                icon: "film.stack",
                color: .orange
            )
            statCard(
                value: nbTPTotal > 0 ? "\(nbTPValides)/\(nbTPTotal)" : "–",
                label: "TP validés",
                icon: "folder.badge.gearshape",
                color: .green
            )
            statCard(
                value: settings.stravaConnected ? "Actif" : "—",
                label: "Strava",
                icon: "figure.run",
                color: .red
            )
        }
    }

    @ViewBuilder
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Progress bars

    @ViewBuilder
    private var progressSection: some View {
        if nbCMTotal > 0 || nbTPTotal > 0 {
            VStack(alignment: .leading, spacing: 14) {
                Text("Avancement global")
                    .font(.title3.bold())

                if nbCMTotal > 0 {
                    progressRow(
                        label: "Cours Magistraux",
                        current: nbCMRecuperes, total: nbCMTotal,
                        color: .orange
                    )
                }
                if nbTPTotal > 0 {
                    progressRow(
                        label: "Travaux Pratiques",
                        current: nbTPValides, total: nbTPTotal,
                        color: .green
                    )
                }
            }
            .padding(20)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func progressRow(label: String, current: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(current) / \(total)")
                    .font(.caption.bold())
                    .foregroundStyle(current == total ? .green : color)
            }
            ProgressView(value: Double(current), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .tint(current == total ? .green : color)
        }
    }

    // MARK: - Session card

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session en cours").font(.title3.bold())

            HStack(spacing: 0) {
                infoTile(icon: "building.columns",  title: "Université",    value: settings.university.isEmpty ? "–" : settings.university)
                Divider().frame(height: 44).padding(.horizontal, 16)
                infoTile(icon: "graduationcap",     title: "Niveau",        value: settings.currentLevel)
                Divider().frame(height: 44).padding(.horizontal, 16)
                infoTile(icon: "calendar",          title: "Quadrimestre",  value: settings.currentQuadrimestre)
                Divider().frame(height: 44).padding(.horizontal, 16)
                infoTile(icon: "folder.fill",       title: "Cours actifs",  value: "\(nbCoursOneDrive)")
                Spacer()
            }
        }
        .padding(20)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func infoTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }

    // MARK: - Data loading

    private func chargerStats() {
        let niveau = settings.currentLevel
        let quadri = settings.currentQuadrimestre
        let basePath = settings.oneDrivePath

        DispatchQueue.global(qos: .userInitiated).async {
            let chemin = "\(basePath)\(niveau)/\(quadri)/"
            let dossiers = (try? FileManager.default.contentsOfDirectory(atPath: chemin)) ?? []
            let cours = dossiers.filter {
                !$0.hasPrefix(".") && !$0.lowercased().contains("icon") &&
                ($0.components(separatedBy: "-").first?.count ?? 0) >= 4
            }

            // Pour chaque cours, sommer CM et TP depuis UserDefaults
            var totalCM = 0, recuperesCM = 0
            var totalTP = 0, validesTP = 0

            for dossier in cours {
                let code = dossier.components(separatedBy: "-").first ?? ""
                guard !code.isEmpty else { continue }

                let nbCM = UserDefaults.standard.integer(forKey: "nb_cm_\(niveau)_\(quadri)_\(code)")
                let nbTP = UserDefaults.standard.integer(forKey: "nb_tp_\(niveau)_\(quadri)_\(code)")
                totalCM += nbCM
                totalTP += nbTP

                // Compter les sous-dossiers CM existants
                let cheminCM = "\(chemin)\(dossier)/\(code)-CM"
                let ssCM = (try? FileManager.default.contentsOfDirectory(atPath: cheminCM)) ?? []
                recuperesCM += ssCM.filter { $0.hasPrefix("\(code)-CM-") }.count

                // Compter les sous-dossiers TP existants
                let cheminTP = "\(chemin)\(dossier)/\(code)-TP"
                let ssTP = (try? FileManager.default.contentsOfDirectory(atPath: cheminTP)) ?? []
                validesTP += ssTP.filter { $0.hasPrefix("\(code)-TP-") }.count
            }

            DispatchQueue.main.async {
                self.nbCoursOneDrive = cours.count
                self.nbCMTotal       = totalCM
                self.nbCMRecuperes   = recuperesCM
                self.nbTPTotal       = totalTP
                self.nbTPValides     = validesTP
            }
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prenom = settings.studentName.components(separatedBy: " ").first ?? ""
        let suffix = prenom.isEmpty ? "" : ", \(prenom)"
        switch hour {
        case 5..<12:  return "Bonjour\(suffix) 👋"
        case 12..<18: return "Bon après-midi\(suffix) 👋"
        default:      return "Bonsoir\(suffix) 👋"
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.dateFormat = "EEEE d MMMM yyyy"
        return f.string(from: Date()).capitalized
    }
}

#Preview {
    HomeView()
        .environment(AppSettings())
        .frame(width: 800, height: 600)
}
