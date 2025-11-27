# MediaSync

Application macOS native pour synchroniser automatiquement Spotify et Apple Music avec vos applications de montage vidéo.

## ✨ Fonctionnalités

- 🎬 **Détection multi-applications** : Détecte quand Premiere Pro, DaVinci Resolve ou After Effects lit une vidéo
- 🎵 **Contrôle Spotify & Apple Music** : Pause automatique pendant la lecture, reprise après
- 🎧 **Capture audio After Effects** : Utilise ScreenCaptureKit pour détecter l'audio en temps réel
- ⚙️ **Délai configurable** : Ajustez le temps avant la reprise de la musique
- 🎨 **Design natif macOS** : Interface SwiftUI moderne et élégante
- 🚀 **Démarrage automatique** : Option pour lancer la synchronisation à l'ouverture

## 🛠 Installation

### Prérequis

- macOS 13.0 (Ventura) ou plus récent
- Xcode Command Line Tools

```bash
xcode-select --install
```

### Compilation

```bash
cd MediaSync
chmod +x build.sh
./build.sh
```

### Installation

```bash
cp -r "dist/MediaSync.app" /Applications/
```

## 🚀 Utilisation

1. Lancez l'application
2. **Accordez la permission d'enregistrement d'écran** (nécessaire pour After Effects)
3. La synchronisation démarre automatiquement (configurable)
4. Quand vous lancez la lecture dans une app de montage → Spotify/Apple Music se met en pause
5. Quand vous arrêtez la lecture → La musique reprend après le délai configuré

## ⚙️ Configuration

- **Délai de reprise** : 0.5s à 5.0s (par pas de 0.5s)
- **Démarrage automatique** : Active/désactive la synchronisation au lancement

## 🎬 Applications supportées

| Application         | Méthode de détection     |
| ------------------- | ------------------------ |
| Adobe Premiere Pro  | `pmset assertions`       |
| DaVinci Resolve     | `pmset assertions`       |
| Adobe After Effects | ScreenCaptureKit (audio) |

## 🎵 Lecteurs de musique supportés

- Spotify
- Apple Music

## 🏗 Architecture

```
MediaSync/
├── Package.swift                      # Configuration Swift Package Manager
├── build.sh                           # Script de compilation
└── Sources/
    ├── MediaSyncApp.swift   # Point d'entrée
    ├── ContentView.swift              # Interface utilisateur SwiftUI
    ├── MdiaSyncMonitor.swift          # Logique de monitoring principal
    └── AudioCaptureManager.swift      # Capture audio ScreenCaptureKit (After Effects)
```

## 📝 Notes techniques

- Utilise `pmset -g assertions` pour détecter la lecture Premiere Pro et DaVinci Resolve
- Utilise **ScreenCaptureKit** pour capturer l'audio d'After Effects en temps réel
- Contrôle Spotify et Apple Music via AppleScript
- Interface 100% SwiftUI avec animations natives
- Stockage des préférences via `@AppStorage` (UserDefaults)

## 🔒 Permissions requises

- **Enregistrement d'écran** : Nécessaire pour capturer l'audio d'After Effects via ScreenCaptureKit
- **AppleScript** : Nécessaire pour contrôler Spotify et Apple Music
