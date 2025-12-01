# MediaSync

Application macOS native pour synchroniser automatiquement Spotify et Apple Music avec vos applications de montage vidéo.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Fonctionnalités

- 🎬 **Détection multi-applications** : Premiere Pro, DaVinci Resolve, After Effects
- 🎵 **Contrôle automatique** : Spotify & Apple Music se mettent en pause pendant la lecture vidéo
- 🌐 **Support navigateurs** : Safari, Chrome, Brave, Edge, Opera, Arc (YouTube, etc.)
- 🎧 **Capture audio** : Détection en temps réel via ScreenCaptureKit
- ⚙️ **Délai configurable** : Ajustez le temps avant la reprise de la musique
- 🔄 **Mises à jour automatiques** : Notification quand une nouvelle version est disponible
- 🎨 **Design natif macOS** : Interface SwiftUI moderne et élégante

---

## 📦 Installation

### Prérequis

- **macOS 14.0** (Sonoma) ou plus récent
- **Xcode Command Line Tools**

```bash
xcode-select --install
```

- **Python 3 avec Pillow** (pour générer l'icône)

```bash
pip3 install Pillow
```

### Option 1 : Télécharger la Release

1. Allez sur [Releases](https://github.com/ArnaudGct/MediaSync/releases)
2. Téléchargez le dernier fichier `.dmg`
3. Ouvrez le DMG et glissez **MediaSync** dans **Applications**
4. Premier lancement : **Clic droit → Ouvrir → Confirmer** (nécessaire car l'app n'est pas signée Apple)

### Option 2 : Compiler depuis les sources

```bash
# Cloner le repository
git clone https://github.com/ArnaudGct/MediaSync.git
cd MediaSync

# Compiler et créer le .app + .dmg
chmod +x build.sh
./build.sh

# Installer dans Applications
cp -r "dist/MediaSync.app" /Applications/
```

---

## 🚀 Utilisation

1. **Lancez MediaSync** depuis Applications ou le Dock
2. **Accordez les permissions** demandées (enregistrement d'écran pour After Effects)
3. La synchronisation démarre automatiquement (configurable)
4. Quand vous lancez la lecture dans une app de montage → La musique se met en pause
5. Quand vous arrêtez la lecture → La musique reprend après le délai configuré

### Permissions requises

| Permission                      | Raison                                                |
| ------------------------------- | ----------------------------------------------------- |
| **Enregistrement d'écran**      | Capturer l'audio d'After Effects via ScreenCaptureKit |
| **AppleScript**                 | Contrôler Spotify et Apple Music                      |
| **JavaScript via Apple Events** | Contrôler les navigateurs (Safari, Chrome, etc.)      |

---

## 🛠 Compilation & Build

### Compilation rapide (debug)

```bash
swift build
```

### Build complet avec .app et .dmg

```bash
./build.sh
```

Cela génère :

- `dist/MediaSync.app` - L'application
- `dist/MediaSync-X.X.dmg` - Le fichier DMG pour distribution

### Mettre à jour l'application installée

```bash
# Fermer MediaSync si ouvert, puis :
rm -rf /Applications/MediaSync.app
cp -r "dist/MediaSync.app" /Applications/
```

Ou en une seule commande :

```bash
./build.sh && rm -rf /Applications/MediaSync.app && cp -r "dist/MediaSync.app" /Applications/
```

---

## 🔄 Gestion des Versions & Releases

### Modifier la version

1. **Éditez `build.sh`** et changez les variables en haut du fichier :

```bash
VERSION="2.2.0"      # Version complète (MAJOR.MINOR.PATCH)
VERSION_SHORT="2.2"  # Version courte pour l'affichage
```

Le script met automatiquement à jour la version dans le code Swift.

### Créer une nouvelle Release GitHub

```bash
# 1. Compiler la nouvelle version
./build.sh

# 2. Commit des changements
git add .
git commit -m "Release v2.2.0 - Description des changements"

# 3. Créer un tag de version
git tag v2.2.0

# 4. Pousser sur GitHub
git push origin main --tags
```

### Publier la Release sur GitHub

1. Allez sur **https://github.com/ArnaudGct/MediaSync/releases**
2. Cliquez **"Draft a new release"**
3. Sélectionnez le tag (ex: `v2.2.0`)
4. Titre : `MediaSync v2.2.0`
5. Description : Listez les nouveautés et corrections
6. **Uploadez le fichier DMG** depuis `dist/MediaSync-2.2.dmg`
7. Cliquez **"Publish release"**

### Système de mise à jour automatique

L'application vérifie automatiquement les nouvelles versions sur GitHub :

- ✅ Vérification toutes les 24h
- ✅ Notification avec les notes de version
- ✅ Téléchargement direct du DMG
- ✅ Option "Ignorer cette version"

Les utilisateurs verront une bannière verte quand une mise à jour est disponible.

---

## 📋 Convention de Versioning

Utilise le **[Semantic Versioning](https://semver.org/lang/fr/)** : `MAJOR.MINOR.PATCH`

| Type      | Quand l'incrémenter                         | Exemple       |
| --------- | ------------------------------------------- | ------------- |
| **MAJOR** | Changements incompatibles, refonte majeure  | 2.0.0 → 3.0.0 |
| **MINOR** | Nouvelles fonctionnalités (rétrocompatible) | 2.1.0 → 2.2.0 |
| **PATCH** | Corrections de bugs                         | 2.1.0 → 2.1.1 |

---

## 🎬 Applications supportées

### Logiciels de montage

| Application         | Méthode de détection        | Modes disponibles |
| ------------------- | --------------------------- | ----------------- |
| Adobe Premiere Pro  | `pmset assertions` ou Audio | System / Audio    |
| DaVinci Resolve     | `pmset assertions` ou Audio | System / Audio    |
| Adobe After Effects | ScreenCaptureKit            | Audio uniquement  |

### Lecteurs de musique

| Application | Contrôle via |
| ----------- | ------------ |
| Spotify     | AppleScript  |
| Apple Music | AppleScript  |

### Navigateurs web

| Navigateur | Configuration requise                                                |
| ---------- | -------------------------------------------------------------------- |
| Safari     | Menu Développement → Autoriser JavaScript via Apple Events           |
| Chrome     | Menu Affichage → Développeur → Autoriser JavaScript via Apple Events |
| Brave      | Menu Affichage → Développeur → Autoriser JavaScript via Apple Events |
| Edge       | Menu Affichage → Développeur → Autoriser JavaScript via Apple Events |
| Opera      | Menu Affichage → Développeur → Autoriser JavaScript via Apple Events |
| Arc        | Menu Affichage → Développeur → Autoriser JavaScript via Apple Events |

---

## 🏗 Architecture du projet

```
MediaSync/
├── Package.swift              # Configuration Swift Package Manager
├── build.sh                   # Script de compilation et packaging
├── README.md                  # Ce fichier
├── CHANGELOG.md               # Historique des versions
├── DISTRIBUTION.md            # Guide détaillé de distribution
└── Sources/
    ├── MediaSyncApp.swift           # Point d'entrée de l'application
    ├── ContentView.swift            # Interface utilisateur SwiftUI
    ├── MediaSyncMonitor.swift       # Logique de monitoring principal
    ├── AudioCaptureManager.swift    # Capture audio ScreenCaptureKit
    └── UpdateChecker.swift          # Vérification des mises à jour GitHub
```

---

## 🔧 Configuration pour les développeurs

### Modifier le repository GitHub pour les mises à jour

Dans `Sources/UpdateChecker.swift`, modifiez :

```swift
static let githubOwner = "VotreUsername"
static let githubRepo = "MediaSync"
```

### Modifier l'identifiant de l'application

Dans `build.sh`, modifiez :

```bash
BUNDLE_ID="com.votrenom.mediasync"
```

---

## 📝 Notes techniques

- Utilise `pmset -g assertions` pour détecter la lecture dans Premiere Pro et DaVinci Resolve
- Utilise **ScreenCaptureKit** pour capturer l'audio d'After Effects en temps réel
- Contrôle Spotify et Apple Music via AppleScript
- Interface 100% SwiftUI avec animations natives
- Stockage des préférences via `@AppStorage` (UserDefaults)
- Vérification des mises à jour via l'API GitHub Releases

---

## ❓ FAQ

### L'app ne se lance pas / "Application endommagée"

```bash
xattr -cr /Applications/MediaSync.app
```

### Comment forcer la vérification des mises à jour ?

Menu **MediaSync → Rechercher des mises à jour**

### Les navigateurs ne sont pas détectés

Activez "Autoriser JavaScript via Apple Events" dans chaque navigateur (voir tableau ci-dessus).

### After Effects n'est pas détecté

Accordez la permission d'enregistrement d'écran dans **Préférences Système → Confidentialité → Enregistrement d'écran**.

---

## 📄 Licence

MIT License - Voir [LICENSE](LICENSE) pour plus de détails.

---

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou une pull request.

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push sur la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request
