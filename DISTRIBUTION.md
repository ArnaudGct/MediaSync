# Guide de Distribution de MediaSync

## 📦 Méthodes de Distribution

### 1. Distribution Simple (Gratuit)

#### Compilation

```bash
./build.sh
```

Cela génère :

- `dist/MediaSync.app` - L'application
- `dist/MediaSync-2.1.dmg` - Le fichier DMG à distribuer

#### Partage

- **AirDrop** : Envoyez directement le DMG
- **Cloud** : Google Drive, Dropbox, iCloud
- **GitHub Releases** : Téléchargez le DMG dans les releases

#### Installation par l'utilisateur

1. Double-clic sur le DMG
2. Glisser MediaSync vers le dossier Applications
3. Éjecter le DMG
4. Premier lancement : Clic droit → Ouvrir → Confirmer

⚠️ **Sans signature Apple, l'utilisateur verra un avertissement de sécurité**

---

### 2. Distribution avec GitHub Releases (Recommandé)

#### Création d'une Release

```bash
# Taguer la version
git tag v2.1.0
git push origin v2.1.0

# Puis sur GitHub :
# 1. Aller dans "Releases"
# 2. Créer une nouvelle release
# 3. Uploader le DMG
```

#### Avantages

- Historique des versions
- Notes de mise à jour
- Téléchargement facile pour les utilisateurs

---

### 3. Distribution avec Signature Apple (Professionnel)

Pour éviter les avertissements de Gatekeeper :

#### Prérequis

- Compte Apple Developer (99$/an)
- Certificat "Developer ID Application"

#### Processus

```bash
# 1. Signer l'application
codesign --force --options runtime --sign "Developer ID Application: Votre Nom (TEAMID)" "dist/MediaSync.app"

# 2. Notariser l'application
xcrun notarytool submit "dist/MediaSync-2.1.dmg" --apple-id "email@example.com" --password "app-specific-password" --team-id "TEAMID" --wait

# 3. Agrafer le ticket
xcrun stapler staple "dist/MediaSync-2.1.dmg"
```

---

## 🔄 Gestion des Mises à Jour

### Option A : Manuelle (Simple)

1. **Versioning** : Incrémentez la version dans `build.sh`

   ```bash
   <key>CFBundleVersion</key>
   <string>2.2.0</string>
   <key>CFBundleShortVersionString</key>
   <string>2.2</string>
   ```

2. **Recompilez** : `./build.sh`

3. **Partagez** : Le nouveau DMG via GitHub Releases ou votre méthode préférée

4. **L'utilisateur** : Télécharge et remplace l'ancienne version

### Option B : Mise à jour automatique avec Sparkle

Sparkle est le standard pour les mises à jour automatiques sur macOS.

#### 1. Ajouter Sparkle au projet

Modifiez `Package.swift` :

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MediaSync",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MediaSync",
            dependencies: ["Sparkle"],
            path: "Sources"
        )
    ]
)
```

#### 2. Créer un fichier appcast.xml

Hébergez ce fichier sur votre serveur ou GitHub Pages :

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>MediaSync Updates</title>
        <item>
            <title>Version 2.2</title>
            <sparkle:version>2.2.0</sparkle:version>
            <sparkle:shortVersionString>2.2</sparkle:shortVersionString>
            <description>
                <![CDATA[
                    <h2>Nouveautés</h2>
                    <ul>
                        <li>Correction de bugs</li>
                        <li>Amélioration des performances</li>
                    </ul>
                ]]>
            </description>
            <pubDate>Thu, 27 Nov 2025 12:00:00 +0000</pubDate>
            <enclosure url="https://votre-serveur.com/MediaSync-2.2.dmg"
                       sparkle:version="2.2.0"
                       type="application/octet-stream"
                       length="5000000"/>
        </item>
    </channel>
</rss>
```

#### 3. Ajouter dans Info.plist

```xml
<key>SUFeedURL</key>
<string>https://votre-serveur.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>VOTRE_CLE_PUBLIQUE</string>
```

### Option C : GitHub comme serveur de mises à jour

Créez un workflow GitHub Actions pour automatiser :

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build
        run: ./build.sh

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: dist/*.dmg
```

---

## 📋 Checklist avant publication

- [ ] Incrémenter le numéro de version
- [ ] Tester sur un Mac propre
- [ ] Mettre à jour le README avec les changements
- [ ] Créer un tag git
- [ ] Compiler en mode release
- [ ] Tester le DMG
- [ ] Publier la release

---

## 🔢 Convention de Versioning

Utilisez le **Semantic Versioning** :

- `MAJOR.MINOR.PATCH` (ex: 2.1.0)
- **MAJOR** : Changements incompatibles
- **MINOR** : Nouvelles fonctionnalités
- **PATCH** : Corrections de bugs

---

## 💡 Conseils

1. **Gardez un CHANGELOG.md** pour documenter les changements
2. **Testez toujours** sur un Mac qui n'a jamais eu l'app
3. **Fournissez des notes de version** claires
4. **Conservez les anciennes versions** au cas où
