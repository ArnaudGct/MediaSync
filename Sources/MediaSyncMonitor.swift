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
    let id: String  // Unique identifier: "browser:windowIndex:tabIndex"
    let browser: String
    let windowIndex: Int
    let tabIndex: Int
    let url: String
    let domain: String
    let title: String
    var isPlaying: Bool
    var isAudible: Bool  // Si l'onglet émet du son (pour Chromium)
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

class MediaSyncMonitor: ObservableObject {
    @Published var isRunning = false
    @Published var isPremiereActive = false
    @Published var isResolveActive = false
    @Published var isFinalCutActive = false
    @Published var isAfterEffectsActive = false
    @Published var isSpotifyPlaying = false
    @Published var isAppleMusicPlaying = false
    @Published var activeApp: String = ""
    @Published var hasScreenCapturePermission = false
    @Published var hasBrowserJSPermission = false
    
    // Navigateurs - état de lecture détecté
    @Published var isBravePlaying = false
    @Published var isChromePlaying = false
    @Published var isEdgePlaying = false
    @Published var isOperaPlaying = false
    @Published var isArcPlaying = false
    @Published var isSafariPlaying = false
    
    // MARK: - App Enable/Disable Settings (persistés)
    @Published var isPremiereEnabled: Bool {
        didSet { UserDefaults.standard.set(isPremiereEnabled, forKey: "isPremiereEnabled") }
    }
    @Published var isResolveEnabled: Bool {
        didSet { UserDefaults.standard.set(isResolveEnabled, forKey: "isResolveEnabled") }
    }
    @Published var isFinalCutEnabled: Bool {
        didSet { UserDefaults.standard.set(isFinalCutEnabled, forKey: "isFinalCutEnabled") }
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
    @Published var playingTabs: [BrowserTab] = []  // Onglets actuellement en lecture
    @Published var enabledDomains: Set<String> {
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
    @Published var finalCutDetectionMode: DetectionMode {
        didSet { UserDefaults.standard.set(finalCutDetectionMode.rawValue, forKey: "finalCutDetectionMode") }
    }
    
    var resumeDelay: Double = 1.0
    
    private var monitorQueue = DispatchQueue(label: "com.mediasync.monitor", qos: .userInteractive)
    private var isChecking = false
    
    // Audio Capture Managers pour chaque app
    private var afterEffectsAudioManager: AudioCaptureManager?
    private var premiereAudioManager: AudioCaptureManager?
    private var resolveAudioManager: AudioCaptureManager?
    private var finalCutAudioManager: AudioCaptureManager?
    
    private var audioCaptureObservers: [AnyCancellable] = []
    
    // Track which apps were playing before pause
    private var spotifyWasPlaying = false
    private var appleMusicWasPlaying = false
    
    // Track paused browser tabs (by their unique ID)
    private var pausedBrowserTabs: Set<String> = []
    
    private var silenceStartTime: Date?
    private var timer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // Charger les préférences sauvegardées
        isPremiereEnabled = UserDefaults.standard.object(forKey: "isPremiereEnabled") as? Bool ?? true
        isResolveEnabled = UserDefaults.standard.object(forKey: "isResolveEnabled") as? Bool ?? true
        isFinalCutEnabled = UserDefaults.standard.object(forKey: "isFinalCutEnabled") as? Bool ?? true
        isAfterEffectsEnabled = UserDefaults.standard.object(forKey: "isAfterEffectsEnabled") as? Bool ?? true
        isSpotifyEnabled = UserDefaults.standard.object(forKey: "isSpotifyEnabled") as? Bool ?? true
        isAppleMusicEnabled = UserDefaults.standard.object(forKey: "isAppleMusicEnabled") as? Bool ?? true
        
        // Navigateurs - activés par défaut pour que la détection fonctionne immédiatement
        isBraveEnabled = UserDefaults.standard.object(forKey: "isBraveEnabled") as? Bool ?? true
        isChromeEnabled = UserDefaults.standard.object(forKey: "isChromeEnabled") as? Bool ?? true
        isEdgeEnabled = UserDefaults.standard.object(forKey: "isEdgeEnabled") as? Bool ?? true
        isOperaEnabled = UserDefaults.standard.object(forKey: "isOperaEnabled") as? Bool ?? true
        isArcEnabled = UserDefaults.standard.object(forKey: "isArcEnabled") as? Bool ?? true
        isSafariEnabled = UserDefaults.standard.object(forKey: "isSafariEnabled") as? Bool ?? true
        
        // Charger les domaines autorisés
        if let savedDomains = UserDefaults.standard.array(forKey: "enabledBrowserDomains") as? [String] {
            enabledDomains = Set(savedDomains)
        } else {
            // Domaines par défaut : streaming musical et vidéo populaires
            enabledDomains = Set([
                "youtube.com",
                "music.youtube.com",
                "open.spotify.com",
                "soundcloud.com",
                "deezer.com",
                "music.apple.com",
                "artlist.io",
                "bandcamp.com",
                "tidal.com",
                "vimeo.com",
                "twitch.tv",
                "dailymotion.com"
            ])
        }
        
        let premiereMode = UserDefaults.standard.string(forKey: "premiereDetectionMode") ?? "pmset"
        premiereDetectionMode = DetectionMode(rawValue: premiereMode) ?? .pmset
        
        let resolveMode = UserDefaults.standard.string(forKey: "resolveDetectionMode") ?? "pmset"
        resolveDetectionMode = DetectionMode(rawValue: resolveMode) ?? .pmset
        
        let finalCutMode = UserDefaults.standard.string(forKey: "finalCutDetectionMode") ?? "pmset"
        finalCutDetectionMode = DetectionMode(rawValue: finalCutMode) ?? .pmset
        
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
            
            // Final Cut Pro Audio Manager
            finalCutAudioManager = AudioCaptureManager(appIdentifier: "com.apple.FinalCut", appName: "Final Cut Pro")
            
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
            
            // Observer Final Cut Pro (pour mode audio)
            if let manager = finalCutAudioManager {
                manager.$isAppPlaying
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] isPlaying in
                        guard let self = self else { return }
                        if self.isFinalCutEnabled && self.finalCutDetectionMode == .audio {
                            self.isFinalCutActive = isPlaying
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
            // Démarrer la capture audio pour Final Cut Pro si en mode audio
            if isFinalCutEnabled && finalCutDetectionMode == .audio {
                finalCutAudioManager?.startMonitoring()
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
            finalCutAudioManager?.stopMonitoring()
        }
        
        DispatchQueue.main.async {
            self.isPremiereActive = false
            self.isResolveActive = false
            self.isFinalCutActive = false
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
    
    func toggleFinalCut() {
        isFinalCutEnabled.toggle()
        if !isFinalCutEnabled {
            isFinalCutActive = false
            if #available(macOS 13.0, *) {
                finalCutAudioManager?.stopMonitoring()
            }
        } else if isRunning {
            if #available(macOS 13.0, *) {
                if finalCutDetectionMode == .audio {
                    finalCutAudioManager?.startMonitoring()
                }
            }
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
        let script = """
        tell application "\(browser.appName)"
            activate
        end tell
        """
        _ = runAppleScript(script)
    }
    
    /// Vérifie si un navigateur a les permissions JavaScript activées
    func checkBrowserJSPermission(browser: Browser) -> Bool {
        let jsTest = "true"
        
        if browser == .safari {
            let script = """
            tell application "System Events"
                if not (exists process "Safari") then return "not_running"
            end tell
            tell application "Safari"
                try
                    if (count of windows) is 0 then return "no_window"
                    if (count of tabs of front window) is 0 then return "no_tab"
                    set jsResult to do JavaScript "\(jsTest)" in current tab of front window
                    return "ok"
                on error errMsg
                    return "error:" & errMsg
                end try
            end tell
            """
            let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result == "ok"
        } else {
            let script = """
            tell application "System Events"
                if not (exists process "\(browser.processName)") then return "not_running"
            end tell
            tell application "\(browser.appName)"
                try
                    if (count of windows) is 0 then return "no_window"
                    set w to front window
                    if (count of tabs of w) is 0 then return "no_tab"
                    tell active tab of w
                        set jsResult to execute javascript "\(jsTest)"
                    end tell
                    return "ok"
                on error errMsg
                    return "error:" & errMsg
                end try
            end tell
            """
            let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result == "ok"
        }
    }
    
    // MARK: - Browser Tabs Management
    
    /// Rafraîchit la liste des onglets en lecture
    func refreshPlayingTabs() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allPlayingTabs: [BrowserTab] = []
            var browserStates: [Browser: Bool] = [:]
            
            // Récupérer les onglets de chaque navigateur activé
            if self.isSafariEnabled {
                let tabs = self.getPlayingTabsFromSafari()
                allPlayingTabs.append(contentsOf: tabs)
                browserStates[.safari] = !tabs.isEmpty
            }
            
            let chromiumBrowsers: [(Browser, Bool)] = [
                (.brave, self.isBraveEnabled),
                (.chrome, self.isChromeEnabled),
                (.edge, self.isEdgeEnabled),
                (.opera, self.isOperaEnabled),
                (.arc, self.isArcEnabled)
            ]
            
            for (browser, isEnabled) in chromiumBrowsers {
                if isEnabled {
                    let tabs = self.getPlayingTabsFromChromium(browser: browser)
                    allPlayingTabs.append(contentsOf: tabs)
                    browserStates[browser] = !tabs.isEmpty
                }
            }
            
            DispatchQueue.main.async {
                self.playingTabs = allPlayingTabs
                
                // Mettre à jour les états de lecture des navigateurs
                self.isSafariPlaying = browserStates[.safari] ?? false
                self.isBravePlaying = browserStates[.brave] ?? false
                self.isChromePlaying = browserStates[.chrome] ?? false
                self.isEdgePlaying = browserStates[.edge] ?? false
                self.isOperaPlaying = browserStates[.opera] ?? false
                self.isArcPlaying = browserStates[.arc] ?? false
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
    }
    
    /// Vérifie si un domaine est autorisé (match partiel)
    private func isDomainEnabled(_ host: String) -> Bool {
        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return enabledDomains.contains { enabledDomain in
            normalizedHost.contains(enabledDomain) || enabledDomain.contains(normalizedHost)
        }
    }
    
    /// Extrait le domaine d'une URL
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
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
    
    func setFinalCutDetectionMode(_ mode: DetectionMode) {
        finalCutDetectionMode = mode
        if isRunning {
            if #available(macOS 13.0, *) {
                if mode == .audio {
                    finalCutAudioManager?.startMonitoring()
                } else {
                    finalCutAudioManager?.stopMonitoring()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func triggerCheck() {
        // Éviter les vérifications concurrentes
        guard !isChecking else { return }
        isChecking = true
        
        // Exécuter les vérifications sur un thread séparé
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            
            var premiereActive = false
            var resolveActive = false
            var finalCutActive = false
            var spotifyPlaying = false
            var appleMusicPlaying = false
            
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
            
            // Check Final Cut Pro (selon le mode de détection)
            if self.isFinalCutEnabled && self.finalCutDetectionMode == .pmset {
                group.enter()
                DispatchQueue.global(qos: .userInteractive).async {
                    finalCutActive = self.checkPmsetAssertion(for: "Final Cut Pro")
                    group.leave()
                }
            } else if self.isFinalCutEnabled && self.finalCutDetectionMode == .audio {
                finalCutActive = self.isFinalCutActive
            }
            
            // Check music players
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
            
            // Check browsers playing status (en parallèle)
            var browserPlayingStatus: [Browser: Bool] = [:]
            let browserGroup = DispatchGroup()
            let statusLock = NSLock()
            
            let browsersToCheck: [(Browser, Bool)] = [
                (.safari, self.isSafariEnabled),
                (.brave, self.isBraveEnabled),
                (.chrome, self.isChromeEnabled),
                (.edge, self.isEdgeEnabled),
                (.opera, self.isOperaEnabled),
                (.arc, self.isArcEnabled)
            ]
            
            for (browser, isEnabled) in browsersToCheck {
                if isEnabled {
                    browserGroup.enter()
                    DispatchQueue.global(qos: .userInteractive).async {
                        let isPlaying = self.checkBrowserHasPlayingMedia(browser: browser)
                        statusLock.lock()
                        browserPlayingStatus[browser] = isPlaying
                        statusLock.unlock()
                        browserGroup.leave()
                    }
                }
            }
            
            group.wait()
            browserGroup.wait()
            
            // Déterminer quelle app de montage est active
            let editingAppActive = premiereActive || resolveActive || finalCutActive || afterEffectsActive
            let currentActiveApp: String
            if premiereActive {
                currentActiveApp = "Premiere"
            } else if resolveActive {
                currentActiveApp = "Resolve"
            } else if finalCutActive {
                currentActiveApp = "Final Cut Pro"
            } else if afterEffectsActive {
                currentActiveApp = "After Effects"
            } else {
                currentActiveApp = ""
            }
            
            // Mise à jour UI
            DispatchQueue.main.async {
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
                
                if self.isFinalCutEnabled && self.finalCutDetectionMode == .pmset {
                    self.isFinalCutActive = finalCutActive
                } else if !self.isFinalCutEnabled {
                    self.isFinalCutActive = false
                }
                
                self.isSpotifyPlaying = self.isSpotifyEnabled ? spotifyPlaying : false
                self.isAppleMusicPlaying = self.isAppleMusicEnabled ? appleMusicPlaying : false
                
                // Update browser playing states
                self.isSafariPlaying = browserPlayingStatus[.safari] ?? false
                self.isBravePlaying = browserPlayingStatus[.brave] ?? false
                self.isChromePlaying = browserPlayingStatus[.chrome] ?? false
                self.isEdgePlaying = browserPlayingStatus[.edge] ?? false
                self.isOperaPlaying = browserPlayingStatus[.opera] ?? false
                self.isArcPlaying = browserPlayingStatus[.arc] ?? false
                
                self.activeApp = currentActiveApp
            }
            
            // Calculer si un navigateur joue de la musique
            let anyBrowserPlaying = browserPlayingStatus.values.contains(true)
            
            // Logique de contrôle
            if editingAppActive {
                self.silenceStartTime = nil
                
                // Pause Spotify si activé et en lecture
                if self.isSpotifyEnabled && spotifyPlaying {
                    self.controlMusicPlayer(app: .spotify, action: "pause")
                    self.spotifyWasPlaying = true
                }
                
                // Pause Apple Music si activé et en lecture
                if self.isAppleMusicEnabled && appleMusicPlaying {
                    self.controlMusicPlayer(app: .appleMusic, action: "pause")
                    self.appleMusicWasPlaying = true
                }
                
                // Pause tous les navigateurs avec des médias en lecture
                if anyBrowserPlaying {
                    self.pauseAllBrowserTabs()
                }
                
            } else {
                // Resume logic
                let anyMusicPlaying = (self.isSpotifyEnabled && spotifyPlaying) || 
                                      (self.isAppleMusicEnabled && appleMusicPlaying) || 
                                      anyBrowserPlaying
                let anyWasPlaying = self.spotifyWasPlaying || 
                                    self.appleMusicWasPlaying || 
                                    !self.pausedBrowserTabs.isEmpty
                
                if anyWasPlaying && !anyMusicPlaying {
                    if self.silenceStartTime == nil {
                        self.silenceStartTime = Date()
                    }
                    
                    if let startTime = self.silenceStartTime,
                       Date().timeIntervalSince(startTime) >= self.resumeDelay {
                        // Resume apps
                        if self.spotifyWasPlaying && self.isSpotifyEnabled {
                            self.controlMusicPlayer(app: .spotify, action: "play")
                            self.spotifyWasPlaying = false
                        }
                        if self.appleMusicWasPlaying && self.isAppleMusicEnabled {
                            self.controlMusicPlayer(app: .appleMusic, action: "play")
                            self.appleMusicWasPlaying = false
                        }
                        
                        // Resume browser tabs
                        self.resumePausedBrowserTabs()
                        
                        self.silenceStartTime = nil
                    }
                } else if anyMusicPlaying {
                    // Si quelque chose joue, réinitialiser les états "was playing"
                    self.spotifyWasPlaying = false
                    self.appleMusicWasPlaying = false
                    self.pausedBrowserTabs.removeAll()
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
        
        var identifier: String {
            switch self {
            case .brave: return "brave"
            case .chrome: return "chrome"
            case .edge: return "edge"
            case .opera: return "opera"
            case .arc: return "arc"
            case .safari: return "safari"
            }
        }
    }
    
    enum BrowserMediaAction {
        case pause
        case play
    }
    
    // MARK: - Safari Tab Detection & Control
    
    /// JavaScript universel pour détecter si un média joue dans un onglet
    /// Stratégie multi-niveaux:
    /// 1. HTML5 audio/video natifs (YouTube, Netflix, Vimeo, etc.)
    /// 2. Sélecteurs spécifiques pour services Web Audio API (Spotify, Deezer, etc.)
    /// 3. Fallback générique basé sur aria-label et patterns communs
    private func getMediaDetectionJS() -> String {
        return """
        (function(){try{var m=document.querySelectorAll('video,audio');for(var i=0;i<m.length;i++){if(!m[i].paused&&!m[i].ended&&m[i].readyState>2&&m[i].currentTime>0)return'playing';}try{var f=document.querySelectorAll('iframe');for(var j=0;j<f.length;j++){var d=f[j].contentDocument||f[j].contentWindow.document;if(d){var im=d.querySelectorAll('video,audio');for(var k=0;k<im.length;k++){if(!im[k].paused&&!im[k].ended&&im[k].readyState>2)return'playing';}}}}catch(e){}if(document.querySelector('[data-testid=control-button-playpause][aria-label*=ause]'))return'playing';if(document.querySelector('[data-testid=play_button_pause]'))return'playing';if(document.querySelector('[data-testid*=pause-button],[data-testid*=pause_button]'))return'playing';if(document.querySelector('#play-pause-button[aria-label*=ause],.play-pause-button[title*=ause]'))return'playing';if(document.querySelector('.playControl.playing,.playButton.playing,.play-button.playing'))return'playing';if(document.querySelector('[data-test=pause],[data-test-id=pause]'))return'playing';if(document.querySelector('[class*=pause][class*=button]:not([class*=play])'))return'playing';if(document.querySelector('button[aria-label*=ause][aria-label*=usic],button[aria-label*=ause][aria-label*=udio],button[aria-label=Pause],button[aria-label=pause]'))return'playing';if(document.querySelector('.now-playing,.is-playing,[data-playing=true]'))return'playing';return'no';}catch(e){return'no';}})()
        """
    }
    
    /// JavaScript universel pour mettre en pause tous les médias
    /// Stratégie: d'abord HTML5, puis services spécifiques, puis fallback générique
    private func getMediaPauseJS() -> String {
        return """
        (function(){try{var paused=false;document.querySelectorAll('video,audio').forEach(function(e){if(!e.paused){e.pause();paused=true;}});if(paused)return'html5';try{document.querySelectorAll('iframe').forEach(function(f){var d=f.contentDocument||f.contentWindow.document;if(d)d.querySelectorAll('video,audio').forEach(function(e){if(!e.paused)e.pause();});});}catch(e){}var b=document.querySelector('[data-testid=control-button-playpause][aria-label*=ause]');if(b){b.click();return'spotify';}b=document.querySelector('[data-testid=play_button_pause]');if(b){b.click();return'deezer';}b=document.querySelector('[data-testid*=pause-button],[data-testid*=pause_button],[data-testid=transport-pause-button]');if(b){b.click();return'testid';}b=document.querySelector('#play-pause-button[aria-label*=ause],.play-pause-button[title*=ause]');if(b){b.click();return'ytmusic';}b=document.querySelector('.playControl.playing,.playButton.playing,.play-button.playing');if(b){b.click();return'playcontrol';}b=document.querySelector('[data-test=pause],[data-test-id=pause]');if(b){b.click();return'datatest';}b=document.querySelector('.playbutton.playing,.playpause.playing');if(b){b.click();return'playbutton';}b=document.querySelector('button[aria-label=Pause],button[aria-label=pause]');if(b){b.click();return'arialabel';}b=document.querySelector('[class*=pause-button]:not([class*=play]),[class*=pauseButton]:not([class*=play])');if(b){b.click();return'classname';}return'none';}catch(e){return'error';}})()
        """
    }
    
    /// JavaScript universel pour reprendre la lecture
    /// Stratégie: d'abord HTML5 (si était en lecture), puis services spécifiques, puis fallback
    private func getMediaPlayJS() -> String {
        return """
        (function(){try{var m=document.querySelectorAll('video,audio');for(var i=0;i<m.length;i++){if(m[i].paused&&m[i].currentTime>0&&!m[i].ended){m[i].play();return'html5';}}var b=document.querySelector('[data-testid=control-button-playpause][aria-label*=lay],[data-testid=control-button-playpause][aria-label*=ecture]');if(b){b.click();return'spotify';}b=document.querySelector('[data-testid=play_button_play]');if(b){b.click();return'deezer';}b=document.querySelector('[data-testid*=play-button]:not([data-testid*=pause]),[data-testid*=play_button]:not([data-testid*=pause]),[data-testid=transport-play-button]');if(b){b.click();return'testid';}b=document.querySelector('#play-pause-button[aria-label*=lay],#play-pause-button[aria-label*=ecture],.play-pause-button[title*=lay]');if(b){b.click();return'ytmusic';}b=document.querySelector('.playControl:not(.playing),.playButton:not(.playing),.play-button:not(.playing)');if(b){b.click();return'playcontrol';}b=document.querySelector('[data-test=play],[data-test-id=play]');if(b){b.click();return'datatest';}b=document.querySelector('.playbutton:not(.playing),.playpause:not(.playing)');if(b){b.click();return'playbutton';}b=document.querySelector('button[aria-label=Play],button[aria-label=play],button[aria-label*=couter],button[aria-label*=Lecture]');if(b){b.click();return'arialabel';}b=document.querySelector('[class*=play-button]:not([class*=pause]),[class*=playButton]:not([class*=pause])');if(b){b.click();return'classname';}return'none';}catch(e){return'error';}})()
        """
    }
    
    /// Récupère les onglets Safari qui jouent actuellement de l'audio sur les domaines autorisés
    private func getPlayingTabsFromSafari() -> [BrowserTab] {
        let jsCode = getMediaDetectionJS()
        
        let script = """
        tell application "System Events"
            if not (exists process "Safari") then return ""
        end tell
        
        tell application "Safari"
            set resultList to ""
            try
                set winIndex to 0
                repeat with w in (every window)
                    set winIndex to winIndex + 1
                    set tabIndex to 0
                    repeat with t in (every tab of w)
                        set tabIndex to tabIndex + 1
                        try
                            set tabURL to URL of t
                            set tabTitle to name of t
                            set playState to do JavaScript "\(jsCode)" in t
                            if playState is "playing" then
                                set resultList to resultList & winIndex & ":::" & tabIndex & ":::" & tabURL & ":::" & tabTitle & "\\n"
                            end if
                        end try
                    end repeat
                end repeat
            end try
            return resultList
        end tell
        """
        
        guard let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            return []
        }
        
        var tabs: [BrowserTab] = []
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let parts = line.components(separatedBy: ":::")
            if parts.count >= 4,
               let winIndex = Int(parts[0]),
               let tabIndex = Int(parts[1]) {
                let url = parts[2]
                let title = parts[3]
                let domain = extractDomain(from: url)
                
                // Vérifier si ce domaine est autorisé
                guard isDomainEnabled(domain) else { continue }
                
                let tabId = "safari:\(winIndex):\(tabIndex)"
                let tab = BrowserTab(
                    id: tabId,
                    browser: "safari",
                    windowIndex: winIndex,
                    tabIndex: tabIndex,
                    url: url,
                    domain: domain,
                    title: title,
                    isPlaying: true,
                    isAudible: true
                )
                tabs.append(tab)
            }
        }
        
        return tabs
    }
    
    /// Met en pause un onglet Safari spécifique
    private func pauseSafariTab(windowIndex: Int, tabIndex: Int) {
        let jsCode = getMediaPauseJS()
        
        let script = """
        tell application "Safari"
            try
                set w to window \(windowIndex)
                set t to tab \(tabIndex) of w
                do JavaScript "\(jsCode)" in t
            end try
        end tell
        """
        _ = runAppleScript(script)
    }
    
    /// Reprend la lecture sur un onglet Safari spécifique
    private func playSafariTab(windowIndex: Int, tabIndex: Int) {
        let jsCode = getMediaPlayJS()
        
        let script = """
        tell application "Safari"
            try
                set w to window \(windowIndex)
                set t to tab \(tabIndex) of w
                do JavaScript "\(jsCode)" in t
            end try
        end tell
        """
        _ = runAppleScript(script)
    }
    
    // MARK: - Chromium Tab Detection & Control
    
    /// Récupère les onglets Chromium qui jouent actuellement de l'audio sur les domaines autorisés
    private func getPlayingTabsFromChromium(browser: Browser) -> [BrowserTab] {
        guard browser.isChromium else { return [] }
        
        let jsCode = getMediaDetectionJS()
        
        let script = """
        tell application "System Events"
            if not (exists process "\(browser.processName)") then return ""
        end tell
        
        tell application "\(browser.appName)"
            set resultList to ""
            try
                set winIndex to 0
                repeat with w in (every window)
                    set winIndex to winIndex + 1
                    set tabIndex to 0
                    repeat with t in (every tab of w)
                        set tabIndex to tabIndex + 1
                        try
                            tell t
                                set tabURL to URL
                                set tabTitle to title
                                set playState to execute javascript "\(jsCode)"
                                if playState is "playing" then
                                    set resultList to resultList & winIndex & ":::" & tabIndex & ":::" & tabURL & ":::" & tabTitle & "\\n"
                                end if
                            end tell
                        end try
                    end repeat
                end repeat
            end try
            return resultList
        end tell
        """
        
        guard let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            return []
        }
        
        var tabs: [BrowserTab] = []
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let parts = line.components(separatedBy: ":::")
            if parts.count >= 4,
               let winIndex = Int(parts[0]),
               let tabIndex = Int(parts[1]) {
                let url = parts[2]
                let title = parts[3]
                let domain = extractDomain(from: url)
                
                // Vérifier si ce domaine est autorisé
                guard isDomainEnabled(domain) else { continue }
                
                let tabId = "\(browser.identifier):\(winIndex):\(tabIndex)"
                let tab = BrowserTab(
                    id: tabId,
                    browser: browser.identifier,
                    windowIndex: winIndex,
                    tabIndex: tabIndex,
                    url: url,
                    domain: domain,
                    title: title,
                    isPlaying: true,
                    isAudible: true
                )
                tabs.append(tab)
            }
        }
        
        return tabs
    }
    
    /// Fallback: détection via JavaScript pour Chromium (gardé pour compatibilité)
    private func getPlayingTabsFromChromiumJS(browser: Browser) -> [BrowserTab] {
        return getPlayingTabsFromChromium(browser: browser)
    }
    
    /// Met en pause un onglet Chromium spécifique
    private func pauseChromiumTab(browser: Browser, windowIndex: Int, tabIndex: Int) {
        guard browser.isChromium else { return }
        
        let jsCode = getMediaPauseJS()
        
        let script = """
        tell application "\(browser.appName)"
            try
                set w to window \(windowIndex)
                set t to tab \(tabIndex) of w
                tell t
                    execute javascript "\(jsCode)"
                end tell
            end try
        end tell
        """
        _ = runAppleScript(script)
    }
    
    /// Reprend la lecture sur un onglet Chromium spécifique
    private func playChromiumTab(browser: Browser, windowIndex: Int, tabIndex: Int) {
        guard browser.isChromium else { return }
        
        let jsCode = getMediaPlayJS()
        
        let script = """
        tell application "\(browser.appName)"
            try
                set w to window \(windowIndex)
                set t to tab \(tabIndex) of w
                tell t
                    execute javascript "\(jsCode)"
                end tell
            end try
        end tell
        """
        _ = runAppleScript(script)
    }
    
    // MARK: - Browser Control Helpers
    
    /// Met en pause tous les onglets en lecture sur les domaines autorisés
    private func pauseAllBrowserTabs() {
        // Safari
        if isSafariEnabled {
            let safariTabs = getPlayingTabsFromSafari()
            for tab in safariTabs {
                pauseSafariTab(windowIndex: tab.windowIndex, tabIndex: tab.tabIndex)
                pausedBrowserTabs.insert(tab.id)
            }
            
            DispatchQueue.main.async {
                self.isSafariPlaying = false
            }
        }
        
        // Navigateurs Chromium
        let chromiumBrowsers: [(Browser, Bool)] = [
            (.brave, isBraveEnabled),
            (.chrome, isChromeEnabled),
            (.edge, isEdgeEnabled),
            (.opera, isOperaEnabled),
            (.arc, isArcEnabled)
        ]
        
        for (browser, isEnabled) in chromiumBrowsers {
            if isEnabled {
                let tabs = getPlayingTabsFromChromium(browser: browser)
                for tab in tabs {
                    pauseChromiumTab(browser: browser, windowIndex: tab.windowIndex, tabIndex: tab.tabIndex)
                    pausedBrowserTabs.insert(tab.id)
                }
                
                // Mettre à jour l'état de lecture sur le main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    switch browser {
                    case .brave: self.isBravePlaying = false
                    case .chrome: self.isChromePlaying = false
                    case .edge: self.isEdgePlaying = false
                    case .opera: self.isOperaPlaying = false
                    case .arc: self.isArcPlaying = false
                    case .safari: break
                    }
                }
            }
        }
    }
    
    /// Reprend la lecture sur les onglets qui étaient en pause
    private func resumePausedBrowserTabs() {
        guard !pausedBrowserTabs.isEmpty else { return }
        
        for tabId in pausedBrowserTabs {
            let parts = tabId.components(separatedBy: ":")
            guard parts.count == 3,
                  let windowIndex = Int(parts[1]),
                  let tabIndex = Int(parts[2]) else { continue }
            
            let browserStr = parts[0]
            
            if browserStr == "safari" && isSafariEnabled {
                playSafariTab(windowIndex: windowIndex, tabIndex: tabIndex)
            } else if let browser = Browser.allCases.first(where: { $0.identifier == browserStr }) {
                if browser.isChromium && isBrowserEnabled(browser) {
                    playChromiumTab(browser: browser, windowIndex: windowIndex, tabIndex: tabIndex)
                }
            }
        }
        
        pausedBrowserTabs.removeAll()
    }
    
    /// Vérifie si un navigateur est activé
    private func isBrowserEnabled(_ browser: Browser) -> Bool {
        switch browser {
        case .safari: return isSafariEnabled
        case .brave: return isBraveEnabled
        case .chrome: return isChromeEnabled
        case .edge: return isEdgeEnabled
        case .opera: return isOperaEnabled
        case .arc: return isArcEnabled
        }
    }
    
    /// Vérifie si des médias jouent dans un navigateur (pour l'affichage UI)
    private func checkBrowserHasPlayingMedia(browser: Browser) -> Bool {
        if browser == .safari {
            return !getPlayingTabsFromSafari().isEmpty
        } else {
            return !getPlayingTabsFromChromium(browser: browser).isEmpty
        }
    }
}
