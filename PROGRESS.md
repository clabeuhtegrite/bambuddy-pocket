# PROGRESS — état vivant du projet Spoolside

> **But** : permettre une reprise propre (par moi-même après un blocage quota, ou par le
> superviseur externe). Mis à jour et commité régulièrement. Voir [`ROADMAP.md`](ROADMAP.md).

**Dernière mise à jour** : 2026-06-02 — Étape 1 + socle dépôt terminés ; dépôt poussé.
Repo : https://github.com/clabeuhtegrite/spoolside (privé).

## 🔆 Prochaine action (point de reprise)
1. **Checkpoint utilisateur présenté** : proposition MVP + recommandation de licence
   (« avant le code applicatif »). Décisions en attente : licence, cadence d'autonomie.
2. **Démarrer Phase 0** (projet Xcode + socle), voir ROADMAP. Le socle ne pose PAS d'en-têtes
   de licence par fichier → il peut commencer **sans** attendre la décision licence (LICENSE
   figé plus tard, avant publication). Travailler sur branche `feat/phase0-socle` + PR, CI verte.
   → Si exécution **non supervisée/headless** : démarrer Phase 0 avec licence **provisoire
     différée** ; ne pas figer `LICENSE`.

## ✅ Fait
- **Recon environnement** : git (`clabeuhtegrite`), gh (scopes `repo`+`workflow`), Docker 29,
  Xcode 26.5 (via `DEVELOPER_DIR`, cf. ci-dessous).
- **Instance Bambuddy Docker locale** lancée (`/Users/ad/bambuddy-upstream`, ports 8000/3000/3002/8883).
- **Cartographie API complète** → `docs/bambuddy-api.md`, `docs/api/openapi.json`,
  `docs/api/rest-endpoints.md` (621 ops, 346 schémas, événements WS, auth).
- **ADR** : 0001 licence (décision en attente), 0002 architecture, 0003 connectivité/sécurité.
- Gouvernance : README, ROADMAP, PROGRESS, CONTRIBUTING, NOTICE, configs SwiftLint/SwiftFormat/EditorConfig.
- **CI** GitHub Actions (lint, build/test iOS, shellcheck).
- **Superviseur externe** launchd (`scripts/supervisor/`) avec retry/back-off quota + doc d'install.
- **Dépôt privé `spoolside` créé et poussé** (commit initial).

## 🟦 En cours
- Checkpoint utilisateur (proposition MVP + licence) — présenté, en attente de réponse.

## ⬜ À faire (résumé)
- Phases 0→3 (cf. ROADMAP). Superviseur externe (launchd) + docs.

## 🔑 Décisions en attente (utilisateur)
- **Licence** (ADR-0001) : AGPL/GPL + exception App Store **vs** Apache-2.0/MPL-2.0.
- **Viewer 3D** (Phase 3) : natif (SceneKit/RealityKit) vs WebView Three.js — ADR à venir.

## ⚠️ Risques / points ouverts
- AGPL ↔ App Store (cf. ADR-0001) — figer la licence avant publication.
- Auth WebSocket sur instance authentifiée — à valider (cf. `docs/bambuddy-api.md` §12).
- Compte Apple Developer absent → build simulateur OK ; device/TestFlight/soumission = utilisateur.

## 🧭 Repères environnement (pour reprise)
- **Working dir / repo local** : `/Users/ad/Bambuddy Pocket` (dossier local ; repo distant = `spoolside`).
- **Bambuddy amont (référence, hors repo)** : `/Users/ad/bambuddy-upstream` (clone + Docker).
- **Recon scratch (hors repo)** : `/Users/ad/spoolside-recon`.
- **Xcode** : `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` avant `xcodebuild`/`xcrun`.
- **Docker** : `cd /Users/ad/bambuddy-upstream && docker compose up -d` ; API `http://localhost:8000`.
- **git** : identité déjà configurée (ne PAS toucher la config globale). `gh` authentifié.

## 🗒️ Journal (récent en haut)
- **2026-06-02** — Étape 1 : recon API complète, contrat écrit, ADR licence, scaffolding entamé.
