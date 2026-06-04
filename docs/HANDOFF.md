# Passation — terminer BamPocket

> Document de relais. Donne ce prompt (ou pointe ce fichier) à l'agent qui terminera le projet.
> État au moment de la passation : phases 0→3 + une bonne partie de la longue traîne intégrées,
> CI verte, ~80 tests. Voir `PROGRESS.md` / `ROADMAP.md` pour le détail vivant.

## MISSION
Intégrer le **maximum** de fonctionnalités de Bambuddy pour que l'app permette de **se passer
quasi entièrement de l'interface web** (quasi-parité). Tu tournes en **autonomie complète** ;
n'interromps que sur un vrai blocage (court questionnaire à réponses pré-remplies).

## 0. À lire d'abord
- Repo (public) : github.com/clabeuhtegrite/bambuddy-pocket — branche : `claude/cloud-dev-environment-aAJAg`
  (ou branche depuis `main` si la PR est mergée). Workflow : branches + PR, CI verte avant merge.
- Lis : `PROGRESS.md`, `ROADMAP.md`, `docs/bambuddy-api.md`, `docs/api/openapi.json` +
  `docs/api/rest-endpoints.md` (621 opérations), `docs/adr/`.
- Déjà fait (vert CI, ≈32 endpoints + WebSocket) : multi-serveurs + auth (clé d'API /
  user-pass+2FA / Cloudflare, Keychain) ; temps réel WebSocket + fusion deltas ; imprimantes
  (liste, détail, contrôles pause/reprise/stop, vitesse, lumière, clear HMS, AMS unload, séchage,
  création) ; caméra (snapshot + MJPEG) ; archive (liste/recherche/détail, stats, download→viewer
  3D STL/3MF, ajout-à-la-file) ; file (liste, ajout, réordo, start/cancel/delete) ; activité ;
  inventaire bobines ; bibliothèque (fichiers) ; projets ; notifications en-app dérivées du WS ;
  À propos/crédits.

## 1. Avantage-clé : Mac + Xcode
L'agent précédent ne pouvait PAS exécuter l'app. TOI SI. Donc :
1. Lance un Bambuddy de dev en Docker (cf. README) + imprimante virtuelle (docs §11) ;
   `curl localhost:8000/api/v1/...` pour voir les VRAIES réponses.
2. **Vérifie/ajuste chaque contrat d'API au réel** — c'est là que sont les écarts. Bug déjà
   trouvé : `requires_2fa` se décode en `requires2Fa` (majuscule après un chiffre). Couvre chaque
   décodage par un test.
3. `brew install xcodegen swiftlint swiftformat` ; `xcodegen generate` ;
   `xcodebuild -scheme BamPocket -destination 'platform=iOS Simulator,name=iPhone 17' test` ;
   `(cd Packages/BambuddyPocketKit && swift test)`. Lance l'app et clique partout.

## 2. Architecture (à respecter)
- Paquet SPM `BambuddyPocketKit` : `…Domain` (modèles Codable + logique pure), `…Networking`
  (RESTClient/WebSocketClient/CameraStream, endpoints, ServerConnectionFactory), `…DesignSystem`.
- App `BambuddyPocket` : composition root `AppEnvironment` ; hub `ServerListModel` qui fabrique
  les view-models par écran (`makeXxxModel(for:)`). View-models = `@MainActor @Observable final class`.
- JSON : `JSONDecoder.bambuddy()` / `JSONEncoder.bambuddy()` (snake_case + iso8601). Modélise des
  SOUS-ENSEMBLES robustes (champs optionnels, dates en `String` si doute) — clés inconnues ignorées.
- Endpoints = extensions sur `APIClient` dans `BambuddyEndpoints.swift` (`get`/`post`/`delete`) ;
  données brutes via `RESTClient.data(forPath:)`. En-têtes auth/Cloudflare via
  `RequestAuthorization.headerFields` (REST + WS + caméra). Secrets au Keychain uniquement.

## 3. Recette pour ajouter une fonction (copie le pattern archive/inventory/projects)
Lecture : 1) modèle Domain `Codable, Sendable, Hashable, Identifiable` ; 2) endpoint + test
endpoint (suite sérialisée `MockNetworkingTests`) + test de décodage Domain ; 3) `XxxListModel`
+ `ServerListModel.makeXxxModel` ; 4) `XxxListView` (List + `.searchable` + overlay + `.task`/
`.refreshable`) (+ détail) + `NavigationLink` dans `ServerDetailView` ; 5) i18n dans
`Localizable.xcstrings` (EN source + fr/es/de). Écriture : endpoint POST/PATCH/DELETE + méthode
view-model + bouton/swipe + confirmation + recharge.

## 4. Règles dures (sinon CI rouge — tu builds en local, vérifie avant de pousser)
`swiftformat --lint .` ET `swiftlint --strict` doivent passer. Pièges rencontrés :
- pas de `@ViewBuilder` sur un membre à expression unique ; utilise des switch/if-EXPRESSIONS
  (pas de `return`/assignation redondants) ; pas d'init memberwise redondant ; doc `///` collé à
  la déclaration sinon `//` détaché ; **120 colonnes max** (raccourcis le littéral ou wrappe
  l'appel) ; `String(bytes:encoding:)` (pas `decoding:as:`) ; `NSLock.withLock {}` en async ;
  **force-unwrap = erreur** (`try #require` en test, `??`/`guard` en code).
- Toute chaîne visible → String Catalog (FR/EN/ES/DE). Accessibilité (VoiceOver/Dynamic Type) sur
  chaque écran. Commits Conventional Commits, atomiques. Tiens `PROGRESS.md`/`ROADMAP.md` à jour.

## 5. Backlog priorisé (vers la parité web — fais-en le MAXIMUM)
### Tier 1 — approfondir le cœur
- printers : skip-objects (+`print/objects`), clear-plate, AMS **load**/reset, séchage paramétré,
  calibration, home-axes/bed-jog, print-options, connect/disconnect, édition/suppression imprimante.
- queue : **batches**, **planification** (`scheduled_time`), édition d'item (PATCH), bulk,
  `background-dispatch`.
- archives : photos/vignettes/timelapse, favori (PATCH), notes/tags, suppression, recherche
  serveur, purge.
- camera : **token de flux** si auth, `camera/status`, détection plateau.
- library : arbre de **dossiers**, détail, download→3D, enqueue, upload, renommage/déplacement,
  corbeille. projects : détail/création/édition + items. inventory : détail/édition bobine,
  assignments, usage, shopping-list, catalogue, couleurs.

### Tier 2 — réglages, serveur, comptes
- settings (langue/devise/imprimante par défaut), system (info/health/storage), users (profil),
  **api-keys** (CRUD), groups, notification-templates, user-notifications.
- AUTH complète : OIDC/LDAP, 2FA email-send + codes de secours, logout, **refresh/relogin du JWT**.

### Tier 3 — intégrations (vérifier le contrat au réel)
- spoolman (+inventory), spoolbuddy (RFID), cloud (Bambu), makerworld, obico, **smart-plugs**
  (alim on/off — confirmer le body de `/{id}/control` + champ d'état), firmware, maintenance,
  slicer-presets/slice-jobs, discovery, virtual-printers, sauvegardes (github/local), kprofiles,
  labels, filament-catalog, external-links, print-log, metrics, updates, support, bug-report.

### Transverse / App Store
- **Notifications** : session WS persistante au niveau serveur (pas seulement l'écran imprimantes).
- Perf : parseur MJPEG par blocs (au lieu d'octet-par-octet) ; pagination des grandes listes.
- UX : iPad (NavigationSplitView), mode sombre, états vides/erreurs/offline, Dynamic Type, VoiceOver.
- Tests : **XCUITest** sur chemins critiques + étendre l'unitaire.
- App Store : icône + launch screen, captures, privacy manifest + déclarations, mentions OSS (faites).
- Pré-publication (non codable, à signaler) : **clearance marque « Bambuddy » + relecture
  juridique AGPL/exception**, compte Apple Developer, TestFlight.

## 6. Definition of Done
Tier 1 en profondeur ; Tier 2 couvert ; Tier 3 au maximum du vérifiable. App utilisable de bout en
bout en réel (Docker / imprimante virtuelle), équivalente à l'usage courant du web. CI VERTE, tests
unitaires + UI. `PROGRESS.md`/`ROADMAP.md` à jour ; build sans warning.

**Démarrage** : (1) lance le Docker Bambuddy + l'app ; (2) vérifie les contrats des écrans déjà
faits contre les vraies réponses et corrige les écarts ; (3) déroule le Tier 1 ; PR verte en continu.
