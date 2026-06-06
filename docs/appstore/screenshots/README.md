# Captures App Store — génération

Captures marketing aux dimensions **App Store iPhone 6.9"** (**1320 × 2868**, iPhone 17 Pro Max),
en thème **sombre**, locales **fr** et **en**.

## Mode démo (aucun backend, aucune imprimante réelle)

Les captures s'appuient sur le **mode démo** intégré à l'app (`-uitest-demo`) : un `URLProtocol`
local (`BambuddyPocket/App/Demo/`) sert des fixtures JSON synthétiques (imprimante en cours, AMS,
archives, file, bibliothèque, G-code d'aperçu). Aucune requête réseau réelle, aucune donnée réelle,
aucun secret. Le temps réel (WebSocket) n'est pas simulé : l'app reste sur l'état REST initial.

## Régénérer

Simulateur cible : **iPhone 17 Pro Max** (6.9"). Barre d'état figée à 09:41 conseillée :

```sh
SIM=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max" | head -1 | grep -oE "[0-9A-F-]{36}")
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl status_bar "$SIM" override --time "09:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
for LANG in fr en; do
  TEST_RUNNER_SCREENSHOT_CAPTURE=1 TEST_RUNNER_SCREENSHOT_LANG=$LANG \
  TEST_RUNNER_SCREENSHOT_APPEARANCE=dark \
  xcodebuild test -project BamPocket.xcodeproj -scheme BamPocket \
    -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" \
    -only-testing:BamPocketUITests/AppStoreScreenshotTests/testCaptureAppStoreScreens
done
```

Le test (`BambuddyPocketUITests/AppStoreScreenshotTests.swift`) écrit dans
`docs/appstore/screenshots/<langue>/`. Il est **ignoré** hors `SCREENSHOT_CAPTURE=1` (donc inerte en
CI). La variable doit être préfixée `TEST_RUNNER_` pour atteindre le processus de test XCUITest.

## Écrans

| Fichier | Écran |
|---|---|
| `01-accueil.png` | Accueil — tableau de bord temps réel |
| `02-detail-imprimante.png` | Détail imprimante — températures + AMS |
| `03-archives.png` | Archives d'impression |
| `04-viewer-3d.png` | Aperçu 3D — parcours G-code |
| `05-file-attente.png` | File d'attente |
