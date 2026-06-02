# Contribuer à Spoolside

Merci de contribuer ! Ce projet vise une qualité **production / App Store**.

## Pré-requis
- macOS + **Xcode 26+** (iOS 18 SDK minimum).
- [SwiftLint](https://github.com/realm/SwiftLint) + [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
  (`brew install swiftlint swiftformat`).
- Docker (pour l'instance Bambuddy de dev — cf. [README](README.md)).

> Si `xcodebuild` cible les Command Line Tools au lieu d'Xcode :
> `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (ou `sudo xcode-select -s …`).

## Flux de travail
1. **Brancher** depuis `main` : `git switch -c feat/ma-fonctionnalite`.
2. Développer en **petits commits atomiques**.
3. `swiftformat .` puis `swiftlint` — **zéro warning**.
4. Lancer les tests (`xcodebuild test` ou `swift test` pour `SpoolsideKit`).
5. Ouvrir une **PR** vers `main`. La **CI doit être verte** avant merge.

## Convention de commits — [Conventional Commits](https://www.conventionalcommits.org/)
Format : `type(scope): sujet` (impératif, ≤ ~72 car.).
Types : `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `perf`, `style`.
Exemples :
```
feat(networking): client WebSocket avec reconnexion et ping/pong
fix(printers): fusion des deltas de statut temps réel
docs(adr): ADR-0004 viewer 3D
```

## Style & architecture
- Respecter [ADR-0002](docs/adr/0002-architecture.md) (MVVM, DI maison, séparation des couches)
  et [ADR-0003](docs/adr/0003-connectivite-securite.md) (secrets Keychain, en-têtes centralisés).
- SwiftUI + `@Observable` ; view-models `@MainActor` ; `async/await`.
- **Aucun secret** dans le code/les logs/le dépôt.
- i18n : toute chaîne visible passe par les catalogues (FR/EN/ES/DE). Accessibilité (VoiceOver,
  Dynamic Type) sur les nouveaux écrans.

## Tests
- Logique de domaine et décodage réseau : tests unitaires (fixtures JSON).
- Chemins critiques UI : XCUITest.

## Sécurité
Voir [SECURITY](docs/SECURITY.md) (à venir) ; signaler les vulnérabilités en privé.
