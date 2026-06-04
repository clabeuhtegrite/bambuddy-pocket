# BamPocket

> **BamPocket** — client iOS natif (open source) pour
> [Bambuddy](https://github.com/maziggy/bambuddy), l'outil auto-hébergé de gestion d'imprimantes
> 3D Bambu Lab. Projet **tiers, non affilié** à Bambuddy ni à Bambu Lab.
> « Bambuddy » et « Bambu Lab » sont des marques de leurs détenteurs ; la relecture/clearance
> pré-publication reste du ressort de l'utilisateur. Contexte :
> [`docs/adr/0004-nommage.md`](docs/adr/0004-nommage.md). Le dépôt GitHub conserve le slug
> historique `bambuddy-pocket`.

[![CI](https://github.com/clabeuhtegrite/bambuddy-pocket/actions/workflows/ci.yml/badge.svg)](https://github.com/clabeuhtegrite/bambuddy-pocket/actions/workflows/ci.yml)

## Qu'est-ce que c'est

Un client mobile **iPhone + iPad** (iOS 18+) qui se connecte à une ou plusieurs instances
Bambuddy auto-hébergées pour : suivre l'état des imprimantes **en temps réel**, consulter
l'**archive d'impressions**, voir la **caméra**, piloter la **file d'attente** et les
**impressions**, le tout avec une expérience native (SwiftUI, mode sombre, VoiceOver, i18n
FR/EN/ES/DE). Ce n'est **pas** un clone de l'interface web : l'app exploite l'API au mieux pour une
UX mobile de qualité production.

## État du projet

🚧 **En cours de développement actif** — dépôt **public** dès la phase de dev (pour profiter de
l'intégration continue GitHub Actions, gratuite sur les dépôts publics). **L'application n'est pas
encore terminée ni prête pour la production** : fonctionnalités, API et UI évoluent rapidement.
Voir [`PROGRESS.md`](PROGRESS.md) (état détaillé) et [`ROADMAP.md`](ROADMAP.md) (phases).

> ⚠️ Avant toute **publication de l'app** (App Store) : vérification de marque « Bambuddy » et
> relecture juridique AGPL/exception requises (cf. README ci-dessus et `docs/adr/`).

## Pile technique

- **Swift + SwiftUI**, architecture **MVVM**, `async/await`, injection de dépendances.
- Séparation nette **réseau / domaine / UI**.
- Dépendances tierces **minimales** (SPM), sinon maison.
- Tests unitaires + UI sur les chemins critiques ; **SwiftLint + SwiftFormat** ; build sans warning.
- **CI** GitHub Actions (build + tests + lint).

## Connexion à un serveur Bambuddy

L'app gère plusieurs serveurs ajoutés par URL (`schéma + hôte + port`). Méthodes d'accès :
LAN HTTP (exception ATS documentée + réseau local iOS), Tailscale/VPN, reverse proxy HTTPS,
et **Cloudflare Access** par service token (en-têtes `CF-Access-Client-Id` /
`CF-Access-Client-Secret` sur **toutes** les requêtes, y compris le WebSocket). Tous les
secrets/tokens sont stockés au **Keychain**, jamais en clair ni dans le dépôt.

## Développement

### Pré-requis
- macOS + **Xcode 26+** (iOS 18 SDK ou supérieur).
- Docker (pour l'instance Bambuddy de dev).

> ℹ️ Si `xcodebuild` se plaint des Command Line Tools, Xcode est installé mais non sélectionné.
> Soit `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, soit exporter
> `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (utilisé par les scripts/CI locaux).

### Backend de dev (Docker, macOS)
Docker Desktop ne gère pas `network_mode: host` : dans `docker-compose.yml` commenter
`network_mode: host`, décommenter `ports:` (au moins `8000`). La découverte d'imprimantes ne
marche pas → ajout par IP manuel.
```bash
docker compose up -d
curl -s http://localhost:8000/health            # {"status":"healthy"}
open http://localhost:8000/docs                  # Swagger
```
La démo <https://bambuddy.cool> sert de **référence en lecture seule** (jamais d'écriture).

### Projet iOS (génération & build)
Le projet Xcode est **généré** depuis [`project.yml`](project.yml) via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — le `.xcodeproj`
n'est pas versionné (source de vérité = `project.yml`).
```bash
xcodegen generate         # crée BamPocket.xcodeproj
open BamPocket.xcodeproj  # ouvrir dans Xcode, ou builder en CLI ↓
xcodebuild -project BamPocket.xcodeproj -scheme BamPocket \
  -destination 'platform=iOS Simulator,name=iPhone 17' build test
(cd Packages/BambuddyPocketKit && swift test)   # tests du paquet SPM
```
> Le code est organisé en : cible app `BamPocket` (SwiftUI) + paquet SPM local
> `BambuddyPocketKit` (modules `…Domain`, `…Networking`, `…DesignSystem` — noms internes
> conservés). Cf.
> [`docs/adr/0002-architecture.md`](docs/adr/0002-architecture.md).

## Documentation

- [`docs/bambuddy-api.md`](docs/bambuddy-api.md) — **contrat d'API** (REST + WebSocket + modèles).
- [`docs/api/openapi.json`](docs/api/openapi.json) — spec OpenAPI brute (source machine).
- [`docs/api/rest-endpoints.md`](docs/api/rest-endpoints.md) — catalogue exhaustif des 621 endpoints.
- [`docs/adr/`](docs/adr/) — décisions d'architecture (ADR).
- [`docs/SIDELOAD.md`](docs/SIDELOAD.md) — installer l'app sur votre iPhone (free provisioning,
  sans compte développeur payant).
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — guide de contribution.

## Licence

**GNU AGPL-3.0-or-later** (voir [`LICENSE`](LICENSE)) — aligné sur Bambuddy (lui-même AGPL-3.0),
avec une **permission additionnelle (AGPLv3 §7)** autorisant la distribution via l'App Store et
les plateformes analogues (voir [`LICENSE-APP-STORE-EXCEPTION.md`](LICENSE-APP-STORE-EXCEPTION.md)).
Contexte et alternatives écartées : [`docs/adr/0001-licence.md`](docs/adr/0001-licence.md).
En-têtes de fichiers : `SPDX-License-Identifier: AGPL-3.0-or-later`.
