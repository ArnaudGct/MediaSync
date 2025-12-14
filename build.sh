#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# Build Script pour MediaSync
# Application macOS native en Swift/SwiftUI
# ═══════════════════════════════════════════════════════════════════════════════

set -e

APP_NAME="MediaSync"
BUNDLE_ID="com.mediasync.app"
BUILD_DIR="$(pwd)/.build/release"
APP_BUNDLE="$(pwd)/dist/${APP_NAME}.app"

# ⚠️ VERSION - Modifiez ces valeurs lors d'une mise à jour
VERSION="1.1.0"
VERSION_SHORT="1.1"

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  🔨 Building ${APP_NAME} v${VERSION}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Mettre à jour la version dans UpdateChecker.swift
echo "📝 Mise à jour de la version dans le code..."
sed -i '' "s/static let currentVersion = \".*\"/static let currentVersion = \"${VERSION}\"/" Sources/UpdateChecker.swift

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  🔨 Building ${APP_NAME}"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Vérifier Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode Command Line Tools non installé"
    echo "   Installez avec: xcode-select --install"
    exit 1
fi

echo "📦 Compilation en mode Release..."
swift build -c release

echo ""
echo "📁 Création du bundle .app..."

# Créer le dossier dist
rm -rf "dist"
mkdir -p "dist"

# Créer la structure du bundle
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copier l'exécutable
cp "${BUILD_DIR}/MediaSync" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Créer l'icône de l'application
echo "🎨 Création de l'icône..."
ICONSET_DIR="${APP_BUNDLE}/Contents/Resources/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

# Exporter la variable pour Python
export ICONSET_DIR

# Générer l'icône avec Python
python3 << 'PYTHON_SCRIPT'
import os

iconset_dir = os.environ.get('ICONSET_DIR')
print(f"Création des icônes dans: {iconset_dir}")

try:
    from PIL import Image, ImageDraw
    
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    def create_icon(size):
        # Créer une image avec transparence
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        center = size // 2
        radius = size // 2
        
        # === CERCLE VERT FLAT ===
        # Couleur verte accent MediaSync: rgb(49, 209, 89)
        draw.ellipse([0, 0, size - 1, size - 1], fill=(49, 209, 89, 255))
        
        # === WAVEFORM BLANC ===
        wave_height = int(radius * 0.7)
        bar_width = max(3, int(size / 16))
        bar_gap = max(2, int(size / 20))
        num_bars = 5
        total_width = num_bars * bar_width + (num_bars - 1) * bar_gap
        start_x = center - total_width // 2
        
        # Hauteurs des barres (pattern waveform symétrique)
        heights = [0.35, 0.65, 1.0, 0.65, 0.35]
        
        for i, h in enumerate(heights):
            bar_height = int(wave_height * h)
            x = start_x + i * (bar_width + bar_gap)
            y = center - bar_height // 2
            
            # Barre blanche avec coins arrondis
            corner_radius = bar_width // 2
            draw.rounded_rectangle(
                [x, y, x + bar_width, y + bar_height],
                radius=corner_radius,
                fill=(255, 255, 255, 255)
            )
        
        return img
    
    for size in sizes:
        img = create_icon(size)
        
        if size == 16:
            img.save(f"{iconset_dir}/icon_16x16.png")
        elif size == 32:
            img.save(f"{iconset_dir}/icon_16x16@2x.png")
            img.save(f"{iconset_dir}/icon_32x32.png")
        elif size == 64:
            img.save(f"{iconset_dir}/icon_32x32@2x.png")
        elif size == 128:
            img.save(f"{iconset_dir}/icon_128x128.png")
        elif size == 256:
            img.save(f"{iconset_dir}/icon_128x128@2x.png")
            img.save(f"{iconset_dir}/icon_256x256.png")
        elif size == 512:
            img.save(f"{iconset_dir}/icon_256x256@2x.png")
            img.save(f"{iconset_dir}/icon_512x512.png")
        elif size == 1024:
            img.save(f"{iconset_dir}/icon_512x512@2x.png")
    
    print("✓ Icônes générées (flat design)")
except Exception as e:
    print(f"Erreur: {e}")
PYTHON_SCRIPT

# Convertir l'iconset en icns
if [ -d "${ICONSET_DIR}" ]; then
    echo "📦 Conversion en icns..."
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
    echo "✓ Icône créée"
fi

# Créer Info.plist avec icône
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION_SHORT}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Cette application nécessite l'accès à AppleScript pour contrôler Spotify et Apple Music.</string>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Cette application nécessite l'accès à l'enregistrement d'écran pour détecter l'audio d'After Effects.</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2025 Arnaud Graciet. Vibe-codée avec ❤️</string>
    <key>CFBundleGetInfoString</key>
    <string>MediaSync ${VERSION} - Vibe-codée avec ❤️ par Arnaud Graciet - https://arnaudgct.fr/</string>
</dict>
</plist>
EOF

# Signer l'application (ad-hoc)
echo ""
echo "🔐 Signature de l'application..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# Créer un DMG pour la distribution
echo ""
echo "📀 Création du DMG..."
DMG_NAME="${APP_NAME}-$(cat "${APP_BUNDLE}/Contents/Info.plist" | grep -A1 CFBundleShortVersionString | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/').dmg"

# Créer un dossier temporaire pour le DMG
DMG_TEMP="dist/dmg_temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copier l'app
cp -r "${APP_BUNDLE}" "${DMG_TEMP}/"

# Créer un lien symbolique vers Applications
ln -s /Applications "${DMG_TEMP}/Applications"

# Créer le DMG
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "dist/${DMG_NAME}"

# Nettoyer
rm -rf "${DMG_TEMP}"

echo "✓ DMG créé: dist/${DMG_NAME}"

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "  ✅ Build terminé avec succès!"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "  📍 Application: dist/${APP_NAME}.app"
echo "  📀 DMG:         dist/${DMG_NAME}"
echo ""
echo "  💡 Pour installer dans Applications:"
echo "     cp -r \"dist/${APP_NAME}.app\" /Applications/"
echo ""
echo "  🚀 Pour lancer:"
echo "     open \"dist/${APP_NAME}.app\""
echo ""

# Ouvrir le dossier dist
open "dist/"
