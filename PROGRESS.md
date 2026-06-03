# PROGRESS — état vivant du projet Bambuddy Pocket

> **But** : permettre une reprise propre (par moi-même après un blocage quota, ou par le
> superviseur externe). Mis à jour et commité régulièrement. Voir [`ROADMAP.md`](ROADMAP.md).

**Dernière mise à jour** : 2026-06-03 — Phase 0 en cours : socle + couche réseau + persistance
faits ; UI multi-serveurs câblée. Repo : https://github.com/clabeuhtegrite/bambuddy-pocket (privé).

## 🔆 Prochaine action (point de reprise)
**Phase 0 — couche réseau.** Le socle (projet XcodeGen, paquet SPM `BambuddyPocketKit`, app SwiftUI
minimale, i18n, CI iOS) et les modèles de domaine (PrinterStatus/AMS/HMS/Printer + décodage testé)
sont faits. ✅ `RESTClient`/`RequestFactory` (PR #4). ✅ `SecretStore` (Keychain + InMemory),
`ServerStore` (UserDefaults), mapping `ServerSecrets`→`RequestAuthorization` (PR #5).
✅ `ServerConnectionFactory` + sonde `/auth/status` (PR #6).
✅ **Composition root** `AppEnvironment` (live/inMemory) + view-model `ServerListModel` (`@MainActor
@Observable`) + **UI multi-serveurs** : liste, ajout/édition par URL (`ServerURLParser`), secrets
Keychain (clé d'API + Cloudflare Access), test de connexion `/auth/status`, avertissement HTTP en
clair, i18n FR/EN/ES/DE (branche `claude/cloud-dev-environment-aAJAg`). Prochaine brique :
1. **Auth interactive** : login user/pass → JWT (`POST /auth/login`), 2FA (`/auth/2fa/verify`),
   `GET /auth/me` ; rafraîchissement/relogin du JWT. (La méthode `userPassword` est déjà modélisée
   mais non exposée dans le formulaire tant que le flux login n'est pas implémenté.)
2. `WebSocketClient` (URLSessionWebSocketTask, reconnexion, ping/pong, en-têtes auth + Cloudflare)
   + fusion des deltas `PrinterStatus`.
Puis **Phase 1** (liste imprimantes temps réel, détail, archive).
Cadence : **autonomie complète** ; n'arrêter que sur vrai blocage → documenter + `scripts/notify/notify.sh "…"`.
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
