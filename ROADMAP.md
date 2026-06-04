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
- ✅ Couche réseau : client REST (`async/await`) + client WebSocket (ping, reconnexion appelant).
- 🟦 Injection des en-têtes **Cloudflare Access** + Bearer/X-API-Key sur REST **et** WS (✅) **et** caméra (⬜).
- 🟦 Modèles de domaine d'après le contrat (✅ PrinterStatus/AMS/HMS/Printer + événements WS + fusion ; ⬜ Archive, QueueItem…).
- ✅ Multi-serveurs : ajout/édition par URL, test de connexion, stockage **Keychain** des secrets.
- 🟦 Auth : détection `auth_status` (✅ sonde), clé d'API (✅), sans-auth (✅) ; ⬜ login user/pass + 2FA.
- 🟦 Design system (✅ tokens ; ⬜ composants, typographie Dynamic Type), mode sombre.
- ✅ i18n FR/EN/ES/DE (String Catalog) ; ⬜ accessibilité (VoiceOver) au fil de l'eau.
- ✅ Privacy manifest + `NSLocalNetworkUsageDescription` + ATS (exception HTTP local).
- ✅ CI : build + tests + lint (SwiftLint/SwiftFormat) + shellcheck sur push/PR.

## Phase 1 — MVP cœur (lecture, testable sur la démo) 🟦
- ✅ **Liste multi-imprimantes** + statut **temps réel** (WebSocket, fusion des deltas).
- ✅ **Détail imprimante** : température (buse/plateau/chambre), progression (couches, temps
  restant), état, AMS/bobines, **erreurs HMS** (code+sévérité). ⬜ ventilateurs détaillés.
- 🟦 **Caméra** : ✅ snapshot rafraîchi + flux MJPEG, ✅ **détection de plateau vide** (check-plate),
  ✅ **état du flux** (camera/status) + **jeton de flux** (stream-token) ; ⬜ flux authentifié via token.
- 🟦 **Archive d'impressions** : ✅ liste + détail (statut, durée, filament, coût/énergie,
  chronologie) + **recherche serveur** (`/archives/search`), ✅ **favori** (PATCH/toggle),
  ✅ **édition** (tags, notes, nom, lien), ✅ **suppression** ; ⬜ vignettes, photos, timelapse.
- ⬜ État serveur (`/system/info`, santé) + sélecteur de serveur.

## Phase 2 — Actions (écritures, Docker local / imprimante virtuelle) 🟦
- 🟦 **Contrôles d'impression** : ✅ pause/reprise/stop, vitesse, lumière chambre, clear HMS,
  AMS unload/load/reset, séchage, **skip-objects**, **clear-plate**, **home-axes**, **calibration**,
  **connect/disconnect**, **suppression d'imprimante** ; ⬜ print-options, bed-jog, airduct-mode.
- 🟦 **File d'attente** : ✅ liste + **réordonnancement (drag/drop)**, ✅ ajout, ✅ start/stop/cancel/delete,
  ✅ **édition d'item** (PATCH : planification `scheduled_time`, réassignation, options), ✅ **lots
  (batches)** (liste + annulation), ✅ **mise à jour en lot** (`PATCH /queue/bulk`) ; ⬜ distribution
  auto (`background-dispatch`).
- ✅ **Notifications EN-APP** : ✅ flux d'activité (`notifications/logs`) en lecture ; ✅ **dérivation
  temps réel depuis le WebSocket** au niveau serveur (`ServerNotificationCenter`, session WS
  persistante) — fin/début d'impression, **HMS grave** (transition), bobine manquante, plateau non
  vide, archive créée ; feed lu/non-lu + badge + bannières.
- 🟦 Gestion d'imprimante côté serveur : ✅ ajout (`PrinterCreate`), ✅ suppression ; ⬜ édition (PATCH).

## Phase 3 — Avancé ⬜
- ⬜ **Viewer 3D** des 3MF/STL/gcode (décision d'approche : SceneKit/RealityKit + parseur natif,
  ou WebView Three.js en v1 — cf. `gcode_viewer` amont). ADR à rédiger.
- ⬜ **Slicing** : déclenchement du sidecar serveur (OrcaSlicer/Bambu Studio) s'il est activé
  (`use_slicer_api`, `slice-jobs`) — non testable sur la démo.
- 🟦 Bibliothèque de modèles (✅ liste + recherche, détail, ajout à la file, édition nom/notes,
  suppression ; ⬜ dossiers, upload, déplacement) / projets (✅ liste + recherche, détail, création,
  édition, suppression ; ⬜ items/BOM/timeline), **inventaire
  filaments** (✅ liste,
  détail, édition, historique de consommation, reset compteur, suppression) ; ⬜ Spoolman/SpoolBuddy,
  intégrations (cloud, smart-plugs, Obico, MakerWorld) selon priorité.

## Transverse / sortie App Store ⬜
- ⬜ Tests (unitaires + UI) sur chemins critiques ; build sans warning.
- ⬜ Icône, launch screen, captures, classification d'âge, mentions open source.
- ⬜ Privacy manifest + déclarations de collecte ; conformité HIG + App Review.
- ⬜ Étapes nécessitant le compte Apple Developer (à la charge de l'utilisateur) : enrôlement,
  signature distribution, TestFlight, soumission, réponses à la revue.
