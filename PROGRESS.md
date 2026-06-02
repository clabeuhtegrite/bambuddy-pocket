# PROGRESS — état vivant du projet Spoolside

> **But** : permettre une reprise propre (par moi-même après un blocage quota, ou par le
> superviseur externe). Mis à jour et commité régulièrement. Voir [`ROADMAP.md`](ROADMAP.md).

**Dernière mise à jour** : 2026-06-02 — Étape 1 (recon) terminée ; scaffolding du dépôt en cours.

## 🔆 Prochaine action (point de reprise)
1. Terminer le scaffolding (CONTRIBUTING, ADR-0002/0003, CI, superviseur, configs lint).
2. Créer le dépôt GitHub privé `spoolside` + 1er commit + push.
3. **Présenter à l'utilisateur** : proposition MVP + recommandation de licence (checkpoint
   « avant le code applicatif »). En attendant la réponse licence, ne pas figer `LICENSE`.
4. Démarrer **Phase 0** (projet Xcode + socle) — voir ROADMAP.

## ✅ Fait
- **Recon environnement** : git (`clabeuhtegrite`), gh (scopes `repo`+`workflow`), Docker 29,
  Xcode 26.5 (via `DEVELOPER_DIR`, cf. ci-dessous).
- **Instance Bambuddy Docker locale** lancée (`/Users/ad/bambuddy-upstream`, ports 8000/3000/3002/8883).
- **Cartographie API complète** → `docs/bambuddy-api.md`, `docs/api/openapi.json`,
  `docs/api/rest-endpoints.md` (621 ops, 346 schémas, événements WS, auth).
- **ADR-0001 (licence)** rédigé — AGPL-3.0 amont + conflit App Store analysés ; **décision en attente**.
- Gouvernance : README, ROADMAP, ce PROGRESS.

## 🟦 En cours
- Scaffolding dépôt + création GitHub.
- Proposition MVP (à présenter).

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
