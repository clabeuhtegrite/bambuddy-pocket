# PROGRESS — état vivant du projet Bambuddy Pocket

> **But** : permettre une reprise propre (par moi-même après un blocage quota, ou par le
> superviseur externe). Mis à jour et commité régulièrement. Voir [`ROADMAP.md`](ROADMAP.md).

**Dernière mise à jour** : 2026-06-03 — Phase 0 en cours : socle + couche réseau + persistance
faits ; lecture quasi complète + auth. Repo : https://github.com/clabeuhtegrite/bambuddy-pocket (public, en dev).

## 🔆 Prochaine action (point de reprise)
**Phases 0, 1 et 2 largement implémentées** (branche `claude/cloud-dev-environment-aAJAg`, dépôt
public, CI verte). Fait : socle + multi-serveurs + **auth complète** (none / clé d'API / user-pass
+ 2FA / Cloudflare, secrets Keychain) ; **temps réel WebSocket** (events + fusion deltas) ; liste +
détail imprimantes (températures, HMS, AMS) ; **caméra** (snapshot) ; **archive** (liste/détail +
recherche) ; **contrôles** (pause/reprise/stop, vitesse, lumière, clear HMS, AMS unload/séchage) ;
**file d'attente** (liste + réordonnancement drag-drop) ; **flux d'activité**. ~70 tests unitaires.

Prochaines briques (par valeur) :
1. **Notifications en-app dérivées du WebSocket** : exposer une session WS au niveau serveur
   (pas seulement l'écran imprimantes) ; bannières/feed sur `print_complete`/`print_start`/
   `missing_spool_assignment`/`plate_not_empty`/HMS sévère.
2. **Caméra MJPEG réelle** (parseur multipart `x-mixed-replace`) + token de flux si auth.
3. **File** : ajout/start/stop/cancel d'un job, lots (batches), planification.
4. **État serveur** (`/system/info`, santé) ; gestion d'imprimante (`PrinterCreate`).
5. **Phase 3** : viewer 3D (décision d'approche prise en autonomie : WebView Three.js en v1, ADR
   à rédiger), slicing, inventaire.
6. **Finitions App Store** : icône/launch screen, captures, accessibilité, build sans warning.
Cadence : **autonomie complète** ; CI = juge (pas de toolchain en local sur l'env cloud).
Build iOS : `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ; `xcodegen generate` ;
`xcodebuild -project BambuddyPocket.xcodeproj -scheme BambuddyPocket -destination 'platform=iOS Simulator,name=iPhone 17' test`.

## ✅ Fait
- **Recon environnement** : git (`clabeuhtegrite`), gh (`repo`+`workflow`), Docker 29, Xcode 26.5
  (via `DEVELOPER_DIR`).
- **Instance Bambuddy Docker locale** lancée (`/Users/ad/bambuddy-upstream`, ports 8000/3000/3002/8883).
- **Cartographie API complète** → `docs/bambuddy-api.md`, `docs/api/openapi.json`,
  `docs/api/rest-endpoints.md` (621 ops, 346 schémas, événements WS, auth).
- **Décisions actées** : Licence = **AGPL-3.0-or-later + exception App Store** (ADR-0001) ;
  Nom = **Bambuddy Pocket** (ADR-0004) ; cadence = autonomie complète.
- **Licence en place** : `LICENSE` (AGPL-3.0) + `LICENSE-APP-STORE-EXCEPTION.md`.
- **ADR** : 0001 licence, 0002 architecture, 0003 connectivité/sécurité, 0004 nommage.
- **Gouvernance** : README, ROADMAP, PROGRESS, CONTRIBUTING, NOTICE, configs lint/format/editorconfig.
- **CI** GitHub Actions (lint, build/test iOS, shellcheck) — verte sur `main`.
- **Superviseur externe** launchd + **notifier** (ntfy) avec retry/back-off quota & garde heartbeat.
- **Dépôt privé créé, poussé, renommé** `bambuddy-pocket`. PR #1 ouverte (checkpoint).

## 🟦 En cours
- Renommage Spoolside → Bambuddy Pocket (branche `chore/checkpoint-recon`, à merger).
- Activation du superviseur (launchd).

## ⬜ À faire (résumé)
- Phases 0→3 (cf. ROADMAP). Commencer Phase 0.

## 🔑 Décisions en attente (utilisateur)
- **Viewer 3D** (Phase 3) : natif (SceneKit/RealityKit) vs WebView Three.js — ADR à venir (pas urgent).

## ⚠️ Risques / points ouverts
- **Marque « Bambuddy »** (ADR-0004) : risque accepté ; **clearance + accord auteur amont requis
  avant publication**. Plan de repli : renommage (points isolés).
- AGPL ↔ App Store : géré par l'exception §7 ; **relecture juridique avant 1re soumission**.
- Auth WebSocket sur instance authentifiée — à valider (cf. `docs/bambuddy-api.md` §12).
- Compte Apple Developer absent → build simulateur OK ; device/TestFlight/soumission = utilisateur.

## 🧭 Repères environnement (pour reprise)
- **Working dir / repo local** : `/Users/ad/Bambuddy Pocket` (repo distant = `bambuddy-pocket`).
- **Bambuddy amont (référence, hors repo)** : `/Users/ad/bambuddy-upstream` (clone + Docker).
- **Recon scratch (hors repo)** : `/Users/ad/bambuddy-pocket-recon`.
- **Xcode** : `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` avant `xcodebuild`/`xcrun`.
- **Docker** : `cd /Users/ad/bambuddy-upstream && docker compose up -d` ; API `http://localhost:8000`.
- **Contact (blocage)** : `scripts/notify/notify.sh "message"` (ntfy ; config `scripts/notify/notify.env`).
- **git** : identité déjà configurée (ne PAS toucher la config globale). `gh` authentifié.
  Workflow : **branches + PR** (pas de push direct sur `main`).

## 🗒️ Journal (récent en haut)
- **2026-06-03 (22)** — Tier 1 (inventaire bobines en profondeur) : **détail** (`GET
  /inventory/spools/{id}`), **édition** (`PATCH /inventory/spools/{id}` — matériau, marque, couleur,
  poids, coût, catégorie, stockage, note), **historique de consommation** (`GET
  /inventory/spools/{id}/usage`), **réinitialisation du compteur** (`POST …/reset-usage`),
  **suppression** (`DELETE …`). Modèles `SpoolUpdate`/`SpoolUsage` (Domain). Contrats vérifiés au
  réel sur le Docker. UI : feuille d'édition, section Historique + bouton Réinitialiser dans le
  détail (qui reflète les éditions via le view-model), swipe suppression dans la liste. i18n
  FR/EN/ES/DE (6 clés). 109 tests SPM verts, 6 tests app, lint/format OK.
- **2026-06-03 (21)** — Tier 1 (archives en profondeur) : **favori** (`POST /archives/{id}/favorite`,
  bascule), **édition de métadonnées** (`PATCH /archives/{id}` — nom, étiquettes/tags, notes, lien
  externe, favori), **suppression** (`DELETE /archives/{id}`), **recherche serveur**
  (`GET /archives/search?q=…`, plein-texte, ≥2 caractères, repli sur la liste si court). Modèle
  `ArchiveUpdate` + champs `tags`/`notes`/`externalUrl` + `tagList` sur `Archive` (Domain). Contrats
  vérifiés au réel sur le Docker. UI : swipes favori/édition/suppression, étoile + tags dans la liste,
  feuille d'édition, section Notes + bouton Éditer dans le détail, recherche serveur à la soumission.
  i18n FR/EN/ES/DE (10 clés). 103 tests SPM verts, 6 tests app, lint/format OK.
- **2026-06-03 (20)** — Tier 1 (file d'attente en profondeur) : **édition d'item** (`PATCH /queue/{id}`
  — planification `scheduled_time`, réassignation d'imprimante, démarrage manuel, exiger succès
  précédent, power-off, options bed-levelling/timelapse/AMS), **mise à jour en lot** (`PATCH /queue/bulk`),
  **lots** (`GET /queue/batches` + annulation `DELETE /queue/batches/{id}`), **stop** d'un item en cours
  (`POST /queue/{id}/stop`). Modèles `QueueItemUpdate`/`QueueBulkUpdate`/`QueueBulkUpdateResponse`/
  `PrintBatch` + champs éditables sur `QueueItem` (Domain). Contrats vérifiés au réel sur le Docker
  (archive + lot ×3 semés en base ; PATCH n'encode que les champs non-nil pour ne pas écraser via
  `exclude_unset`). UI : section Lots (progression), feuille d'édition, swipes start/edit/stop/cancel.
  i18n FR/EN/ES/DE (16 clés). 96 tests SPM verts, 6 tests app, lint/format OK.
- **2026-06-03 (19)** — Tier 1 (contrôles imprimante en profondeur) : **clear-plate**, **home-axes**,
  **calibration** paramétrée (feuille à cocher), **connect/disconnect**, **AMS load** (par balayage,
  tray_id global = ams×4+slot) + **reset tray**, **skip-objects** (feuille listant `print/objects`),
  **suppression d'imprimante**. Modèle `PrintObjects`/`PrintObject` + `CalibrationOptions` (Domain),
  endpoints + 10 tests (contrats vérifiés au réel sur le Docker via imprimante virtuelle). UI :
  sections Maintenance/Device/Management dans le détail + 2 feuilles (`PrinterMaintenanceSheets`).
  i18n FR/EN/ES/DE (22 clés). 88 tests SPM verts, build iOS OK, lint/format OK.
- **2026-06-03 (18)** — Longue traîne (lecture) : **inventaire bobines** (`/inventory/spools`),
  **bibliothèque de modèles** (`/library/files/`), **projets** (`/projects/`) — modèles, endpoints,
  écrans liste + recherche, liens depuis le détail serveur. Aussi : About/crédits, attribution JS.
- **2026-06-03 (17)** — Phase 3 : **viewer 3D** (décision : WebView + Three.js **embarqué**,
  hors-ligne) — `Model3DView` (WKWebView + WKUserScript), `viewer.html` + Three.js/STLLoader/
  3MFLoader/fflate bundlés, rendu STL/3MF, téléchargement archive (`/archives/{id}/download`),
  lien depuis le détail archive. Aussi : flux **caméra MJPEG** réel (repli snapshots), section
  ventilateurs, accessibilité (cloche).
- **2026-06-03 (16)** — Phase 2 : contrôles **lumière de chambre** (`chamber-light?on=`) et
  **vitesse** (`print-speed?mode=`) — endpoints + UI (toggle « Appareil », sélecteur de vitesse).
  Dépôt passé **public** (CI gratuite) ; README/PROGRESS mis à jour.
- **2026-06-03 (15)** — Phase 0 (auth) : **UI de connexion** — `LoginModel` (flux credentials →
  2FA), `LoginView`, méthode `userPassword` dans le formulaire serveur (login avant enregistrement,
  JWT stocké au Keychain). `ServerConnectionFactory.makeClient(for:secrets:)` (secrets explicites).
- **2026-06-03 (14)** — Phase 0 (auth) : couche **login user/pass + 2FA** — modèles
  (`LoginRequest/Response`, `TwoFAVerify*`, `User`) + endpoints `login`/`verifyTwoFactor`/
  `currentUser` + tests.
- **2026-06-03 (13)** — Phase 2 : **flux d'activité** serveur (`/notifications/logs`) — modèle
  `ActivityEntry`, endpoint `activityLog()`, écran liste (succès/échec, titre, message, date).
- **2026-06-03 (12)** — Phase 2 : **file d'attente** (lecture) — modèle `QueueItem`, endpoint
  `queue()`, écran liste ordonnée (position, imprimante, statut) ; lien depuis le détail serveur.
- **2026-06-03 (11)** — Phase 1 : **caméra** — `RESTClient.data(forPath:)` + `cameraSnapshot`,
  `CameraView` (snapshots rafraîchis ~1 s) + lien dans le détail imprimante.
- **2026-06-03 (10)** — Phase 1 : **archive d'impressions** — modèle `Archive` (sous-ensemble
  robuste d'`ArchiveResponse`, dates en `String`), endpoints `archives()`/`archive(id:)`, écrans
  liste + détail (statut, durée, filament, coût/énergie, chronologie), helper `ErrorMessage`
  partagé, i18n FR/EN/ES/DE. Tests : décodage `Archive` + endpoint.
- **2026-06-03 (9)** — Phase 2 (début) : contrôles d'impression (pause/reprise/arrêt, clear HMS)
  — endpoints REST + boutons dans le détail (confirmation d'arrêt). Correctifs CI : `@ViewBuilder`
  redondants (SwiftFormat) et verrou scopé `NSLock.withLock` dans un helper de test (Swift 6).
- **2026-06-03 (8)** — Phase 1 (cœur) : événements WebSocket (`WebSocketEvent` + décodage) et
  **fusion des deltas** (`PrinterStatus.merged(with:)`) ; endpoints REST typés (`printers()`,
  `printerStatus(id:)`) ; **client WebSocket** (`WebSocketClient`, transport injectable, ping,
  reconnexion côté appelant) ; en-têtes auth/Cloudflare factorisés (`RequestAuthorization.headerFields`,
  appliqués aussi au WS). App : `PrinterListModel` (REST + temps réel fusionné), écrans **liste
  imprimantes** (statut live, badge connexion) et **détail** (état, progression, températures,
  erreurs HMS, AMS) ; i18n FR/EN/ES/DE. Tests : WS/merge/endpoints (+~10).
- **2026-06-03 (7)** — Phase 0 : composition root `AppEnvironment` + view-model `ServerListModel`
  + UI multi-serveurs (liste/ajout/édition/détail, `ServerURLParser`, secrets Keychain, test de
  connexion `/auth/status`, avertissement HTTP, i18n FR/EN/ES/DE). Tests : parser (9) + view-model
  (5). Branche `claude/cloud-dev-environment-aAJAg`.
- **2026-06-03 (6)** — Phase 0 : ServerConnectionFactory + sonde `/auth/status` (AuthStatus) ; tests mock fusionnés en 1 suite sérialisée (PR #6, 27 tests).
- **2026-06-03 (5)** — Phase 0 : secrets/persistance (Keychain SecretStore, ServerStore, mapping auth) — PR #5, 25 tests.
- **2026-06-03 (4)** — Phase 0 : couche REST (RESTClient + RequestFactory auth/Cloudflare) + tests (PR #4, 18 tests).
- **2026-06-03 (3)** — Phase 0 : modèles de domaine PrinterStatus/AMS/HMS/Printer + décodage (PR #3, 13 tests).
- **2026-06-03 (2)** — Phase 0 : socle app (XcodeGen, SPM, i18n, CI iOS) — PR #2 mergée, CI verte.
- **2026-06-03** — Décisions licence (AGPL+exception) & nom (Bambuddy Pocket) ; renommage complet ;
  notifier ntfy + superviseur activés.
- **2026-06-02** — Étape 1 : recon API complète, contrat écrit, ADR, scaffolding, dépôt poussé.
