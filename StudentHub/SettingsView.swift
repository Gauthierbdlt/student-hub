//
//  SettingsView.swift
//  StudentHub
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var studentName         = ""
    @State private var university          = ""
    @State private var oneDrivePath        = ""
    @State private var stravaClientId      = ""
    @State private var selectedThemeId     = "bleu"
    @State private var useGradient         = true
    @State private var colorScheme         = "Système"
    @State private var currentLevel        = "BAC1"
    @State private var currentQuadrimestre = "Q1"
    @State private var saveConfirmation    = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                profilSection
                apparenceSection
                oneDriveSection
                stravaSection
                saveButton
            }
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paramètres")
                    .font(.largeTitle.bold())
                Text("Personnalisez StudentHub selon vos besoins.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    // MARK: - Profil

    private var profilSection: some View {
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
                .pickerStyle(.menu).frame(width: 120)
            }
            row(label: "Quadrimestre en cours") {
                Picker("", selection: $currentQuadrimestre) {
                    ForEach(AppSettings.quadOptions, id: \.self) { Text($0) }
                }
                .pickerStyle(.radioGroup)
            }
        }
    }

    // MARK: - Apparence

    private var apparenceSection: some View {
        settingsSection(title: "Apparence", icon: "paintbrush") {
            VStack(alignment: .leading, spacing: 16) {

                // -- Thème couleur --
                VStack(alignment: .leading, spacing: 10) {
                    Text("Thème de couleur")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(ThemeCouleur.catalogue) { theme in
                            ThemeCardView(
                                theme: theme,
                                isSelected: selectedThemeId == theme.id,
                                useGradient: useGradient
                            ) {
                                selectedThemeId = theme.id
                            }
                        }
                    }
                }

                Divider()

                // -- Option gradient --
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Utiliser les dégradés")
                            .font(.subheadline)
                        Text("Applique un gradient de couleur sur les cartes et l'en-tête.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $useGradient)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider()

                // -- Mode clair/sombre --
                row(label: "Thème clair/sombre") {
                    Picker("", selection: $colorScheme) {
                        ForEach(AppSettings.schemeOptions, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
        }
    }

    // MARK: - OneDrive

    private var oneDriveSection: some View {
        settingsSection(title: "OneDrive", icon: "cloud") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chemin du dossier racine OneDrive")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("Chemin absolu…", text: $oneDrivePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button { chooseFolder() } label: { Image(systemName: "folder") }
                        .help("Choisir un dossier…")
                }
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
    }

    // MARK: - Strava

    private var stravaSection: some View {
        settingsSection(title: "Strava", icon: "figure.run") {
            VStack(alignment: .leading, spacing: 12) {
                stravaStatusBadge
                if settings.stravaConnected {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("Compte connecté — Athlete ID : \(settings.stravaAthleteId)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Déconnecter", role: .destructive) {
                            settings.stravaConnected = false
                            settings.stravaAthleteId = ""
                        }.buttonStyle(.bordered)
                    }
                } else {
                    row(label: "Client ID") {
                        TextField("Votre Strava Client ID", text: $stravaClientId)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                    }
                    Text("Obtenez votre Client ID sur [strava.com/settings/api](https://www.strava.com/settings/api)")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { initiateStravaOAuth() } label: {
                        Label("Connecter Strava", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(stravaClientId.isEmpty)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        HStack {
            Spacer()
            if saveConfirmation {
                Label("Sauvegardé ✓", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
            Button(action: saveSettings) {
                Label("Enregistrer les modifications", systemImage: "checkmark")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 30)
    }

    // MARK: - Composants

    private var stravaStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(settings.stravaConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(settings.stravaConnected ? "Connecté" : "Non connecté")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String, icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.title3.bold())
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

    // MARK: - Actions

    private func loadSettings() {
        studentName         = settings.studentName
        university          = settings.university
        oneDrivePath        = settings.oneDrivePath
        stravaClientId      = settings.stravaClientId
        selectedThemeId     = settings.themeId
        useGradient         = settings.useGradient
        colorScheme         = settings.colorSchemePreference
        currentLevel        = settings.currentLevel
        currentQuadrimestre = settings.currentQuadrimestre
    }

    private func saveSettings() {
        settings.studentName           = studentName
        settings.university            = university
        settings.oneDrivePath          = oneDrivePath
        settings.stravaClientId        = stravaClientId
        settings.themeId               = selectedThemeId
        settings.useGradient           = useGradient
        settings.colorSchemePreference = colorScheme
        settings.currentLevel          = currentLevel
        settings.currentQuadrimestre   = currentQuadrimestre
        withAnimation { saveConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saveConfirmation = false }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choisir le dossier OneDrive"
        if panel.runModal() == .OK, let url = panel.url {
            oneDrivePath = url.path + "/"
        }
    }

    private func initiateStravaOAuth() {
        settings.stravaClientId = stravaClientId
        let alert = NSAlert()
        alert.messageText = "Connexion Strava"
        alert.informativeText = "Le Client ID a été sauvegardé. La connexion OAuth complète sera activée depuis l'onglet Sport."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - ThemeCardView

struct ThemeCardView: View {
    let theme: ThemeCouleur
    let isSelected: Bool
    let useGradient: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Aperçu du gradient/couleur
                ZStack {
                    if useGradient {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.gradient)
                            .frame(width: 36, height: 36)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.base)
                            .frame(width: 36, height: 36)
                    }
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }

                Text(theme.nom)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? (useGradient ? AnyShapeStyle(theme.softGradient) : AnyShapeStyle(theme.base.opacity(0.12)))
                    : AnyShapeStyle(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.base : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
        .frame(width: 800, height: 700)
}
