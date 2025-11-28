import Foundation
import Combine
import AppKit
import ScreenCaptureKit

// MARK: - Detection Mode
enum DetectionMode: String, CaseIterable {
    case pmset = "pmset"
    case audio = "audio"
    
    var displayName: String {
        switch self {
        case .pmset: return "Système"
        case .audio: return "Audio"
        }
    }
}

// MARK: - Browser Tab Info
struct BrowserTab: Identifiable, Hashable {
    let id: String  // Unique identifier (domain)
    let domain: String
    let title: String
    var isEnabled: Bool
    var isPlaying: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

class MdiaSyncMonitor: ObservableObject {
    @Published var isRunning = false
    @Published var isPremiereActive = false
    @Published var isResolveActive = false
    @Published var isAfterEffectsActive = false
    @Published var isSpotifyPlaying = false
    @Published var isAppleMusicPlaying = false
    @Published var isBravePlaying = false
    @Published var isChromePlaying = false
    @Published var isEdgePlaying = false
    @Published var isOperaPlaying = false
    @Published var isArcPlaying = false
    @Published var isSafariPlaying = false
    @Published var activeApp: String = ""
    @Published var hasScreenCapturePermission = false
    @Published var hasBrowserJSPermission = false  // Pour vérifier si "Allow JavaScript from Apple Events" est activé
    
    // MARK: - App Enable/Disable Settings (persistés)
    @Published var isPremiereEnabled: Bool {
        didSet { UserDefaults.standard.set(isPremiereEnabled, forKey: "isPremiereEnabled") }
    }
    @Published var isResolveEnabled: Bool {
        didSet { UserDefaults.standard.set(isResolveEnabled, forKey: "isResolveEnabled") }
    }
    @Published var isAfterEffectsEnabled: Bool {
        didSet { UserDefaults.standard.set(isAfterEffectsEnabled, forKey: "isAfterEffectsEnabled") }
    }
    @Published var isSpotifyEnabled: Bool {
        didSet { UserDefaults.standard.set(isSpotifyEnabled, forKey: "isSpotifyEnabled") }
    }
    @Published var isAppleMusicEnabled: Bool {
        didSet { UserDefaults.standard.set(isAppleMusicEnabled, forKey: "isAppleMusicEnabled") }
    }
    @Published var isBraveEnabled: Bool {
        didSet { UserDefaults.standard.set(isBraveEnabled, forKey: "isBraveEnabled") }
    }
    @Published var isChromeEnabled: Bool {
        didSet { UserDefaults.standard.set(isChromeEnabled, forKey: "isChromeEnabled") }
    }
    @Published var isEdgeEnabled: Bool {
        didSet { UserDefaults.standard.set(isEdgeEnabled, forKey: "isEdgeEnabled") }
    }
    @Published var isOperaEnabled: Bool {
        didSet { UserDefaults.standard.set(isOperaEnabled, forKey: "isOperaEnabled") }
    }
    @Published var isArcEnabled: Bool {
        didSet { UserDefaults.standard.set(isArcEnabled, forKey: "isArcEnabled") }
    }
    @Published var isSafariEnabled: Bool {
        didSet { UserDefaults.standard.set(isSafariEnabled, forKey: "isSafariEnabled") }
    }
    
    // MARK: - Browser Tabs Management
    @Published var browserTabs: [BrowserTab] = []  // Onglets de tous les navigateurs
    @Published var enabledDomains: Set<String> {  // Domaines autorisés pour la gestion
        didSet {
            let array = Array(enabledDomains)
            UserDefaults.standard.set(array, forKey: "enabledBrowserDomains")
        }
    }
    
    // MARK: - Detection Mode Settings (persistés)
    @Published var premiereDetectionMode: DetectionMode {
        didSet { UserDefaults.standard.set(premiereDetectionMode.rawValue, forKey: "premiereDetectionMode") }
    }
    @Published var resolveDetectionMode: DetectionMode {
        didSet { UserDefaults.standard.set(resolveDetectionMode.rawValue, forKey: "resolveDetectionMode") }
    }
    // After Effects utilise uniquement le mode audio (pmset ne fonctionne pas)
    
    var resumeDelay: Double = 1.0
    
    private var monitorQueue = DispatchQueue(label: "com.mediasync.monitor", qos: .userInteractive)
    private var isChecking = false
    
    // Audio Capture Managers pour chaque app
    private var afterEffectsAudioManager: AudioCaptureManager?
    private var premiereAudioManager: AudioCaptureManager?
    private var resolveAudioManager: AudioCaptureManager?
    
    private var audioCaptureObservers: [AnyCancellable] = []
    
    // Track which music apps were playing before pause
    private var spotifyWasPlaying = false
    private var appleMusicWasPlaying = false
    private var braveWasPlaying = false
    private var chromeWasPlaying = false
    private var edgeWasPlaying = false
    private var operaWasPlaying = false
    private var arcWasPlaying = false
    private var safariWasPlaying = false
    
    private var silenceStartTime: Date?
    private var timer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // Charger les préférences sauvegardées
        isPremiereEnabled = UserDefaults.standard.object(forKey: "isPremiereEnabled") as? Bool ?? true
        isResolveEnabled = UserDefaults.standard.object(forKey: "isResolveEnabled") as? Bool ?? true
        isAfterEffectsEnabled = UserDefaults.standard.object(forKey: "isAfterEffectsEnabled") as? Bool ?? true
        isSpotifyEnabled = UserDefaults.standard.object(forKey: "isSpotifyEnabled") as? Bool ?? true
        isAppleMusicEnabled = UserDefaults.standard.object(forKey: "isAppleMusicEnabled") as? Bool ?? true
        
        // Navigateurs
        isBraveEnabled = UserDefaults.standard.object(forKey: "isBraveEnabled") as? Bool ?? false
        isChromeEnabled = UserDefaults.standard.object(forKey: "isChromeEnabled") as? Bool ?? false
        isEdgeEnabled = UserDefaults.standard.object(forKey: "isEdgeEnabled") as? Bool ?? false
        isOperaEnabled = UserDefaults.standard.object(forKey: "isOperaEnabled") as? Bool ?? false
        isArcEnabled = UserDefaults.standard.object(forKey: "isArcEnabled") as? Bool ?? false
        isSafariEnabled = UserDefaults.standard.object(forKey: "isSafariEnabled") as? Bool ?? false
        
        // Charger les domaines autorisés (par défaut: youtube, spotify web, soundcloud, deezer)
        if let savedDomains = UserDefaults.standard.array(forKey: "enabledBrowserDomains") as? [String] {
            enabledDomains = Set(savedDomains)
        } else {
            enabledDomains = Set(["youtube.com", "music.youtube.com", "open.spotify.com", "soundcloud.com", "deezer.com", "music.apple.com"])
        }
        
        let premiereMode = UserDefaults.standard.string(forKey: "premiereDetectionMode") ?? "pmset"
        premiereDetectionMode = DetectionMode(rawValue: premiereMode) ?? .pmset
        
        let resolveMode = UserDefaults.standard.string(forKey: "resolveDetectionMode") ?? "pmset"
        resolveDetectionMode = DetectionMode(rawValue: resolveMode) ?? .pmset
        
        // Charger l'état de permission JS navigateur sauvegardé
        hasBrowserJSPermission = UserDefaults.standard.bool(forKey: "hasBrowserJSPermission")
        
        // Charger l'état de permission Screen Capture sauvegardé
        hasScreenCapturePermission = UserDefaults.standard.bool(forKey: "screenCapturePermissionGranted")
        
        setupAudioCaptureManagers()
    }
    
    private func setupAudioCaptureManagers() {
        if #available(macOS 13.0, *) {
            // After Effects Audio Manager
            afterEffectsAudioManager = AudioCaptureManager(appIdentifier: "com.adobe.AfterEffects", appName: "After Effects")
            
            // Premiere Pro Audio Manager
            premiereAudioManager = AudioCaptureManager(appIdentifier: "com.adobe.PremierePro", appName: "Adobe Premiere Pro")
            
            // DaVinci Resolve Audio Manager
            resolveAudioManager = AudioCaptureManager(appIdentifier: "com.blackmagic-design.DaVinciResolve", appName: "DaVinci Resolve")
            
            // Observer After Effects
            if let manager = afterEffectsAudioManager {
                manager.$isAppPlaying
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] isPlaying in
                        if self?.isAfterEffectsEnabled == true {
                            self?.isAfterEffectsActive = isPlaying
                        }
                    }
                    .store(in: &audioCaptureObservers)
                
                manager.$hasPermission
                    .receive(on: DispatchQueue.main)
                    .assign(to: &$hasScreenCapturePermission)
            }
            
            // Observer Premiere (pour mode audio)
            if let manager = premiereAudioManager {
                manager.$isAppPlaying
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] isPlaying in
                        guard let self = self else { return }
                        if self.isPremiereEnabled && self.premiereDetectionMode == .audio {
                            self.isPremiereActive = isPlaying
                        }
                    }
                    .store(in: &audioCaptureObservers)
            }
            
            // Observer Resolve (pour mode audio)
            if let manager = resolveAudioManager {
                manager.$isAppPlaying
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] isPlaying in
                        guard let self = self else { return }
                        if self.isResolveEnabled && self.resolveDetectionMode == .audio {
                            self.isResolveActive = isPlaying
                        }
                    }
                    .store(in: &audioCaptureObservers)
            }
        }
    }
    
    /// Demande la permission d'enregistrement d'écran
    func requestScreenCapturePermission() {
        if #available(macOS 13.0, *) {
            afterEffectsAudioManager?.openScreenRecordingPreferences()
        }
    }
    
    /// Ouvre les préférences système pour la permission d'enregistrement d'écran
    func openScreenRecordingPreferences() {
        if #available(macOS 13.0, *) {
            afterEffectsAudioManager?.openScreenRecordingPreferences()
        }
    }
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // Démarrer la capture audio pour After Effects (toujours en mode audio)
        if #available(macOS 13.0, *) {
            if isAfterEffectsEnabled {
                afterEffectsAudioManager?.startMonitoring()
            }
            // Démarrer la capture audio pour Premiere si en mode audio
            if isPremiereEnabled && premiereDetectionMode == .audio {
                premiereAudioManager?.startMonitoring()
            }
            // Démarrer la capture audio pour Resolve si en mode audio
            if isResolveEnabled && resolveDetectionMode == .audio {
                resolveAudioManager?.startMonitoring()
            }
        }
        
        // Timer plus rapide pour une meilleure réactivité
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.triggerCheck()
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        silenceStartTime = nil
        
        // Arrêter tous les audio managers
        if #available(macOS 13.0, *) {
            afterEffectsAudioManager?.stopMonitoring()
            premiereAudioManager?.stopMonitoring()
            resolveAudioManager?.stopMonitoring()
        }
        
        DispatchQueue.main.async {
            self.isPremiereActive = false
            self.isResolveActive = false
            self.isAfterEffectsActive = false
            self.isSpotifyPlaying = false
            self.isAppleMusicPlaying = false
            self.activeApp = ""
        }
    }
    
    // MARK: - Toggle App Methods
    
    func togglePremiere() {
        isPremiereEnabled.toggle()
        if !isPremiereEnabled {
            isPremiereActive = false
        }
    }
    
    func toggleResolve() {
        isResolveEnabled.toggle()
        if !isResolveEnabled {
            isResolveActive = false
        }
    }
    
    func toggleAfterEffects() {
        isAfterEffectsEnabled.toggle()
        if !isAfterEffectsEnabled {
            isAfterEffectsActive = false
            if #available(macOS 13.0, *) {
                afterEffectsAudioManager?.stopMonitoring()
            }
        } else if isRunning {
            if #available(macOS 13.0, *) {
                afterEffectsAudioManager?.startMonitoring()
            }
        }
    }
    
    func toggleSpotify() {
        isSpotifyEnabled.toggle()
    }
    
    func toggleAppleMusic() {
        isAppleMusicEnabled.toggle()
    }
    
    func toggleBrave() {
        isBraveEnabled.toggle()
    }
    
    func toggleChrome() {
        isChromeEnabled.toggle()
    }
    
    func toggleEdge() {
        isEdgeEnabled.toggle()
    }
    
    func toggleOpera() {
        isOperaEnabled.toggle()
    }
    
    func toggleArc() {
        isArcEnabled.toggle()
    }
    
    func toggleSafari() {
        isSafariEnabled.toggle()
    }
    
    /// Ouvre les préférences développeur d'un navigateur pour activer JavaScript from Apple Events
    func openBrowserDevSettings(browser: Browser) {
        if browser == .safari {
            // Pour Safari, ouvrir les préférences et afficher les instructions
            let script = """
            tell application "Safari"
                activate
            end tell
            delay 0.5
            tell application "System Events"
                tell process "Safari"
                    -- Essayer d'ouvrir les préférences via le menu
                    try
                        click menu item "Settings…" of menu "Safari" of menu bar 1
                    on error
                        try
                            click menu item "Preferences…" of menu "Safari" of menu bar 1
                        end try
                    end try
                end tell
            end tell
            """
            _ = runAppleScript(script)
        } else {
            let script = """
            tell application "\(browser.appName)"
                activate
            end tell
            """
            _ = runAppleScript(script)
        }
    }
    
    /// Vérifie si Safari a les permissions JavaScript activées
    func checkSafariJSPermission() -> Bool {
        let script = """
        tell application "Safari"
            try
                set t to current tab of front window
                set jsResult to do JavaScript "true" in t
                return "ok"
            on error
                return "no"
            end try
        end tell
        """
        let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result == "ok"
    }
    
    // MARK: - Browser Tabs Management
    
    /// Rafraîchit la liste des onglets avec des médias dans tous les navigateurs activés
    func refreshBrowserTabs() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allTabs: [BrowserTab] = []
            
            // Récupérer les onglets de chaque navigateur Chromium activé
            let chromiumBrowsers: [(Browser, Bool)] = [
                (.brave, self.isBraveEnabled),
                (.chrome, self.isChromeEnabled),
                (.edge, self.isEdgeEnabled),
                (.opera, self.isOperaEnabled),
                (.arc, self.isArcEnabled)
            ]
            
            for (browser, isEnabled) in chromiumBrowsers {
                if isEnabled {
                    let tabs = self.fetchChromiumTabsWithMedia(browser: browser)
                    allTabs.append(contentsOf: tabs)
                }
            }
            
            // Safari
            if self.isSafariEnabled {
                let safariTabs = self.fetchSafariTabsWithMedia()
                allTabs.append(contentsOf: safariTabs)
            }
            
            DispatchQueue.main.async {
                // Mettre à jour la liste en préservant l'état enabled des domaines existants
                // Dédupliquer par domaine
                var uniqueDomains = Set<String>()
                self.browserTabs = allTabs.compactMap { tab in
                    guard !uniqueDomains.contains(tab.domain) else { return nil }
                    uniqueDomains.insert(tab.domain)
                    var updatedTab = tab
                    updatedTab.isEnabled = self.enabledDomains.contains(tab.domain)
                    return updatedTab
                }
            }
        }
    }
    
    /// Active ou désactive un domaine
    func toggleDomain(_ domain: String) {
        if enabledDomains.contains(domain) {
            enabledDomains.remove(domain)
        } else {
            enabledDomains.insert(domain)
        }
        
        // Mettre à jour l'état des onglets
        for i in browserTabs.indices {
            if browserTabs[i].domain == domain {
                browserTabs[i].isEnabled = enabledDomains.contains(domain)
            }
        }
    }
    
    /// Récupère tous les onglets d'un navigateur Chromium qui ont des éléments média
    private func fetchChromiumTabsWithMedia(browser: Browser) -> [BrowserTab] {
        let script = """
        tell application "System Events"
            if not (exists process "\(browser.processName)") then return ""
        end tell
        
        tell application "\(browser.appName)"
            set tabInfoList to ""
            try
                set windowList to every window
                repeat with w in windowList
                    set tabList to every tab of w
                    repeat with t in tabList
                        try
                            tell t
                                set tabURL to URL
                                set tabTitle to title
                                set hasMedia to execute javascript "(function() { return document.querySelectorAll('video, audio').length > 0 ? 'yes' : 'no'; })()"
                                set isPlaying to execute javascript "(function() { var m = document.querySelectorAll('video, audio'); for (var i = 0; i < m.length; i++) { if (!m[i].paused && !m[i].ended) return 'yes'; } return 'no'; })()"
                                if hasMedia is "yes" then
                                    set tabInfoList to tabInfoList & tabURL & "|||" & tabTitle & "|||" & isPlaying & "\\n"
                                end if
                            end tell
                        end try
                    end repeat
                end repeat
            end try
            return tabInfoList
        end tell
        """
        
        guard let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            return []
        }
        
        return parseTabsFromResult(result)
    }
    
    /// Récupère tous les onglets Safari qui ont des éléments média
    private func fetchSafariTabsWithMedia() -> [BrowserTab] {
        let script = """
        tell application "System Events"
            if not (exists process "Safari") then return ""
        end tell
        
        tell application "Safari"
            set tabInfoList to ""
            try
                set windowList to every window
                repeat with w in windowList
                    set tabList to every tab of w
                    repeat with t in tabList
                        try
                            set tabURL to URL of t
                            set tabTitle to name of t
                            set hasMedia to do JavaScript "(function() { return document.querySelectorAll('video, audio').length > 0 ? 'yes' : 'no'; })()" in t
                            set isPlaying to do JavaScript "(function() { var m = document.querySelectorAll('video, audio'); for (var i = 0; i < m.length; i++) { if (!m[i].paused && !m[i].ended) return 'yes'; } return 'no'; })()" in t
                            if hasMedia is "yes" then
                                set tabInfoList to tabInfoList & tabURL & "|||" & tabTitle & "|||" & isPlaying & "\\n"
                            end if
                        end try
                    end repeat
                end repeat
            end try
            return tabInfoList
        end tell
        """
        
        guard let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            return []
        }
        
        return parseTabsFromResult(result)
    }
    
    /// Parse les résultats d'onglets en BrowserTab
    private func parseTabsFromResult(_ result: String) -> [BrowserTab] {
        var tabs: [BrowserTab] = []
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let parts = line.components(separatedBy: "|||")
            if parts.count >= 3 {
                let url = parts[0]
                let title = parts[1]
                let isPlaying = parts[2] == "yes"
                
                // Extraire le domaine de l'URL
                if let urlObj = URL(string: url), let host = urlObj.host {
                    // Simplifier le domaine (enlever www.)
                    let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                    
                    // Éviter les doublons de domaine
                    if !tabs.contains(where: { $0.domain == domain }) {
                        let tab = BrowserTab(
                            id: domain,
                            domain: domain,
                            title: title,
                            isEnabled: enabledDomains.contains(domain),
                            isPlaying: isPlaying
                        )
                        tabs.append(tab)
                    }
                }
            }
        }
        
        return tabs
    }
    
    // MARK: - Detection Mode Methods
    
    func setPremiereDetectionMode(_ mode: DetectionMode) {
        premiereDetectionMode = mode
        if isRunning {
            if #available(macOS 13.0, *) {
                if mode == .audio {
                    premiereAudioManager?.startMonitoring()
                } else {
                    premiereAudioManager?.stopMonitoring()
                }
            }
        }
    }
    
    func setResolveDetectionMode(_ mode: DetectionMode) {
        resolveDetectionMode = mode
        if isRunning {
            if #available(macOS 13.0, *) {
                if mode == .audio {
                    resolveAudioManager?.startMonitoring()
                } else {
                    resolveAudioManager?.stopMonitoring()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func triggerCheck() {
        // Éviter les vérifications concurrentes
        guard !isChecking else { return }
        isChecking = true
        
        // Exécuter les vérifications en parallèle sur un thread séparé
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Vérifications en parallèle
            var premiereActive = false
            var resolveActive = false
            var spotifyPlaying = false
            var appleMusicPlaying = false
            var bravePlaying = false
            var chromePlaying = false
            var edgePlaying = false
            var operaPlaying = false
            var arcPlaying = false
            var safariPlaying = false
            
            // After Effects est toujours géré par AudioCaptureManager
            let afterEffectsActive = self.isAfterEffectsEnabled ? self.isAfterEffectsActive : false
            
            let group = DispatchGroup()
            
            // Check Premiere Pro (selon le mode de détection)
            if self.isPremiereEnabled && self.premiereDetectionMode == .pmset {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    premiereActive = self.checkPmsetAssertion(for: "Adobe Premiere")
                    group.leave()
                }
            } else if self.isPremiereEnabled && self.premiereDetectionMode == .audio {
                // Le mode audio est géré par l'observer, on récupère juste la valeur actuelle
                premiereActive = self.isPremiereActive
            }
            
            // Check DaVinci Resolve (selon le mode de détection)
            if self.isResolveEnabled && self.resolveDetectionMode == .pmset {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    resolveActive = self.checkPmsetAssertion(for: "DaVinci Resolve")
                    group.leave()
                }
            } else if self.isResolveEnabled && self.resolveDetectionMode == .audio {
                resolveActive = self.isResolveActive
            }
            
            // Check music players in parallel (seulement si activés)
            if self.isSpotifyEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    spotifyPlaying = self.checkMusicPlayerStatus(app: .spotify)
                    group.leave()
                }
            }
            
            if self.isAppleMusicEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    appleMusicPlaying = self.checkMusicPlayerStatus(app: .appleMusic)
                    group.leave()
                }
            }
            
            // Check all browsers in parallel
            if self.isBraveEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    bravePlaying = self.checkBrowserMediaStatus(browser: .brave)
                    group.leave()
                }
            }
            
            if self.isChromeEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    chromePlaying = self.checkBrowserMediaStatus(browser: .chrome)
                    group.leave()
                }
            }
            
            if self.isEdgeEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    edgePlaying = self.checkBrowserMediaStatus(browser: .edge)
                    group.leave()
                }
            }
            
            if self.isOperaEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    operaPlaying = self.checkBrowserMediaStatus(browser: .opera)
                    group.leave()
                }
            }
            
            if self.isArcEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    arcPlaying = self.checkBrowserMediaStatus(browser: .arc)
                    group.leave()
                }
            }
            
            if self.isSafariEnabled {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    safariPlaying = self.checkBrowserMediaStatus(browser: .safari)
                    group.leave()
                }
            }
            
            group.wait()
            
            // Déterminer quelle app de montage est active
            let editingAppActive = premiereActive || resolveActive || afterEffectsActive
            let currentActiveApp: String
            if premiereActive {
                currentActiveApp = "Premiere"
            } else if resolveActive {
                currentActiveApp = "Resolve"
            } else if afterEffectsActive {
                currentActiveApp = "After Effects"
            } else {
                currentActiveApp = ""
            }
            
            // Mise à jour UI immédiate
            DispatchQueue.main.async {
                // Mettre à jour seulement si en mode pmset (sinon c'est l'observer qui gère)
                if self.isPremiereEnabled && self.premiereDetectionMode == .pmset {
                    self.isPremiereActive = premiereActive
                } else if !self.isPremiereEnabled {
                    self.isPremiereActive = false
                }
                
                if self.isResolveEnabled && self.resolveDetectionMode == .pmset {
                    self.isResolveActive = resolveActive
                } else if !self.isResolveEnabled {
                    self.isResolveActive = false
                }
                
                self.isSpotifyPlaying = self.isSpotifyEnabled ? spotifyPlaying : false
                self.isAppleMusicPlaying = self.isAppleMusicEnabled ? appleMusicPlaying : false
                self.isBravePlaying = self.isBraveEnabled ? bravePlaying : false
                self.isChromePlaying = self.isChromeEnabled ? chromePlaying : false
                self.isEdgePlaying = self.isEdgeEnabled ? edgePlaying : false
                self.isOperaPlaying = self.isOperaEnabled ? operaPlaying : false
                self.isArcPlaying = self.isArcEnabled ? arcPlaying : false
                self.isSafariPlaying = self.isSafariEnabled ? safariPlaying : false
                self.activeApp = currentActiveApp
            }
            
            // Calculer si un navigateur joue de la musique
            let anyBrowserPlaying = bravePlaying || chromePlaying || edgePlaying || operaPlaying || arcPlaying || safariPlaying
            
            // Logique de contrôle des lecteurs de musique
            if editingAppActive {
                self.silenceStartTime = nil
                
                // Pause les apps de musique activées
                if self.isSpotifyEnabled && spotifyPlaying {
                    self.controlMusicPlayer(app: .spotify, action: "pause")
                    self.spotifyWasPlaying = true
                }
                if self.isAppleMusicEnabled && appleMusicPlaying {
                    self.controlMusicPlayer(app: .appleMusic, action: "pause")
                    self.appleMusicWasPlaying = true
                }
                
                // Pause tous les navigateurs activés
                if self.isBraveEnabled && bravePlaying {
                    self.controlBrowserMedia(browser: .brave, action: .pause)
                    self.braveWasPlaying = true
                }
                if self.isChromeEnabled && chromePlaying {
                    self.controlBrowserMedia(browser: .chrome, action: .pause)
                    self.chromeWasPlaying = true
                }
                if self.isEdgeEnabled && edgePlaying {
                    self.controlBrowserMedia(browser: .edge, action: .pause)
                    self.edgeWasPlaying = true
                }
                if self.isOperaEnabled && operaPlaying {
                    self.controlBrowserMedia(browser: .opera, action: .pause)
                    self.operaWasPlaying = true
                }
                if self.isArcEnabled && arcPlaying {
                    self.controlBrowserMedia(browser: .arc, action: .pause)
                    self.arcWasPlaying = true
                }
                if self.isSafariEnabled && safariPlaying {
                    self.controlBrowserMedia(browser: .safari, action: .pause)
                    self.safariWasPlaying = true
                }
            } else {
                // Resume logic
                let anyMusicPlaying = (self.isSpotifyEnabled && spotifyPlaying) || (self.isAppleMusicEnabled && appleMusicPlaying) || anyBrowserPlaying
                let anyWasPlaying = self.spotifyWasPlaying || self.appleMusicWasPlaying || self.braveWasPlaying || self.chromeWasPlaying || self.edgeWasPlaying || self.operaWasPlaying || self.arcWasPlaying || self.safariWasPlaying
                
                if anyWasPlaying && !anyMusicPlaying {
                    if self.silenceStartTime == nil {
                        self.silenceStartTime = Date()
                    }
                    
                    if let startTime = self.silenceStartTime,
                       Date().timeIntervalSince(startTime) >= self.resumeDelay {
                        // Resume apps that were playing
                        if self.spotifyWasPlaying && self.isSpotifyEnabled {
                            self.controlMusicPlayer(app: .spotify, action: "play")
                            self.spotifyWasPlaying = false
                        }
                        if self.appleMusicWasPlaying && self.isAppleMusicEnabled {
                            self.controlMusicPlayer(app: .appleMusic, action: "play")
                            self.appleMusicWasPlaying = false
                        }
                        
                        // Resume tous les navigateurs
                        if self.braveWasPlaying && self.isBraveEnabled {
                            self.controlBrowserMedia(browser: .brave, action: .play)
                            self.braveWasPlaying = false
                        }
                        if self.chromeWasPlaying && self.isChromeEnabled {
                            self.controlBrowserMedia(browser: .chrome, action: .play)
                            self.chromeWasPlaying = false
                        }
                        if self.edgeWasPlaying && self.isEdgeEnabled {
                            self.controlBrowserMedia(browser: .edge, action: .play)
                            self.edgeWasPlaying = false
                        }
                        if self.operaWasPlaying && self.isOperaEnabled {
                            self.controlBrowserMedia(browser: .opera, action: .play)
                            self.operaWasPlaying = false
                        }
                        if self.arcWasPlaying && self.isArcEnabled {
                            self.controlBrowserMedia(browser: .arc, action: .play)
                            self.arcWasPlaying = false
                        }
                        if self.safariWasPlaying && self.isSafariEnabled {
                            self.controlBrowserMedia(browser: .safari, action: .play)
                            self.safariWasPlaying = false
                        }
                        self.silenceStartTime = nil
                    }
                } else if anyMusicPlaying {
                    self.spotifyWasPlaying = false
                    self.appleMusicWasPlaying = false
                    self.braveWasPlaying = false
                    self.chromeWasPlaying = false
                    self.edgeWasPlaying = false
                    self.operaWasPlaying = false
                    self.arcWasPlaying = false
                    self.safariWasPlaying = false
                    self.silenceStartTime = nil
                }
            }
            
            self.isChecking = false
        }
    }
    
    // MARK: - Music Player Types
    
    enum MusicPlayer {
        case spotify
        case appleMusic
        
        var processName: String {
            switch self {
            case .spotify: return "Spotify"
            case .appleMusic: return "Music"
            }
        }
        
        var appName: String {
            switch self {
            case .spotify: return "Spotify"
            case .appleMusic: return "Music"
            }
        }
    }
    
    private func checkPmsetAssertion(for appName: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pmset -g assertions"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains(appName) && output.contains("PreventUserIdleDisplaySleep") {
                    return true
                }
            }
        } catch {
            // Silently fail
        }
        
        return false
    }
    
    private func checkMusicPlayerStatus(app: MusicPlayer) -> Bool {
        let script = """
            tell application "System Events"
                if not (exists process "\(app.processName)") then
                    return "not_running"
                end if
            end tell
            tell application "\(app.appName)"
                return player state as string
            end tell
        """
        
        let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return result == "playing"
    }
    
    private func controlMusicPlayer(app: MusicPlayer, action: String) {
        let script = """
            tell application "\(app.appName)"
                \(action)
            end tell
        """
        _ = runAppleScript(script)
    }
    
    private func runAppleScript(_ script: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    // MARK: - Browser Types
    
    enum Browser: CaseIterable {
        case brave
        case chrome
        case edge
        case opera
        case arc
        case safari
        
        var appName: String {
            switch self {
            case .brave: return "Brave Browser"
            case .chrome: return "Google Chrome"
            case .edge: return "Microsoft Edge"
            case .opera: return "Opera"
            case .arc: return "Arc"
            case .safari: return "Safari"
            }
        }
        
        var processName: String {
            switch self {
            case .brave: return "Brave Browser"
            case .chrome: return "Google Chrome"
            case .edge: return "Microsoft Edge"
            case .opera: return "Opera"
            case .arc: return "Arc"
            case .safari: return "Safari"
            }
        }
        
        var isChromium: Bool {
            switch self {
            case .safari: return false
            default: return true
            }
        }
        
        var displayName: String {
            switch self {
            case .brave: return "Brave"
            case .chrome: return "Chrome"
            case .edge: return "Edge"
            case .opera: return "Opera"
            case .arc: return "Arc"
            case .safari: return "Safari"
            }
        }
    }
    
    enum BrowserMediaAction {
        case pause
        case play
    }
    
    /// Construit une liste de domaines autorisés pour le JavaScript
    private func buildEnabledDomainsJS() -> String {
        let domains = enabledDomains.map { "'\($0)'" }.joined(separator: ",")
        return "[\(domains)]"
    }
    
    /// Vérifie si un média joue dans un navigateur (seulement sur les domaines autorisés)
    private func checkBrowserMediaStatus(browser: Browser) -> Bool {
        // D'abord vérifier si le navigateur est lancé
        let checkRunning = """
        tell application "System Events"
            return exists process "\(browser.processName)"
        end tell
        """
        
        guard let isRunning = runAppleScript(checkRunning)?.trimmingCharacters(in: .whitespacesAndNewlines),
              isRunning == "true" else {
            return false
        }
        
        let enabledDomainsJS = buildEnabledDomainsJS()
        let result: String?
        
        if browser.isChromium {
            // Navigateurs Chromium (Brave, Chrome, Edge, Opera, Arc)
            let script = """
            tell application "\(browser.appName)"
                set mediaPlaying to false
                try
                    set windowList to every window
                    repeat with w in windowList
                        set tabList to every tab of w
                        repeat with t in tabList
                            try
                                tell t
                                    set tabURL to URL
                                    set checkResult to execute javascript "(function() { var dominated = \(enabledDomainsJS); var host = window.location.hostname.replace('www.', ''); var isAllowed = dominated.some(function(d) { return host.indexOf(d) !== -1; }); if (!isAllowed) return 'skip'; var m = document.querySelectorAll('video, audio'); for (var i = 0; i < m.length; i++) { if (!m[i].paused && !m[i].ended) return 'playing'; } return 'no'; })()"
                                    if checkResult is "playing" then
                                        set mediaPlaying to true
                                        exit repeat
                                    end if
                                end tell
                            end try
                        end repeat
                        if mediaPlaying then exit repeat
                    end repeat
                end try
                return mediaPlaying
            end tell
            """
            result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Safari - syntaxe différente
            let script = """
            tell application "Safari"
                set mediaPlaying to false
                try
                    set windowList to every window
                    repeat with w in windowList
                        set tabList to every tab of w
                        repeat with t in tabList
                            try
                                set tabURL to URL of t
                                set checkResult to do JavaScript "(function() { var dominated = \(enabledDomainsJS); var host = window.location.hostname.replace('www.', ''); var isAllowed = dominated.some(function(d) { return host.indexOf(d) !== -1; }); if (!isAllowed) return 'skip'; var m = document.querySelectorAll('video, audio'); for (var i = 0; i < m.length; i++) { if (!m[i].paused && !m[i].ended) return 'playing'; } return 'no'; })()" in t
                                if checkResult is "playing" then
                                    set mediaPlaying to true
                                    exit repeat
                                end if
                            end try
                        end repeat
                        if mediaPlaying then exit repeat
                    end repeat
                end try
                return mediaPlaying
            end tell
            """
            result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Si on obtient une réponse valide, la permission JS est accordée
        if result == "true" || result == "false" {
            DispatchQueue.main.async {
                self.hasBrowserJSPermission = true
                UserDefaults.standard.set(true, forKey: "hasBrowserJSPermission")
            }
        }
        
        return result == "true"
    }
    
    /// Contrôle la lecture média dans un navigateur (seulement sur les domaines autorisés)
    private func controlBrowserMedia(browser: Browser, action: BrowserMediaAction) {
        let jsAction = action == .pause ? "pause()" : "play()"
        let enabledDomainsJS = buildEnabledDomainsJS()
        
        if browser.isChromium {
            // Navigateurs Chromium
            let script = """
            tell application "\(browser.appName)"
                try
                    set windowList to every window
                    repeat with w in windowList
                        set tabList to every tab of w
                        repeat with t in tabList
                            try
                                tell t
                                    execute javascript "(function() { var dominated = \(enabledDomainsJS); var host = window.location.hostname.replace('www.', ''); var isAllowed = dominated.some(function(d) { return host.indexOf(d) !== -1; }); if (!isAllowed) return; document.querySelectorAll('video, audio').forEach(function(e) { e.\(jsAction); }); })()"
                                end tell
                            end try
                        end repeat
                    end repeat
                end try
            end tell
            """
            _ = runAppleScript(script)
        } else {
            // Safari
            let script = """
            tell application "Safari"
                try
                    set windowList to every window
                    repeat with w in windowList
                        set tabList to every tab of w
                        repeat with t in tabList
                            try
                                do JavaScript "(function() { var dominated = \(enabledDomainsJS); var host = window.location.hostname.replace('www.', ''); var isAllowed = dominated.some(function(d) { return host.indexOf(d) !== -1; }); if (!isAllowed) return; document.querySelectorAll('video, audio').forEach(function(e) { e.\(jsAction); }); })()" in t
                            end try
                        end repeat
                    end repeat
                end try
            end tell
            """
            _ = runAppleScript(script)
        }
    }
}
