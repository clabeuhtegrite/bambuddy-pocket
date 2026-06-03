# Roadmap — Bambuddy Pocket

Roadmap priorisée, dérivée de la reconnaissance d'API (cf. [`docs/bambuddy-api.md`](docs/bambuddy-api.md)).
État d'avancement vivant dans [`PROGRESS.md`](PROGRESS.md).

Légende : ⬜ à faire · 🟦 en cours · ✅ fait

---

## Étape 1 — Reconnaissance (préalable au code app) ✅
- ✅ Cloner Bambuddy, lancer l'instance Docker locale (backend de dev).
- ✅ Cartographier l'API : REST (621 ops via OpenAPI), WebSocket (événements), schémas, auth.
- ✅ Produire `docs/bambuddy-api.md` (contrat) + `docs/api/` (openapi.json, catalogue).
- ✅ Lire la LICENSE (AGPL-3.0) → ADR-0001 (décision en attente).
- 🟦 Proposer périmètre MVP + roadmap (ce document) — **à valider**.

## Phase 0 — Socle 🟦
Projet Xcode (iPhone+iPad, iOS 18), MVVM, et fondations transverses.
- ✅ Projet Xcode (XcodeGen) + structure de modules (App + paquet SPM Domain/Networking/DesignSystem).
- 🟦 Couche réseau : client REST (`async/await`) + client WebSocket (TLS, reconnexion, ping/pong).
- ⬜ Injection des en-têtes **Cloudflare Access** + Bearer/X-API-Key sur REST **et** WS **et** caméra.
- 🟦 Modèles de domaine d'après le contrat (✅ PrinterStatus/AMS/HMS/Printer ; ⬜ Archive, QueueItem…).
- ⬜ Multi-serveurs : ajout/édition par URL, test de connexion, stockage **Keychain** des secrets.
- ⬜ Auth : détection `auth_status`, login user/pass + 2FA, clé d'API, sans-auth.
- 🟦 Design system (✅ tokens ; ⬜ composants, typographie Dynamic Type), mode sombre.
- ✅ i18n FR/EN/ES/DE (String Catalog) ; ⬜ accessibilité (VoiceOver) au fil de l'eau.
- ✅ Privacy manifest + `NSLocalNetworkUsageDescription` + ATS (exception HTTP local).
- ✅ CI : build + tests + lint (SwiftLint/SwiftFormat) + shellcheck sur push/PR.

## Phase 1 — MVP cœur (lecture, testable sur la démo) ⬜
- ⬜ **Liste multi-imprimantes** + statut **temps réel** (WebSocket, fusion des deltas).
- ⬜ **Détail imprimante** : température (buse/plateau/chambre), progression (couches, temps
  restant), état, AMS/bobines, ventilateurs, lumière chambre, **erreurs HMS** (code+sévérité+texte).
- ⬜ **Caméra** : flux MJPEG + snapshot (token si auth).
- ⬜ **Archive d'impressions** : liste (`ArchiveSlim`), détail (`ArchiveResponse`), vignettes,
  photos, métadonnées, coût/énergie, timelapse.
- ⬜ État serveur (`/system/info`, santé) + sélecteur de serveur.

## Phase 2 — Actions (écritures, Docker local / imprimante virtuelle) ⬜
- ⬜ **Contrôles d'impression** : pause/reprise/stop, skip-objects, vitesse, lumière, clear-plate,
  AMS load/unload, séchage, clear HMS.
- ⬜ **File d'attente & planification** : liste, ajout, **réordonnancement (drag/drop)**,
  start/stop/cancel, lots (batches), planification (`scheduled_time`), distribution auto.
- ⬜ **Notifications EN-APP** dérivées du WebSocket (fin d'impression, début, HMS sévère,
  bobine manquante, plateau non vide) + flux d'activité (`notifications/logs`).
- ⬜ Gestion d'imprimante côté serveur (ajout/édition `PrinterCreate`).

## Phase 3 — Avancé ⬜
- ⬜ **Viewer 3D** des 3MF/STL/gcode (décision d'approche : SceneKit/RealityKit + parseur natif,
  ou WebView Three.js en v1 — cf. `gcode_viewer` amont). ADR à rédiger.
- ⬜ **Slicing** : déclenchement du sidecar serveur (OrcaSlicer/Bambu Studio) s'il est activé
  (`use_slicer_api`, `slice-jobs`) — non testable sur la démo.
- ⬜ Bibliothèque de modèles/projets, inventaire filaments/Spoolman/SpoolBuddy, intégrations
  (cloud, smart-plugs, Obico, MakerWorld) selon priorité.

## Transverse / sortie App Store ⬜
- ⬜ Tests (unitaires + UI) sur chemins critiques ; build sans warning.
- ⬜ Icône, launch screen, captures, classification d'âge, mentions open source.
- ⬜ Privacy manifest + déclarations de collecte ; conformité HIG + App Review.
- ⬜ Étapes nécessitant le compte Apple Developer (à la charge de l'utilisateur) : enrôlement,
  signature distribution, TestFlight, soumission, réponses à la revue.
