import Foundation
import SwiftUI

// MARK: - GitHub Release Model
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

// MARK: - Update Info
struct UpdateInfo {
    let version: String
    let releaseNotes: String
    let downloadUrl: String
    let releaseUrl: String
    let publishedAt: Date
}

// MARK: - Update Checker
@MainActor
class UpdateChecker: ObservableObject {
    // ⚠️ CONFIGURATION - Repository GitHub
    static let githubOwner = "ArnaudGct"
    static let githubRepo = "MediaSync"
    static let currentVersion = "1.0.0"  // Version actuelle de l'app
    
    // URL directe pour les releases
    static var releasesUrl: String {
        "https://github.com/\(githubOwner)/\(githubRepo)/releases"
    }
    
    @Published var updateAvailable: Bool = false
    @Published var latestUpdate: UpdateInfo?
    @Published var isChecking: Bool = false
    @Published var lastCheckDate: Date?
    @Published var errorMessage: String?
    
    // Stockage de la dernière version ignorée
    @AppStorage("ignoredVersion") private var ignoredVersion: String = ""
    @AppStorage("lastUpdateCheck") private var lastUpdateCheckTimestamp: Double = 0
    
    private let checkInterval: TimeInterval = 6 * 60 * 60 // 6 heures (plus fréquent)
    
    init() {
        // Ne pas vérifier automatiquement dans init pour éviter les blocages au démarrage
    }
    
    // MARK: - Public Methods
    
    /// Vérifie les mises à jour si le délai est passé
    func checkForUpdatesIfNeeded() {
        let lastCheck = Date(timeIntervalSince1970: lastUpdateCheckTimestamp)
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        
        if timeSinceLastCheck > checkInterval || lastUpdateCheckTimestamp == 0 {
            Task {
                await checkForUpdates()
            }
        }
    }
    
    /// Force la vérification des mises à jour
    func checkForUpdates() async {
        guard !isChecking else { return }
        
        isChecking = true
        errorMessage = nil
        
        defer {
            isChecking = false
            lastCheckDate = Date()
            lastUpdateCheckTimestamp = Date().timeIntervalSince1970
        }
        
        do {
            let release = try await fetchLatestRelease()
            
            if let release = release {
                // Nettoyer le tag (enlever "v" ou "V" au début)
                let latestVersion = release.tagName
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
                
                print("📦 Version actuelle: \(Self.currentVersion)")
                print("📦 Dernière version GitHub: \(latestVersion)")
                
                if isNewerVersion(latestVersion, than: Self.currentVersion) {
                    // Vérifier si l'utilisateur n'a pas ignoré cette version
                    if latestVersion != ignoredVersion {
                        // Trouver le DMG dans les assets
                        let dmgAsset = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
                        
                        let dateFormatter = ISO8601DateFormatter()
                        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        var publishedDate = dateFormatter.date(from: release.publishedAt)
                        
                        // Fallback sans fractions de secondes
                        if publishedDate == nil {
                            dateFormatter.formatOptions = [.withInternetDateTime]
                            publishedDate = dateFormatter.date(from: release.publishedAt)
                        }
                        
                        latestUpdate = UpdateInfo(
                            version: latestVersion,
                            releaseNotes: release.body,
                            downloadUrl: dmgAsset?.browserDownloadUrl ?? release.htmlUrl,
                            releaseUrl: release.htmlUrl,
                            publishedAt: publishedDate ?? Date()
                        )
                        updateAvailable = true
                        print("✅ Mise à jour disponible: \(latestVersion)")
                    } else {
                        print("⏭️ Version \(latestVersion) ignorée par l'utilisateur")
                    }
                } else {
                    updateAvailable = false
                    latestUpdate = nil
                    print("✅ Application à jour")
                }
            } else {
                print("ℹ️ Aucune release trouvée sur GitHub")
            }
        } catch {
            errorMessage = "Impossible de vérifier les mises à jour"
            print("❌ Erreur de vérification: \(error.localizedDescription)")
        }
    }
    
    /// Ignore la version actuelle
    func ignoreCurrentUpdate() {
        if let update = latestUpdate {
            ignoredVersion = update.version
            updateAvailable = false
            latestUpdate = nil
        }
    }
    
    /// Réinitialise la version ignorée (pour permettre de re-notifier)
    func resetIgnoredVersion() {
        ignoredVersion = ""
    }
    
    /// Ouvre la page de téléchargement
    func openDownloadPage() {
        if let update = latestUpdate, let url = URL(string: update.releaseUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Ouvre la page des releases GitHub
    func openReleasesPage() {
        if let url = URL(string: Self.releasesUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Télécharge directement le DMG
    func downloadUpdate() {
        if let update = latestUpdate, let url = URL(string: update.downloadUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchLatestRelease() async throws -> GitHubRelease? {
        let urlString = "https://api.github.com/repos/\(Self.githubOwner)/\(Self.githubRepo)/releases/latest"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("MediaSync/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // 404 signifie qu'il n'y a pas encore de release
        if httpResponse.statusCode == 404 {
            print("ℹ️ Pas de release sur GitHub (404)")
            return nil
        }
        
        // Rate limiting
        if httpResponse.statusCode == 403 {
            print("⚠️ Rate limit GitHub atteint")
            throw URLError(.userAuthenticationRequired)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("⚠️ Réponse GitHub: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }
    
    /// Compare deux versions (format: MAJOR.MINOR.PATCH)
    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1Part = i < v1Components.count ? v1Components[i] : 0
            let v2Part = i < v2Components.count ? v2Components[i] : 0
            
            if v1Part > v2Part {
                return true
            } else if v1Part < v2Part {
                return false
            }
        }
        
        return false
    }
}

// MARK: - Update Alert View
struct UpdateAlertView: View {
    @ObservedObject var updateChecker: UpdateChecker
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mise à jour disponible")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    if let update = updateChecker.latestUpdate {
                        Text("Version \(update.version)")
                            .font(.system(size: 13))
                            .foregroundColor(.accentGreen)
                    }
                }
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.elevated)
            
            // Release Notes
            if let update = updateChecker.latestUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nouveautés")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    
                    ScrollView {
                        Text(update.releaseNotes.isEmpty ? "Améliorations et corrections de bugs." : update.releaseNotes)
                            .font(.system(size: 12))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.elevated.opacity(0.5))
                )
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: {
                    updateChecker.ignoreCurrentUpdate()
                    isPresented = false
                }) {
                    Text("Ignorer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.elevated)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Plus tard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.elevated)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    updateChecker.downloadUpdate()
                    isPresented = false
                }) {
                    Text("Télécharger")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentGreen)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
}

// MARK: - Update Banner (compact, pour l'interface principale)
struct UpdateBanner: View {
    @ObservedObject var updateChecker: UpdateChecker
    let onTap: () -> Void
    
    var body: some View {
        if updateChecker.updateAvailable, let update = updateChecker.latestUpdate {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Mise à jour disponible")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Version \(update.version)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentGreen, Color.accentGreen.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Check for Updates Button (pour les menus)
struct CheckForUpdatesButton: View {
    @ObservedObject var updateChecker: UpdateChecker
    
    var body: some View {
        Button(action: {
            Task {
                await updateChecker.checkForUpdates()
            }
        }) {
            HStack(spacing: 8) {
                if updateChecker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                
                Text(updateChecker.isChecking ? "Vérification..." : "Rechercher des mises à jour")
            }
        }
        .disabled(updateChecker.isChecking)
    }
}
