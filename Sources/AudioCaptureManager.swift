import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine
import AppKit

/// Gestionnaire de capture audio utilisant ScreenCaptureKit
/// Permet de détecter l'audio provenant d'applications spécifiques
@available(macOS 13.0, *)
class AudioCaptureManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAppPlaying = false
    @Published var hasPermission = false
    @Published var isMonitoring = false
    @Published var isAppRunning = false
    
    // MARK: - App Configuration
    private let appBundleIdentifier: String
    private let appNamePattern: String
    private let permissionKey: String
    
    // MARK: - Private Properties
    private var stream: SCStream?
    private var targetApp: SCRunningApplication?
    
    // Paramètres de détection audio
    private let audioThreshold: Float = 0.0005
    private let silenceTimeout: TimeInterval = 0.4
    
    private var lastAudioDetectionTime: Date?
    private var silenceTimer: Timer?
    private var appCheckTimer: Timer?
    
    // Queue pour le traitement audio
    private let audioQueue: DispatchQueue
    
    // Flag pour éviter les multiples tentatives de connexion
    private var isSettingUp = false
    
    // MARK: - Initialization
    
    init(appIdentifier: String, appName: String) {
        self.appBundleIdentifier = appIdentifier
        self.appNamePattern = appName.lowercased()
        self.permissionKey = "screenCapturePermissionGranted"
        self.audioQueue = DispatchQueue(label: "com.mediasync.audiocapture.\(appIdentifier)", qos: .userInteractive)
        super.init()
        
        // Charger l'état de permission depuis UserDefaults (PAS de vérification système)
        self.hasPermission = UserDefaults.standard.bool(forKey: permissionKey)
    }
    
    deinit {
        appCheckTimer?.invalidate()
        silenceTimer?.invalidate()
    }
    
    // MARK: - Permission Management
    
    /// Ouvre les préférences système - c'est tout, pas de vérification automatique
    func openScreenRecordingPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Marque la permission comme accordée (appelé quand la capture réussit)
    private func markPermissionGranted() {
        DispatchQueue.main.async {
            if !self.hasPermission {
                self.hasPermission = true
                UserDefaults.standard.set(true, forKey: self.permissionKey)
            }
        }
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Démarrer le timer de vérification d'app
        startAppCheckTimer()
        
        // Tenter de démarrer la capture (si permission OK, ça marchera)
        Task {
            await setupAudioCapture()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        isSettingUp = false
        
        appCheckTimer?.invalidate()
        appCheckTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        Task {
            await stopStream()
        }
        
        DispatchQueue.main.async {
            self.isAppPlaying = false
            self.isAppRunning = false
        }
    }
    
    // MARK: - App Check Timer
    
    private func startAppCheckTimer() {
        appCheckTimer?.invalidate()
        appCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Ne vérifier que si on a déjà la permission (pour éviter les pop-ups)
            if self.hasPermission || self.isMonitoring {
                Task {
                    await self.checkAppStatusSilently()
                }
            }
        }
    }
    
    /// Vérifie le statut de l'app SEULEMENT si on sait qu'on a la permission
    private func checkAppStatusSilently() async {
        guard hasPermission || isMonitoring else { return }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            let app = content.applications.first { app in
                app.bundleIdentifier == self.appBundleIdentifier ||
                app.applicationName.lowercased().contains(self.appNamePattern)
            }
            
            let wasRunning = isAppRunning
            let isNowRunning = app != nil
            
            await MainActor.run {
                self.isAppRunning = isNowRunning
            }
            
            // App vient de démarrer
            if isNowRunning && !wasRunning && !isMonitoring && !isSettingUp {
                await setupAudioCapture()
            }
            
            // App vient de se fermer
            if !isNowRunning && wasRunning {
                await stopStream()
                await MainActor.run {
                    self.isAppPlaying = false
                    self.isMonitoring = false
                }
            }
            
        } catch {
            // Erreur silencieuse - ne pas spammer
        }
    }
    
    // MARK: - Audio Capture Setup
    
    private func setupAudioCapture() async {
        guard !isSettingUp else { return }
        isSettingUp = true
        
        defer { isSettingUp = false }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            // Si on arrive ici, la permission est accordée !
            markPermissionGranted()
            
            targetApp = content.applications.first { app in
                app.bundleIdentifier == self.appBundleIdentifier ||
                app.applicationName.lowercased().contains(self.appNamePattern)
            }
            
            guard let app = targetApp else {
                await MainActor.run {
                    self.isMonitoring = false
                    self.isAppPlaying = false
                    self.isAppRunning = false
                }
                return
            }
            
            await MainActor.run {
                self.isAppRunning = true
            }
            
            await stopStream()
            
            guard let display = content.displays.first else {
                return
            }
            
            let appFilter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
            
            let config = SCStreamConfiguration()
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.showsCursor = false
            config.queueDepth = 3
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
            config.excludesCurrentProcessAudio = true
            
            stream = SCStream(filter: appFilter, configuration: config, delegate: self)
            
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
            
            try await stream?.startCapture()
            
            await MainActor.run {
                self.isMonitoring = true
                self.startSilenceDetectionTimer()
            }
            
        } catch {
            // Échec silencieux - la permission n'est probablement pas accordée
            await MainActor.run {
                self.isMonitoring = false
            }
        }
    }
    
    private func stopStream() async {
        guard let currentStream = stream else { return }
        
        do {
            try await currentStream.stopCapture()
        } catch {
            // Ignorer
        }
        stream = nil
    }
    
    // MARK: - Silence Detection Timer
    
    private func startSilenceDetectionTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkForSilence()
        }
    }
    
    private func checkForSilence() {
        guard isMonitoring else { return }
        
        if let lastDetection = lastAudioDetectionTime {
            let timeSinceLastAudio = Date().timeIntervalSince(lastDetection)
            
            if timeSinceLastAudio > silenceTimeout && isAppPlaying {
                DispatchQueue.main.async {
                    self.isAppPlaying = false
                }
            }
        }
    }
    
    // MARK: - Audio Level Analysis
    
    private func analyzeAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        
        guard status == kCMBlockBufferNoErr, let data = dataPointer, length > 0 else { return }
        
        let frameCount = length / MemoryLayout<Float>.size
        guard frameCount > 0 else { return }
        
        let samples = UnsafeRawPointer(data).bindMemory(to: Float.self, capacity: frameCount)
        
        var sumValue: Float = 0
        for i in 0..<frameCount {
            let sample = samples[i]
            sumValue += sample * sample
        }
        
        let rms = sqrt(sumValue / Float(frameCount))
        
        if rms > audioThreshold {
            lastAudioDetectionTime = Date()
            
            if !isAppPlaying {
                DispatchQueue.main.async {
                    self.isAppPlaying = true
                }
            }
        }
    }
}

// MARK: - SCStreamDelegate

@available(macOS 13.0, *)
extension AudioCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.isAppPlaying = false
        }
        
        // Réessayer après 1 seconde si l'app est toujours là
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if self.isAppRunning && self.hasPermission {
                await self.setupAudioCapture()
            }
        }
    }
}

// MARK: - SCStreamOutput

@available(macOS 13.0, *)
extension AudioCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        analyzeAudioBuffer(sampleBuffer)
    }
}
