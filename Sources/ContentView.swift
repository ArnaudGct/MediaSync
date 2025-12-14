import SwiftUI
import AppKit

// MARK: - Design System
extension Color {
    // Fond glass morphism teinté vert
    static let background = Color(red: 0.04, green: 0.06, blue: 0.05)
    static let cardBackground = Color(red: 0.08, green: 0.12, blue: 0.10)
    static let cardBackgroundHover = Color(red: 0.12, green: 0.16, blue: 0.14)
    static let elevated = Color(red: 0.14, green: 0.18, blue: 0.16)
    
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.70, green: 0.75, blue: 0.72)
    static let textTertiary = Color(red: 0.45, green: 0.50, blue: 0.47)
    
    static let accentGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let accentPurple = Color(red: 0.75, green: 0.35, blue: 0.95)
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.0)  // DaVinci Resolve
    static let accentBlue = Color(red: 0.0, green: 0.6, blue: 1.0)    // After Effects
    static let accentRed = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)
    static let appleMusicPink = Color(red: 0.98, green: 0.34, blue: 0.45)  // Apple Music
    static let braveOrange = Color(red: 0.98, green: 0.35, blue: 0.13)    // Brave Browser
    static let chromeYellow = Color(red: 0.98, green: 0.75, blue: 0.18)   // Google Chrome
    static let edgeBlue = Color(red: 0.0, green: 0.47, blue: 0.95)        // Microsoft Edge
    static let operaRed = Color(red: 1.0, green: 0.18, blue: 0.33)        // Opera
    static let arcPurple = Color(red: 0.55, green: 0.35, blue: 0.95)      // Arc Browser
    static let safariBlue = Color(red: 0.0, green: 0.60, blue: 0.95)      // Safari
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var monitor: MediaSyncMonitor
    @EnvironmentObject var updateChecker: UpdateChecker
    @AppStorage("resumeDelay") private var resumeDelay: Double = 1.0
    @AppStorage("autoStart") private var autoStart: Bool = true
    @State private var isHoveringButton = false
    @State private var selectedTab: Int = 0
    @State private var showUpdateAlert = false
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header avec drag area
                headerView
                
                // Bannière de mise à jour si disponible
                if updateChecker.updateAvailable {
                    UpdateBanner(updateChecker: updateChecker) {
                        showUpdateAlert = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                
                // Tab Selector
                tabSelector
                
                // Content based on selected tab
                if selectedTab == 0 {
                    editingSoftwareTab
                } else {
                    mediaPlayersTab
                }
                
                // Footer with action button and settings
                footerSection
            }
            
            // Update Alert Overlay
            if showUpdateAlert {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showUpdateAlert = false
                    }
                
                UpdateAlertView(updateChecker: updateChecker, isPresented: $showUpdateAlert)
            }
        }
        .frame(width: 420, height: 700)
        .onAppear {
            if autoStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    monitor.start()
                }
            }
            // Vérifier les mises à jour au démarrage
            updateChecker.checkForUpdatesIfNeeded()
        }
        .onChange(of: updateChecker.updateAvailable) { _, newValue in
            // Afficher automatiquement l'alerte si une mise à jour est trouvée
            if newValue {
                showUpdateAlert = true
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            // Zone de drag pour déplacer la fenêtre
            WindowDragArea()
                .frame(height: 20)
            
            HStack(spacing: 12) {
                // App Icon (smaller)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: monitor.isRunning 
                                    ? [Color.accentGreen.opacity(0.3), Color.accentGreen.opacity(0.1)]
                                    : [Color.elevated, Color.cardBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(
                            monitor.isRunning 
                                ? Color.accentGreen 
                                : Color.textTertiary
                        )
                        .symbolEffect(.pulse, options: .repeating, isActive: monitor.isRunning)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text("MediaSync")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    // Status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(monitor.isRunning ? Color.accentGreen : Color.textTertiary)
                            .frame(width: 8, height: 8)
                        
                        Text(monitor.isRunning ? "Synchronisation active" : "En attente")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(monitor.isRunning ? .accentGreen : .textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Montage",
                icon: "film",
                isSelected: selectedTab == 0,
                activeCount: countActiveEditingSoftware()
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 0
                }
            }
            
            TabButton(
                title: "Multimédia",
                icon: "music.note.list",
                isSelected: selectedTab == 1,
                activeCount: countActiveMediaPlayers()
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 1
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
    
    private func countActiveEditingSoftware() -> Int {
        var count = 0
        if monitor.isPremiereEnabled { count += 1 }
        if monitor.isResolveEnabled { count += 1 }
        if monitor.isFinalCutEnabled { count += 1 }
        if monitor.isAfterEffectsEnabled { count += 1 }
        return count
    }
    
    private func countActiveMediaPlayers() -> Int {
        var count = 0
        if monitor.isSpotifyEnabled { count += 1 }
        if monitor.isAppleMusicEnabled { count += 1 }
        if monitor.isBraveEnabled { count += 1 }
        if monitor.isChromeEnabled { count += 1 }
        if monitor.isEdgeEnabled { count += 1 }
        if monitor.isOperaEnabled { count += 1 }
        if monitor.isArcEnabled { count += 1 }
        if monitor.isSafariEnabled { count += 1 }
        return count
    }
    
    // MARK: - Editing Software Tab
    private var editingSoftwareTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Info card
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentBlue)
                    
                    Text("Quand ces logiciels jouent de l'audio, vos lecteurs multimédia seront mis en pause.")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                    
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentBlue.opacity(0.1))
                )
                
                EditingAppRow(
                    iconFallback: "Pr",
                    name: "Premiere Pro",
                    isActive: monitor.isPremiereActive,
                    isEnabled: monitor.isPremiereEnabled,
                    accentColor: .accentPurple,
                    detectionMode: monitor.premiereDetectionMode,
                    hasPermission: monitor.hasScreenCapturePermission,
                    showModeSelector: true,
                    onToggleEnabled: { monitor.togglePremiere() },
                    onModeChange: { mode in monitor.setPremiereDetectionMode(mode) },
                    onOpenPreferences: { monitor.openScreenRecordingPreferences() }
                )
                
                EditingAppRow(
                    iconFallback: "DR",
                    name: "DaVinci Resolve",
                    isActive: monitor.isResolveActive,
                    isEnabled: monitor.isResolveEnabled,
                    accentColor: .accentOrange,
                    detectionMode: monitor.resolveDetectionMode,
                    hasPermission: monitor.hasScreenCapturePermission,
                    showModeSelector: true,
                    onToggleEnabled: { monitor.toggleResolve() },
                    onModeChange: { mode in monitor.setResolveDetectionMode(mode) },
                    onOpenPreferences: { monitor.openScreenRecordingPreferences() }
                )
                
                EditingAppRow(
                    iconFallback: "FC",
                    name: "Final Cut Pro",
                    isActive: monitor.isFinalCutActive,
                    isEnabled: monitor.isFinalCutEnabled,
                    accentColor: .accentGreen,
                    detectionMode: monitor.finalCutDetectionMode,
                    hasPermission: monitor.hasScreenCapturePermission,
                    showModeSelector: true,
                    onToggleEnabled: { monitor.toggleFinalCut() },
                    onModeChange: { mode in monitor.setFinalCutDetectionMode(mode) },
                    onOpenPreferences: { monitor.openScreenRecordingPreferences() }
                )
                
                EditingAppRow(
                    iconFallback: "Ae",
                    name: "After Effects",
                    isActive: monitor.isAfterEffectsActive,
                    isEnabled: monitor.isAfterEffectsEnabled,
                    accentColor: .accentBlue,
                    detectionMode: .audio,
                    hasPermission: monitor.hasScreenCapturePermission,
                    showModeSelector: false,
                    onToggleEnabled: { monitor.toggleAfterEffects() },
                    onModeChange: { _ in },
                    onOpenPreferences: { monitor.openScreenRecordingPreferences() }
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Media Players Tab
    private var mediaPlayersTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Section Lecteurs de musique
                VStack(spacing: 10) {
                    HStack {
                        Text("LECTEURS DE MUSIQUE")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.textTertiary)
                        Spacer()
                    }
                    .padding(.leading, 4)
                    
                    MusicAppRow(
                        icon: "music.note",
                        name: "Spotify",
                        isActive: monitor.isSpotifyPlaying,
                        isEnabled: monitor.isSpotifyEnabled,
                        accentColor: .spotifyGreen,
                        onToggleEnabled: { monitor.toggleSpotify() }
                    )
                    
                    MusicAppRow(
                        icon: "music.note",
                        name: "Apple Music",
                        isActive: monitor.isAppleMusicPlaying,
                        isEnabled: monitor.isAppleMusicEnabled,
                        accentColor: .appleMusicPink,
                        onToggleEnabled: { monitor.toggleAppleMusic() }
                    )
                }
                
                // Section Navigateurs
                VStack(spacing: 10) {
                    HStack {
                        Text("NAVIGATEURS WEB")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.textTertiary)
                        Spacer()
                    }
                    .padding(.leading, 4)
                    
                    // Info bulle pour les navigateurs
                    BrowserPermissionInfo()
                    
                    // Grille de navigateurs (2 colonnes)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        CompactBrowserRow(
                            iconText: "Sf",
                            name: "Safari",
                            isActive: monitor.isSafariPlaying,
                            isEnabled: monitor.isSafariEnabled,
                            accentColor: .safariBlue,
                            onToggleEnabled: { monitor.toggleSafari() }
                        )
                        
                        CompactBrowserRow(
                            iconText: "Ch",
                            name: "Chrome",
                            isActive: monitor.isChromePlaying,
                            isEnabled: monitor.isChromeEnabled,
                            accentColor: .chromeYellow,
                            onToggleEnabled: { monitor.toggleChrome() }
                        )
                        
                        CompactBrowserRow(
                            iconText: "Br",
                            name: "Brave",
                            isActive: monitor.isBravePlaying,
                            isEnabled: monitor.isBraveEnabled,
                            accentColor: .braveOrange,
                            onToggleEnabled: { monitor.toggleBrave() }
                        )
                        
                        CompactBrowserRow(
                            iconText: "Ed",
                            name: "Edge",
                            isActive: monitor.isEdgePlaying,
                            isEnabled: monitor.isEdgeEnabled,
                            accentColor: .edgeBlue,
                            onToggleEnabled: { monitor.toggleEdge() }
                        )
                        
                        CompactBrowserRow(
                            iconText: "Op",
                            name: "Opera",
                            isActive: monitor.isOperaPlaying,
                            isEnabled: monitor.isOperaEnabled,
                            accentColor: .operaRed,
                            onToggleEnabled: { monitor.toggleOpera() }
                        )
                        
                        CompactBrowserRow(
                            iconText: "Ar",
                            name: "Arc",
                            isActive: monitor.isArcPlaying,
                            isEnabled: monitor.isArcEnabled,
                            accentColor: .arcPurple,
                            onToggleEnabled: { monitor.toggleArc() }
                        )
                    }
                    
                    // Section Domaines gérés
                    if monitor.isBraveEnabled || monitor.isChromeEnabled || monitor.isEdgeEnabled || monitor.isOperaEnabled || monitor.isArcEnabled || monitor.isSafariEnabled {
                        BrowserDomainsSection(
                            playingTabs: monitor.playingTabs,
                            enabledDomains: monitor.enabledDomains,
                            onToggleDomain: { domain in monitor.toggleDomain(domain) },
                            onRefresh: { monitor.refreshPlayingTabs() }
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.elevated)
            
            // Action Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if monitor.isRunning {
                        monitor.stop()
                    } else {
                        monitor.start()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: monitor.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(monitor.isRunning ? "Arrêter" : "Démarrer")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            monitor.isRunning
                                ? (isHoveringButton ? Color.accentRed.opacity(0.8) : Color.accentRed)
                                : (isHoveringButton ? Color.accentGreen.opacity(0.8) : Color.accentGreen)
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringButton = hovering
                }
            }
            
            // Quick Settings
            HStack(spacing: 12) {
                // Delay
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.accentGreen.opacity(0.8))
                    
                    Text("Délai de reprise:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.9))
                    
                    Picker("", selection: $resumeDelay) {
                        Text("0.5s").tag(0.5)
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("3s").tag(3.0)
                        Text("5s").tag(5.0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 65)
                    .tint(.accentGreen)
                    .colorScheme(.dark)
                    .onChange(of: resumeDelay) { _, newValue in
                        monitor.resumeDelay = newValue
                    }
                }
                
                Spacer()
                
                // Auto Start
                HStack(spacing: 6) {
                    Text("Démarrage auto")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.9))
                    
                    Toggle("", isOn: $autoStart)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.accentGreen)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cardBackground.opacity(0.6))
            )
            
            // Credits
            HStack(spacing: 4) {
                Text("Vibe-codée avec")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                
                Text("❤️")
                    .font(.system(size: 10))
                
                Text("par")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                
                Link("Arnaud Graciet", destination: URL(string: "https://arnaudgct.fr/")!)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentGreen)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let activeCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    
                    if activeCount > 0 {
                        Text("\(activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.accentGreen))
                    }
                }
                .foregroundColor(isSelected ? .textPrimary : .textTertiary)
                
                // Indicator
                Rectangle()
                    .fill(isSelected ? Color.accentGreen : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Browser Row (for grid)
struct CompactBrowserRow: View {
    let iconText: String
    let name: String
    let isActive: Bool
    let isEnabled: Bool
    let accentColor: Color
    let onToggleEnabled: () -> Void
    
    var body: some View {
        Button(action: onToggleEnabled) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isEnabled ? (isActive ? accentColor.opacity(0.15) : Color.elevated) : Color.elevated.opacity(0.3))
                        .frame(width: 32, height: 32)
                    
                    Text(iconText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isEnabled ? (isActive ? accentColor : .textTertiary) : .textTertiary.opacity(0.5))
                    
                    if !isEnabled {
                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentRed.opacity(0.8))
                            .offset(x: 10, y: 10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
                    
                    if isEnabled && isActive {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.elevated.opacity(isEnabled ? 0.5 : 0.25))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editing App Row (Premiere, Resolve, After Effects)
struct EditingAppRow: View {
    let iconFallback: String
    let name: String
    let isActive: Bool
    let isEnabled: Bool
    let accentColor: Color
    let detectionMode: DetectionMode
    let hasPermission: Bool
    let showModeSelector: Bool
    let onToggleEnabled: () -> Void
    let onModeChange: (DetectionMode) -> Void
    let onOpenPreferences: () -> Void
    
    private var needsPermission: Bool {
        detectionMode == .audio && !hasPermission
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon container (cliquable pour activer/désactiver)
            Button(action: onToggleEnabled) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isEnabled ? (isActive ? accentColor.opacity(0.15) : Color.elevated) : Color.elevated.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Text(iconFallback)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isEnabled ? (isActive ? accentColor : .textTertiary) : .textTertiary.opacity(0.5))
                    
                    // Indicateur désactivé
                    if !isEnabled {
                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentRed.opacity(0.8))
                            .offset(x: 14, y: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
                
                if !isEnabled {
                    Text("Désactivé")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                } else if needsPermission {
                    Text("Permission requise")
                        .font(.system(size: 12))
                        .foregroundColor(.accentRed)
                } else {
                    Text(isActive ? "Lecture en cours" : "En pause")
                        .font(.system(size: 12))
                        .foregroundColor(isActive ? accentColor : .textTertiary)
                }
            }
            
            Spacer()
            
            // Mode selector ou permission button
            if isEnabled {
                if needsPermission {
                    Button(action: onOpenPreferences) {
                        Text("Réglages")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.accentBlue.opacity(0.8)))
                    }
                    .buttonStyle(.plain)
                } else if showModeSelector {
                    // Sélecteur de mode
                    DetectionModeSelector(
                        selectedMode: detectionMode,
                        hasPermission: hasPermission,
                        accentColor: accentColor,
                        onModeChange: onModeChange
                    )
                } else {
                    // Badge Audio uniquement (After Effects)
                    Text("Audio")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.8)))
                }
                
                // Status indicator
                if !needsPermission {
                    Circle()
                        .fill(isActive ? accentColor : Color.textTertiary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .shadow(color: isActive ? accentColor.opacity(0.5) : .clear, radius: 3)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.elevated.opacity(isEnabled ? 0.5 : 0.25))
        )
        .opacity(isEnabled ? 1 : 0.7)
    }
}

// MARK: - Detection Mode Selector
struct DetectionModeSelector: View {
    let selectedMode: DetectionMode
    let hasPermission: Bool
    let accentColor: Color
    let onModeChange: (DetectionMode) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(DetectionMode.allCases, id: \.self) { mode in
                Button(action: {
                    if mode == .audio && !hasPermission {
                        // Ne pas changer si pas de permission pour audio
                        return
                    }
                    onModeChange(mode)
                }) {
                    Text(mode.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(selectedMode == mode ? .white : .textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectedMode == mode ? accentColor.opacity(0.8) : Color.elevated)
                        )
                }
                .buttonStyle(.plain)
                .opacity(mode == .audio && !hasPermission ? 0.5 : 1)
            }
        }
    }
}

// MARK: - Music App Row
struct MusicAppRow: View {
    let icon: String
    let name: String
    let isActive: Bool
    let isEnabled: Bool
    let accentColor: Color
    let onToggleEnabled: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon container (cliquable pour activer/désactiver)
            Button(action: onToggleEnabled) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isEnabled ? (isActive ? accentColor.opacity(0.15) : Color.elevated) : Color.elevated.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isEnabled ? (isActive ? accentColor : .textTertiary) : .textTertiary.opacity(0.5))
                    
                    // Indicateur désactivé
                    if !isEnabled {
                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentRed.opacity(0.8))
                            .offset(x: 14, y: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
                
                if !isEnabled {
                    Text("Gestion désactivée")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                } else {
                    Text(isActive ? "En lecture" : "En pause")
                        .font(.system(size: 12))
                        .foregroundColor(isActive ? accentColor : .textTertiary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isEnabled {
                Circle()
                    .fill(isActive ? accentColor : Color.textTertiary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .shadow(color: isActive ? accentColor.opacity(0.5) : .clear, radius: 3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.elevated.opacity(isEnabled ? 0.5 : 0.25))
        )
        .opacity(isEnabled ? 1 : 0.7)
    }
}

// MARK: - Browser Permission Info
struct BrowserPermissionInfo: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentBlue)
                    
                    Text("Configuration requise pour les navigateurs")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.elevated)
                    
                    // Safari instructions
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Sf")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.safariBlue)
                            Text("Safari")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Safari > Réglages > Avancé")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                            Text("2. Cocher \"Afficher les fonctionnalités pour les développeurs web\"")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                            Text("3. Menu Développement > \"Autoriser JavaScript via Apple Events\"")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.leading, 16)
                    }
                    
                    Divider()
                        .background(Color.elevated)
                    
                    // Chromium browsers instructions
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Ch Br Ed Op Ar")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.chromeYellow)
                            Text("Navigateurs Chromium")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Menu Affichage > Développeur")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                            Text("2. Cocher \"Autoriser JavaScript via Apple Events\"")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.leading, 16)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.elevated.opacity(0.3))
        )
    }
}

// MARK: - Browser App Row (Brave, Chrome, etc.)
struct BrowserAppRow: View {
    let iconText: String
    let name: String
    let isActive: Bool
    let isEnabled: Bool
    let accentColor: Color
    let onToggleEnabled: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon container (cliquable pour activer/désactiver)
            Button(action: onToggleEnabled) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isEnabled ? (isActive ? accentColor.opacity(0.15) : Color.elevated) : Color.elevated.opacity(0.3))
                        .frame(width: 44, height: 44)
                    
                    Text(iconText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isEnabled ? (isActive ? accentColor : .textTertiary) : .textTertiary.opacity(0.5))
                    
                    // Indicateur désactivé
                    if !isEnabled {
                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentRed.opacity(0.8))
                            .offset(x: 14, y: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
                
                if !isEnabled {
                    Text("Gestion désactivée")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                } else {
                    Text(isActive ? "En lecture" : "En pause")
                        .font(.system(size: 12))
                        .foregroundColor(isActive ? accentColor : .textTertiary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isEnabled {
                Circle()
                    .fill(isActive ? accentColor : Color.textTertiary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .shadow(color: isActive ? accentColor.opacity(0.5) : .clear, radius: 3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.elevated.opacity(isEnabled ? 0.5 : 0.25))
        )
        .opacity(isEnabled ? 1 : 0.7)
    }
}

// MARK: - Browser Domains Section
struct BrowserDomainsSection: View {
    let playingTabs: [BrowserTab]
    let enabledDomains: Set<String>
    let onToggleDomain: (String) -> Void
    let onRefresh: () -> Void
    
    @State private var isExpanded = false
    
    // Liste des domaines par défaut connus
    private let knownDomains = [
        "youtube.com": "YouTube",
        "music.youtube.com": "YouTube Music",
        "open.spotify.com": "Spotify Web",
        "soundcloud.com": "SoundCloud",
        "deezer.com": "Deezer",
        "music.apple.com": "Apple Music Web",
        "artlist.io": "Artlist",
        "bandcamp.com": "Bandcamp",
        "tidal.com": "Tidal",
        "vimeo.com": "Vimeo",
        "twitch.tv": "Twitch",
        "dailymotion.com": "Dailymotion",
        "netflix.com": "Netflix",
        "primevideo.com": "Prime Video",
        "disneyplus.com": "Disney+"
    ]
    
    // Combine les domaines connus + ceux détectés dans les onglets
    private var allDomains: [(domain: String, name: String, isPlaying: Bool)] {
        var result: [(String, String, Bool)] = []
        
        // Ajouter les domaines connus
        for (domain, name) in knownDomains.sorted(by: { $0.value < $1.value }) {
            let isPlaying = playingTabs.contains { $0.domain.contains(domain) || domain.contains($0.domain) }
            result.append((domain, name, isPlaying))
        }
        
        // Ajouter les domaines détectés non connus
        for tab in playingTabs {
            let tabDomain = tab.domain
            if !knownDomains.keys.contains(where: { tabDomain.contains($0) || $0.contains(tabDomain) }) {
                if !result.contains(where: { $0.0 == tabDomain }) {
                    result.append((tabDomain, tabDomain, true))
                }
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header avec bouton pour expand/collapse
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentBlue)
                    
                    Text("Sites web gérés")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text("\(enabledDomains.count) actifs")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                    .background(Color.elevated)
                
                VStack(spacing: 6) {
                    // Info text
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                        Text("Seuls les sites activés seront mis en pause")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                        Spacer()
                        
                        // Bouton refresh
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentBlue)
                        }
                        .buttonStyle(.plain)
                        .help("Actualiser les onglets")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Liste des domaines
                    ForEach(allDomains, id: \.domain) { domain, name, isPlaying in
                        DomainRow(
                            domain: domain,
                            displayName: name,
                            isEnabled: enabledDomains.contains(domain),
                            isPlaying: isPlaying,
                            onToggle: { onToggleDomain(domain) }
                        )
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.elevated.opacity(0.3))
        )
    }
}

// MARK: - Domain Row
struct DomainRow: View {
    let domain: String
    let displayName: String
    let isEnabled: Bool
    let isPlaying: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isEnabled ? Color.accentGreen : Color.textTertiary, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if isEnabled {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentGreen)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Name
                Text(displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isEnabled ? .textPrimary : .textTertiary)
                
                Spacer()
                
                // Playing indicator
                if isPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 9))
                        Text("En lecture")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.accentGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentGreen.opacity(0.15)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Status Row (legacy, kept for compatibility)
struct AppStatusRow: View {
    let icon: String
    let iconFallback: String
    let name: String
    let isActive: Bool
    let accentColor: Color
    var usesScreenCapture: Bool = false
    var hasPermission: Bool = true
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? accentColor.opacity(0.15) : Color.elevated)
                    .frame(width: 44, height: 44)
                
                if icon.contains(".") {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isActive ? accentColor : .textTertiary)
                } else {
                    Text(iconFallback)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? accentColor : .textTertiary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                Text(isActive ? "Lecture en cours" : "En pause")
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? accentColor : .textTertiary)
            }
            
            Spacer()
            
            Circle()
                .fill(isActive ? accentColor : Color.textTertiary.opacity(0.5))
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? accentColor.opacity(0.5) : .clear, radius: 3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.elevated.opacity(0.5))
        )
    }
}

// MARK: - Help Step
struct HelpStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.accentBlue)
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Custom Slider
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knobSize: CGFloat = 24
            let trackHeight: CGFloat = 6
            
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let knobX = knobSize/2 + CGFloat(progress) * (width - knobSize)
            
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.elevated)
                    .frame(height: trackHeight)
                
                // Track filled
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGreen.opacity(0.7), Color.accentGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, knobX), height: trackHeight)
                
                // Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.2), radius: isDragging ? 6 : 4, y: 2)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .position(x: knobX, y: geometry.size.height / 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newProgress = (gesture.location.x - knobSize/2) / (width - knobSize)
                        let clampedProgress = max(0, min(1, newProgress))
                        let rawValue = range.lowerBound + clampedProgress * (range.upperBound - range.lowerBound)
                        value = (rawValue / step).rounded() * step
                        value = max(range.lowerBound, min(range.upperBound, value))
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3)) {
                            isDragging = false
                        }
                    }
            )
        }
        .frame(height: 30)
        .animation(.spring(response: 0.2), value: value)
    }
}

// MARK: - Custom Toggle Style
struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.accentGreen : Color.elevated)
                    .frame(width: 51, height: 31)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

// MARK: - Window Drag Area
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// Preview supprimé pour compatibilité Swift Package Manager
