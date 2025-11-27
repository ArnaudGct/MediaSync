import SwiftUI

@main
struct MediaSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = MdiaSyncMonitor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 600)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configuration de la fenêtre
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            // Désactivé pour éviter que le slider déplace la fenêtre
            window.isMovableByWindowBackground = false
            window.backgroundColor = NSColor(Color.background)
            
            // Intercepter le bouton de fermeture
            window.delegate = self
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Ne pas quitter quand la fenêtre est fermée
        return false
    }
    
    // Réouvrir la fenêtre quand on clique sur l'icône du Dock
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Rouvrir la fenêtre
            for window in NSApplication.shared.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

// Extension pour intercepter la fermeture de fenêtre
extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Cacher l'application au lieu de fermer (comme Cmd+H)
        NSApplication.shared.hide(nil)
        return false
    }
}