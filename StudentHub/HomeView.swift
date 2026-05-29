//
//  HomeView.swift
//  StudentHub
//

import SwiftUI

struct HomeView: View {
    @Environment(AppSettings.self) private var settings

    @State private var nbCoursOneDrive: Int = 0
    @State private var nbCMRecuperes: Int = 0
    @State private var nbCMTotal: Int = 0
    @State private var nbTPValides: Int = 0
    @State private var nbTPTotal: Int = 0
    @State private var moyenneGlobale: Double? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greetingHeader
                statsRow
                progressSection
                sessionCard
                Spacer(minLength: 30)
            }
            .padding(32)
        }
        .onAppear { chargerStats() }
        .onChange(of: settings.currentLevel)        { _, _ in chargerStats() }
        .onChange(of: settings.currentQuadrimestre) { _, _ in chargerStats() }
    }

    // MARK: - Greeting

    private var greetingHeader: some View {
        ZStack(alignment: .leading) {
            // Fond gradient si activé
            if settings.useGradient {
                RoundedRectangle(cornerRadius: 16)
                    .fill(settings.theme.gradient)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(settings.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greetingText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                        Text("\(settings.currentLevel) • \(settings.currentQuadrimestre)")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)

                    if !settings.university.isEmpty {
                        Text(settings.university)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
            statCard(value: "\(nbCoursOneDrive)",
                     label: "Cours ce quadri",
                     icon: "book.closed.fill", color: settings.accentColor)
            statCard(value: nbCMTotal > 0 ? "\(nbCMRecuperes)/\(nbCMTotal)" : "–",
                     label: "CM récupérés",
                     icon: "film.stack", color: .orange)
            statCard(value: nbTPTotal > 0 ? "\(nbTPValides)/\(nbTPTotal)" : "–",
                     label: "TP validés",
                     icon: "folder.badge.gearshape", color: .green)
            statCard(value: moyenneGlobale.map { String(format: "%.2f", $0) } ?? "–",
                     label: "Moyenne /20",
                     icon: "chart.bar.fill", color: couleurMoyenne(moyenneGlobale))
        }
    }

    @ViewBuilder
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if settings.useGradient {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                }
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title2.bold())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(settings.useGradient ? AnyShapeStyle(settings.theme.softGradient) : AnyShapeStyle(Color(.windowBackgroundColor).opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        if nbCMTotal > 0 || nbTPTotal > 0 {
            VStack(alignment: .leading, spacing: 14) {
                Text("Avancement global").font(.title3.bold())
                if nbCMTotal > 0 {
                    progressRow(label: "Cours Magistraux",
                                current: nbCMRecuperes, total: nbCMTotal, color: .orange)
                }
                if nbTPTotal > 0 {
                    progressRow(label: "Travaux Pratiques",
                                current: nbTPValides, total: nbTPTotal, color: .green)
                }
            }
            .padding(20)
            .background(settings.useGradient ? AnyShapeStyle(settings.theme.softGradient) : AnyShapeStyle(Color(.windowBackgroundColor).opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(settings.accentColor.opacity(0.08), lineWidth: 1))
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
                infoTile(icon: "building.columns", title: "Université",
                         value: settings.university.isEmpty ? "–" : settings.university)
                Divider().frame(height: 44).padding(.horizontal, 16)
                infoTile(icon: "graduationcap", title: "Niveau",      value: settings.currentLevel)
                Divider().frame(height: 44).padding(.horizontal, 16)
                infoTile(icon: "calendar",       title: "Quadrimestre", value: settings.currentQuadrimestre)
                Divider().frame(height: 44).padding(.horizontal, 16)
                infoTile(icon: "folder.fill",    title: "Cours actifs", value: "\(nbCoursOneDrive)")
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

            var totalCM = 0, recuperesCM = 0
            var totalTP = 0, validesTP = 0
            var sommeMoyennes = 0.0
            var nbMoyennes = 0

            for dossier in cours {
                let code = dossier.components(separatedBy: "-").first ?? ""
                guard !code.isEmpty else { continue }

                // ── FIX : lecture des valeurs persistées pour la période courante ──
                let cleTP = "nb_tp_\(niveau)_\(quadri)_\(code)"
                let cleCM = "nb_cm_\(niveau)_\(quadri)_\(code)"
                let nbCM = UserDefaults.standard.object(forKey: cleCM) != nil
                    ? UserDefaults.standard.integer(forKey: cleCM) : 0
                let nbTP = UserDefaults.standard.object(forKey: cleTP) != nil
                    ? UserDefaults.standard.integer(forKey: cleTP) : 0
                totalCM += nbCM
                totalTP += nbTP

                let cheminCM = "\(chemin)\(dossier)/\(code)-CM"
                let ssCM = (try? FileManager.default.contentsOfDirectory(atPath: cheminCM)) ?? []
                recuperesCM += ssCM.filter { $0.hasPrefix("\(code)-CM-") }.count

                let cheminTP = "\(chemin)\(dossier)/\(code)-TP"
                let ssTP = (try? FileManager.default.contentsOfDirectory(atPath: cheminTP)) ?? []
                validesTP += ssTP.filter { $0.hasPrefix("\(code)-TP-") }.count

                // Moyenne du cours
                let info = CourseCreditStore.shared.moyennePour(code)
                if let moy = info.moyenne {
                    sommeMoyennes += moy
                    nbMoyennes += 1
                }
            }

            DispatchQueue.main.async {
                self.nbCoursOneDrive = cours.count
                self.nbCMTotal       = totalCM
                self.nbCMRecuperes   = recuperesCM
                self.nbTPTotal       = totalTP
                self.nbTPValides     = validesTP
                self.moyenneGlobale  = nbMoyennes > 0 ? sommeMoyennes / Double(nbMoyennes) : nil
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

    private func couleurMoyenne(_ moy: Double?) -> Color {
        guard let m = moy else { return .secondary }
        switch m {
        case 14...: return .green
        case 10..<14: return .orange
        default: return .red
        }
    }
}

#Preview {
    HomeView()
        .environment(AppSettings())
        .frame(width: 800, height: 600)
}
