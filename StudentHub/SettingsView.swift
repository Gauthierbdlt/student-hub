//
//  SettingsView.swift
//  StudentHub
//
//  Panneau de préférences : apparence, OneDrive, Strava, profil étudiant.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    // Binding helpers (nécessaires car @Observable n'expose pas de Binding automatique)
    @State private var studentName        = ""
    @State private var university         = ""
    @State private var oneDrivePath       = ""
    @State private var stravaClientId     = ""
    @State private var accentColorName    = "Bleu"
    @State private var colorScheme        = "Système"
    @State private var currentLevel       = "BAC1"
    @State private var currentQuadrimestre = "Q1"

    @State private var showPathPicker     = false
    @State private var saveConfirmation   = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── En-tête ──────────────────────────────────────────────
                headerSection

                // ── Profil ───────────────────────────────────────────────
                settingsSection(title: "Profil étudiant", icon: "person.circle") {
                    row(label: "Prénom / Nom") {
                        TextField("ex : Gauthier Baudelet", text: $studentName)
                            .textFieldStyle(.roundedBorder)
                    }
                    row(label: "Université") {
                        TextField("ex : UCLouvain", text: $university)
                            .textFieldStyle(.roundedBorder)
                    }
                    row(label: "Niveau actuel") {
                        Picker("", selection: $currentLevel) {
                            ForEach(AppSettings.levelOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    row(label: "Quadrimestre en cours") {
                        Picker("", selection: $currentQuadrimestre) {
                            ForEach(AppSettings.quadOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.radioGroup)
                    }
                }

                // ── Apparence ────────────────────────────────────────────
                settingsSection(title: "Apparence", icon: "paintbrush") {
                    row(label: "Couleur d'accent") {
                        HStack(spacing: 10) {
                            ForEach(AppSettings.accentOptions, id: \.self) { name in
                                colorDot(name: name)
                            }
                        }
                    }
                    row(label: "Thème") {
                        Picker("", selection: $colorScheme) {
                            ForEach(AppSettings.schemeOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }
                }

                // ── OneDrive ─────────────────────────────────────────────
                settingsSection(title: "OneDrive", icon: "cloud") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chemin du dossier racine OneDrive")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("Chemin absolu…", text: $oneDrivePath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Button {
                                chooseFolder()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .help("Choisir un dossier…")
                        }
                        // Vérification visuelle
                        let exists = FileManager.default.fileExists(atPath: oneDrivePath)
                        Label(
                            exists ? "Dossier trouvé ✓" : "Dossier introuvable",
                            systemImage: exists ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(exists ? .green : .red)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }

                // ── Strava ───────────────────────────────────────────────
                settingsSection(title: "Strava", icon: "figure.run") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image("strava-logo")      // Asset optionnel
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .opacity(0)           // Masqué si asset absent
                            stravaStatusBadge
                        }

                        if settings.stravaConnected {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Compte connecté — Athlete ID : \(settings.stravaAthleteId)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Déconnecter", role: .destructive) {
                                    settings.stravaConnected = false
                                    settings.stravaAthleteId = ""
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            row(label: "Client ID") {
                                TextField("Votre Strava Client ID", text: $stravaClientId)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 220)
                            }
                            Text("Obtenez votre Client ID sur [strava.com/settings/api](https://www.strava.com/settings/api)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                initiateStravaOAuth()
                            } label: {
                                Label("Connecter Strava", systemImage: "link")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(stravaClientId.isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Bouton Enregistrer ────────────────────────────────────
                HStack {
                    Spacer()
                    Button(action: saveSettings) {
                        Label("Enregistrer les modifications", systemImage: "checkmark")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                    if saveConfirmation {
                        Text("Sauvegardé ✓")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .onAppear(perform: loadSettings)
    }

    // MARK: - Sub-views

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Paramètres")
                .font(.largeTitle).bold()
            Text("Personnalisez StudentHub selon vos besoins.")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }

    private var stravaStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(settings.stravaConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(settings.stravaConnected ? "Connecté" : "Non connecté")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.title3).bold()
                .padding(.bottom, 2)

            content()
        }
        .padding(20)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 30)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .frame(width: 200, alignment: .leading)
                .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func colorDot(name: String) -> some View {
        let color: Color = {
            switch name {
            case "Rouge":   return .red
            case "Vert":    return .green
            case "Orange":  return .orange
            case "Violet":  return .purple
            case "Rose":    return .pink
            case "Jaune":   return .yellow
            default:        return .blue
            }
        }()
        Button {
            accentColorName = name
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 26, height: 26)
                if accentColorName == name {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }

    // MARK: - Actions

    private func loadSettings() {
        studentName         = settings.studentName
        university          = settings.university
        oneDrivePath        = settings.oneDrivePath
        stravaClientId      = settings.stravaClientId
        accentColorName     = settings.accentColorName
        colorScheme         = settings.colorSchemePreference
        currentLevel        = settings.currentLevel
        currentQuadrimestre = settings.currentQuadrimestre
    }

    private func saveSettings() {
        settings.studentName           = studentName
        settings.university            = university
        settings.oneDrivePath          = oneDrivePath
        settings.stravaClientId        = stravaClientId
        settings.accentColorName       = accentColorName
        settings.colorSchemePreference = colorScheme
        settings.currentLevel          = currentLevel
        settings.currentQuadrimestre   = currentQuadrimestre

        withAnimation {
            saveConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saveConfirmation = false }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles       = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choisir le dossier OneDrive"
        if panel.runModal() == .OK, let url = panel.url {
            oneDrivePath = url.path + "/"
        }
    }

    private func initiateStravaOAuth() {
        // OAuth Strava — nécessite un redirect URI enregistré dans l'app.
        // Implémentation complète dans SportView quand le module Strava sera actif.
        // Pour l'instant on sauvegarde le client ID et on informe l'utilisateur.
        settings.stravaClientId = stravaClientId
        let alert = NSAlert()
        alert.messageText     = "Connexion Strava"
        alert.informativeText = "Le Client ID a été sauvegardé. La connexion OAuth complète sera activée depuis l'onglet Sport."
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
        .frame(width: 800, height: 700)
}
