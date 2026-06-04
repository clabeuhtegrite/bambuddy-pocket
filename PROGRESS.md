# PROGRESS — état vivant du projet BamPocket

> **But** : permettre une reprise propre (par moi-même après un blocage quota, ou par le
> superviseur externe). Mis à jour et commité régulièrement. Voir [`ROADMAP.md`](ROADMAP.md).

**Dernière mise à jour** : 2026-06-03 — Phase 0 en cours : socle + couche réseau + persistance
faits ; lecture quasi complète + auth. Repo : https://github.com/clabeuhtegrite/bambuddy-pocket (public, en dev).

## 🔆 Prochaine action (point de reprise)
**Phase 2 — édition d'imprimante (PATCH) livrée (`main` vert).** Écran détail imprimante : bouton
**« Modifier l'imprimante »** ouvrant une feuille d'édition (`PATCH /printers/{id}`) — nom, IP,
modèle, emplacement, actif, archivage auto ; **code d'accès optionnel** (laissé vide = secret LAN
préservé). Modèle `PrinterUpdate` (Domain, tous champs optionnels, encodeur omet les `nil` →
mise à jour partielle `exclude_unset`). **Contrat vérifié au réel sur la VP** (`VP-Test` id=1) :
`PATCH {location:"Lab A"}` → seul `location` modifié (name/serial/auto_archive/is_active intacts),
puis **VP restaurée** (`location:null`, instance propre, auth off). **Jamais exécuté sur
l'imprimante physique.** Tests : **247 SPM** (+1, routage PATCH + omission `access_code`), 11 app +
3 UI, build iOS sans warning, lint/format strict OK. i18n EN/FR/ES/DE.

**Phase 2 — file : distribution automatique en arrière-plan livrée (`main` vert).** La
**distribution auto** (`background_dispatch`) est désormais surveillée et annulable depuis l'écran
File d'attente : une section « Distribution auto » liste les travaux **actifs** (avec progression de
téléversement) et **en attente**, avec un swipe d'annulation. État alimenté en temps réel par le
**WebSocket** (`type: background_dispatch`) via le `ServerNotificationCenter` persistant (`dispatch
State`) ; annulation par `DELETE /background-dispatch/{job_id}`. Modèles
`BackgroundDispatchState`/`BackgroundDispatchJob` (Domain) + case `WebSocketEvent.backgroundDispatch`.
**Contrat vérifié à la doc amont** (`services/background_dispatch.py` `_build_state_payload`,
`routes/background_dispatch.py` cancel, `routes/websocket.py` snapshot). Tests : **246 SPM** (+2),
11 app + 3 UI, build iOS sans warning, lint/format strict OK. i18n EN/FR/ES/DE.

**Phase 1 — caméra : flux authentifié via jeton livré (`main` vert).** Le flux MJPEG, le snapshot
et la vignette d'archive s'authentifient désormais via **`?token=`** quand l'auth est activée :
`makeCameraStream(token:)` ajoute le jeton à l'URL du flux, `cameraSnapshot(token:)` /
`archiveThumbnail(token:)` / `archivePlateThumbnail(token:)` l'ajoutent au chemin (encodé URL via
`RESTClient.appendingToken`). `CameraView` récupère un jeton (`POST /printers/camera/stream-token`)
une fois puis le passe au flux **et** à la boucle de snapshots ; `ArchiveListModel.thumbnail`
récupère aussi un jeton. **Contrat vérifié à la doc amont** (`camera.py` : `RequireCameraStream
TokenIfAuthEnabled` sur stream/snapshot/thumbnail/plate-thumbnail ; `auth.py`
`require_camera_stream_token_if_auth_enabled`) **et au réel** (no-auth : `stream-token` renvoie un
jeton, `?token=` inoffensif). Les en-têtes auth/Cloudflare restent appliqués partout. Tests :
**244 SPM** (+2), 11 app + 3 UI, build iOS sans warning, lint/format strict OK.

**Phase 1 — média d'archive livré (`main` vert).** Détail d'archive : **vignette d'impression**
(`GET /archives/{id}/thumbnail` → image, section en tête de détail) + **métadonnées de timelapse**
(`GET /archives/{id}/timelapse/info` → résolution, durée, débit d'images, taille). Modèle
`TimelapseInfo` (Domain) + champs `thumbnailPath`/`timelapsePath`/`objectCount` sur `Archive`
(accesseurs `hasThumbnail`/`hasTimelapse`). Endpoints octets bruts `archiveThumbnail`/
`archivePlateThumbnail` via `data(forPath:)`. **Contrat vérifié à la doc amont** (`archives.py` :
`get_thumbnail`/`get_timelapse_info`/`get_plate_thumbnail` ; `schemas/timelapse.py`
`TimelapseInfoResponse` ; `schemas/archive.py` `thumbnail_path`/`timelapse_path`/`object_count`).
**Note auth** : `get_thumbnail`/`get_plate_thumbnail` exigent un **stream-token** (`?token=`)
quand l'auth est activée (`RequireCameraStreamTokenIfAuthEnabled`) → couvert par la brique caméra
« flux authentifié via token » (item ⬜ distinct). Tests : **242 SPM** (+3 décodage/endpoints),
11 unitaires app + 3 UI, build iOS sans warning, lint/format strict OK. i18n EN/FR/ES/DE.

**Tier 3 résiduel — gestion des imprimantes virtuelles livrée (`main` vert).** Écran **Imprimantes
virtuelles** (`/virtual-printers`) : **CRUD complet** d'émulateurs Bambu (utile au dev/tests) —
liste (état en cours/activé/désactivé, modèle, mode, série), **création** (nom, modèle, mode,
code d'accès, distribution auto, correspondance couleur), **édition** (+ bascule activé), 
**suppression**. Modèles `VirtualPrinter`/`VirtualPrinterList` (+ table modèles)/`VirtualPrinterCreate`/
`VirtualPrinterUpdate` (code d'accès écriture seule). **Contrat vérifié au réel** : round-trip
**POST → GET → PUT → DELETE** exécuté sur le Docker (VP créée/renommée/supprimée), instance
restaurée à la seule VP d'origine (`VP-Test` id=1, auth off). Tests : **221 SPM** (+9), 11 unitaires
app + 3 UI, build sans warning, lint/format strict OK. `ServerDetailView` allégé (sections
extraites) en amont. **Tier 3 vérifiable largement couvert.** Restants non vérifiables sur cette
instance (notés) : kprofiles (imprimante non connectée), MakerWorld (404), metrics (Prometheus off),
slicer-presets/slice-jobs (sidecar off), cloud Bambu (auth requise), labels (montés sous inventory/
spoolman, dépendent d'un état spoolman/RFID).

**Tier 3 résiduel — support / diagnostic livré (`main` vert).** Écran **Support** (`/support/`) :
bascule du **journal de débogage** (état + durée d'activation), **consultation du journal applicatif**
du serveur (filtre par niveau DEBUG/INFO/WARNING/ERROR, recherche plein-texte, total dans le
fichier) et **effacement**. Modèles `DebugLoggingState`/`LogEntry`/`LogsResponse`. **Contrat vérifié
au réel** sur le Docker (debug-logging off, logs réels filtrés/comptés — `total_in_file` ~24895) ;
aucune mutation laissée (lecture seule côté instance). Refactor : `ServerDetailView` scindé en
`operationsSection`/`administrationSection` + fabrique `link(...)` (sous la limite de longueur de
corps). Tests : **214 SPM** (+7), 11 unitaires app + 3 UI, build sans warning, lint/format strict OK.
Suite recommandée (vérifiable) : **virtual-printers** (CRUD, utile pour le dev — données riches au
réel). Non vérifiables (notés) : kprofiles (imprimante non connectée — VP virtuelle), MakerWorld
(404), metrics (off), slicer-presets (off), cloud Bambu (auth).

**Tier 3 résiduel — intégration Spoolman livrée (`main` vert).** Écran **Spoolman**
(`/spoolman/`, `/settings/spoolman`) : état (activé/connecté), réglages (activation, URL, mode de
synchro auto/manuel, synchro du poids, usage partiel), **connecter/déconnecter**. Modèles
`SpoolmanStatus`/`SpoolmanSettings` (booléens **renvoyés en chaînes** par le serveur → accesseurs
typés)/`SpoolmanSettingsUpdate`. **Contrat vérifié au réel** : intégration **activée** sur le Docker
via `PUT /settings/spoolman` (URL bidon) → état `enabled:true, connected:false` confirmé, `connect`
renvoie 503 (aucun serveur Spoolman joignable), puis **désactivée / instance restaurée propre**
(auth off). Le mode connecté (sync de bobines) **non vérifiable** sans serveur Spoolman réel.
Tests : **207 SPM** (+7), 11 unitaires app + 3 UI, build sans warning, lint/format strict OK.
Suite recommandée (Tier 3 vérifiable) : **labels** (`/labels/`), **kprofiles**, **support/
bug-report**, **virtual-printers** (CRUD dev) ; non vérifiables notés (MakerWorld 404, metrics off,
slicer-presets off, cloud Bambu auth).

**Tier 3 résiduel — sauvegarde distante Git livrée (`main` vert).** Écran **Sauvegarde distante**
(`/github-backup/`) : état, configuration (lecture + **création POST / édition PATCH**), journal
des exécutions, **déclenchement manuel**. Sécurité : le **jeton d'accès** est en **écriture seule**
(jamais renvoyé par le serveur — `has_token` seulement — ni stocké sur l'appareil ; transmis au
serveur à l'enregistrement, préservé en édition si le champ est laissé vide via `exclude_unset`).
Données sauvegardables modélisées (K-profils, profils Bambu Cloud, réglages, bobines, historique),
4 fournisseurs (GitHub/GitLab/Gitea/Forgejo), planification (horaire/quotidien/hebdo). **Contrat
vérifié au réel** : config + log semés dans la base du Docker (`docker compose exec`), charges
réelles décodées, puis **config/log supprimés et instance restaurée propre** (auth toujours off).
Note : la sauvegarde réelle ne peut être exercée sans **vrai jeton** (le serveur exige un dépôt
**privé** vérifié via un appel GitHub) — **non testé volontairement**. Tests : **200 SPM** (+11),
11 unitaires app + 3 UI, build sans warning, lint/format strict OK.

**Tier 3 résiduel — journal d'impression livré (`main` vert).** Écran **Journal d'impression**
(`/print-log/`) : liste paginée (recherche serveur par nom, « charger plus », vidage destructif),
modèles `PrintLogEntry`/`PrintLogPage` (dates ISO **sans fuseau** conservées en `String`, parser
de présentation tolérant). **Contrat vérifié au réel** : entrée semée dans la base du Docker
(`docker compose exec`), charge réelle décodée puis **journal vidé / instance restaurée propre**.
Tests : **189 SPM** (+5) + 11 unitaires app + 3 UI, build sans warning, lint/format strict OK.
Suite recommandée (Tier 3 vérifiable) : **GitHub-backup** (status/config/run en lecture, écran
config avec champ token au Keychain — **sans token réel**), **spoolman** (état non configuré +
écran de réglage ; activation Docker à tenter), puis labels/kprofiles/metrics/updates/support
selon faisabilité.

**Vague finitions App Store livrée (PR #38→#42, `main` vert).** Renommage **BamPocket** (#38),
**icône + launch screen** (#39), **privacy manifest + clés runtime** (#40), **XCUITest chemins
critiques en CI** (#41), **prépa sideload + `docs/SIDELOAD.md`** (#42). Tests : **184 SPM + 11
unitaires app + 3 UI** (CI), build sans warning, lint/format strict OK. Modules SPM internes
conservés. **Reste pour « app totalement terminée »** : captures App Store finalisées (le harnais
`BamPocketScreenshots` les produit en live), classification d'âge, fiche App Store, et les étapes
**compte Apple Developer** (enrôlement, signature distribution, TestFlight, soumission) — à la
charge de l'utilisateur. Étendre encore l'unitaire/UI et l'accessibilité au fil de l'eau.

**Tier 2 complet + vague Tier 3 livrés (PR #26→#37, `main` vert, 184 tests SPM + 11 tests app).**
Correctif bug « Étape » (#26 : `PrinterStatus.displayableStage`, étape affichée seulement si
impression active). **Tier 2** : Réglages (#27 langue/devise/imprimante par défaut/coûts),
État serveur (#28 system/info + health + ressources), Clés d'API (#29 CRUD), Compte (#30 profil
`/auth/me` + 2FA + logout `/auth/logout`). **Tier 3** (contrats vérifiés au réel sur le Docker) :
prises connectées (#31 on/off + état), maintenance (#32 overview + perform), firmware (#33 updates
lecture), catalogue filaments (#34), liens externes (#35 CRUD), sauvegardes locales (#36 status/
list/run), découverte réseau (#37 SSDP start/stop + liste). Endpoints scindés en
`BambuddyEndpoints+Management.swift` (< 500 lignes).

Suite recommandée (Tier 3 restant, **vérifier le contrat au réel**) : print-log (paginé, schéma
connu mais pas de données à décoder sur l'instance virtuelle), GitHub-backup (config/run),
spoolman (intégration externe), makerworld (404 sur cette instance), metrics (Prometheus désactivé),
slicer-presets/slice-jobs (sidecar non activé). **Finitions App Store** : icône/launch screen,
captures, XCUITest sur chemins critiques. Endpoints non vérifiables ici → noter et passer.

**Tier 1 approfondi + notifications transverses livrées** (`main`, dépôt public, CI verte,
137 tests SPM + 11 tests app). Vague notifications (PR mergée) : **session WebSocket persistante
au niveau serveur** (`ServerNotificationCenter`, vivante tant que le serveur est sélectionné,
indépendante de l'écran), **feed horodaté lu/non-lu + badge**, **bannières non intrusives**, et
**dérivation** des événements notables (`print_start`/`print_complete`, `missing_spool_assignment`,
`plate_not_empty`, **HMS grave** par transition d'état, `archive_created`). Contrats WS vérifiés au
réel sur le Docker / la source amont. Vagues précédentes (PR #10 → #15) : file d'attente, archives,
inventaire, bibliothèque, projets, caméra.

Prochaines briques recommandées (par valeur) :
1. **Queue** : `background-dispatch` (cancel job), distribution auto par modèle (`target_model`).
2. **Bibliothèque** : arbre de **dossiers** (`/library/folders/`), déplacement, upload, corbeille.
3. **Projets** : items (add-archives/add-queue), BOM, timeline, templates.
4. **Tier 2** : settings (langue/devise/imprimante par défaut), **system** (`/system/info`, santé,
   storage), users (profil), **api-keys** (CRUD), notification-templates.
5. **Tier 3** (vérifier le contrat au réel) : **smart-plugs** (alim on/off), spoolman, cloud Bambu,
   makerworld, obico, maintenance, firmware.
6. **Finitions App Store** : icône/launch screen, captures, **XCUITest** sur chemins critiques.
Cadence : **autonomie complète** ; build en local (Mac+Xcode) AVANT de pousser ; CI = juge final.
Build iOS : `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ; `xcodegen generate` ;
`xcodebuild -project BamPocket.xcodeproj -scheme BamPocket -destination 'platform=iOS Simulator,name=iPhone 17' test`.

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
- **2026-06-04 (36)** — **Passe d'accessibilité (VoiceOver) sur les écrans Tier 2/3.** Les icônes
  de **statut purement décoratives**, redondantes avec le texte adjacent, sont masquées à VoiceOver
  (`.accessibilityHidden(true)`) pour qu'il n'annonce que l'information utile : État serveur
  (santé), Compte (2FA), Sauvegardes (planification), Découverte (état). Ligne de **lien externe**
  combinée en un seul élément (`.accessibilityElement(children: .combine)`) avec ses icônes
  masquées. Les éléments interactifs (boutons On/Off, créer/supprimer, start/stop) utilisent déjà
  `Label(texte, systemImage:)` → libellés VoiceOver corrects. Build sans warning, lint/format OK,
  184 SPM + 11 + 3 UI verts.
- **2026-06-04 (35)** — **Prépa sideload iPhone (free provisioning, sans compte payant) +
  `docs/SIDELOAD.md`.** Audit signature/entitlements : **aucun fichier `.entitlements`, aucune
  capability** (pas de Push/Associated Domains/App Groups/groupe d'accès trousseau) — l'app
  n'utilise que des API standard (réseau local, `UserDefaults`, trousseau via **service applicatif
  fixe** indépendant du bundle id). `CODE_SIGN_STYLE: Automatic` + bundle id unique
  `com.bampocket.app` → **compatible équipe personnelle**. Guide pas-à-pas écrit : ajout de l'Apple
  ID, sélection de la Personal Team, réglage du bundle id, branchement iPhone, `Trust` du profil,
  Run, autorisation **réseau local** au premier contact, **caveat 7 jours**, rappel
  `xcodegen generate`. Vérifié : `xcodebuild -destination 'generic/platform=iOS' build` échoue
  bien faute d'identité de signature (attendu, documenté, non bloquant pour la CI simulateur).
  Lien ajouté au README. Pas de Swift modifié → CI inchangée.
- **2026-06-04 (34)** — **XCUITest sur chemins critiques (exécutés en CI, sans backend).**
  Nouvelle cible de tests `CriticalPathUITests` ajoutée au **scheme `BamPocket`** (donc à la CI) :
  3 parcours déterministes, indépendants de tout backend Bambuddy — (1) **état vide → ajout d'un
  serveur** via le formulaire (URL + libellé) → liste → **détail** → **navigation vers
  Imprimantes** (bouton « Add printer ») → retour → **centre de notifications** ; (2) écran **À
  propos** (version) ; (3) **annulation** d'ajout (liste reste vide). Robustesse : locale **forcée
  en anglais** (`-AppleLanguages (en)`) pour des sélecteurs stables quel que soit le simulateur ;
  argument **`-uitest-fresh`** (nouveau dans `BamPocketApp`) qui repart d'une liste vide ;
  sélecteurs basés sur les libellés/rôles réels (NavigationLink = Button). Les **captures**
  (`ScreenshotTests`, dépendantes du Docker) sont désormais **isolées derrière `UITEST_LIVE=1`**
  (skip propre en CI, fourni par le scheme `BamPocketScreenshots`). 184 SPM + 11 unitaires app +
  **3 UI** verts, screenshot skippé, build sans warning, lint/format strict OK.
- **2026-06-04 (33)** — **Privacy manifest + clés runtime (App Store / device réel).**
  `PrivacyInfo.xcprivacy` déclare désormais l'**API à raison requise** UserDefaults (`CA92.1`,
  persistance locale de la liste des serveurs) — aucun tracking, aucune collecte. Info.plist :
  `NSLocalNetworkUsageDescription` (déjà présent) couvre les connexions directes REST/WS/caméra
  aux IP locales saisies par l'utilisateur → invite « réseau local » sur device. **Décisions
  documentées** : pas de `NSBonjourServices` (la découverte SSDP est faite par le serveur, pas par
  l'iPhone — l'app n'effectue aucun browse Bonjour/mDNS) ni de `NSCameraUsageDescription` (la
  « caméra » est le flux réseau MJPEG de l'imprimante, l'appareil photo de l'iPhone n'est jamais
  utilisé). Manifest copié dans le bundle (vérifié). Build iOS sans warning, lint/format OK.
- **2026-06-04 (32)** — **Icône d'app + launch screen (DA BamPocket).** Icône soignée : « B »
  géométrique sombre découpé dans une pastille verte (dégradé `#00C64D`→`#00AE42`) sur fond sombre
  dégradé, générée par **script reproductible** `scripts/icon/generate_app_icon.swift` (Core
  Graphics) — master 1024 opaque + 13 tailles iPhone/iPad, `Contents.json` complet. **Launch
  screen** via `UILaunchScreen` : logo centré (`LaunchLogo.imageset`, généré par
  `scripts/icon/generate_launch_logo.swift`) sur fond sombre `LaunchBackground` (`#1A1A1A`).
  Build iOS sans warning (actool OK), lint/format strict OK, 184 SPM + 11 app tests verts.
- **2026-06-04 (31)** — **Renommage produit → « BamPocket » (nom final, ADR-0004 révisé).**
  `CFBundleDisplayName` = `BamPocket` ; scheme/target/produit `BamPocket` (+ scheme captures
  `BamPocketScreenshots`) ; bundle id `com.bampocket.app` (`.tests`/`.uitests`) ;
  `bundleIdPrefix` `com.bampocket`. Cibles de test renommées (`@testable import BamPocket`).
  CI mise à jour (`BamPocket.xcodeproj`/`-scheme BamPocket`). Branding visible + docs (README,
  CONTRIBUTING, NOTICE, LICENSE-exception, ADR-0001/0002/0004, HANDOFF, PROGRESS, ROADMAP,
  `.swiftlint.yml`, `Info.plist`, `PrivacyInfo`, `DSColor` doc, `BamPocketApp`). **Modules SPM
  internes conservés** (`BambuddyPocketKit`/`…Domain`/`…Networking`/`…DesignSystem`) : non
  visibles, un renommage toucherait tous les `import` pour aucun gain produit. Service Keychain
  (`app.bambuddy.pocket.secrets`, chaîne fixe) conservé → secrets stockés non invalidés ; bundle id
  indépendant du Keychain → accès intact. Dépôt GitHub `bambuddy-pocket` **non renommé** (URL).
  184 tests SPM + 11 tests app verts, build iOS sans warning, lint/format strict OK.
- **2026-06-04 (30)** — **Tier 2 complet + vague Tier 3 (PR #26→#37).** Correctif « Étape »
  (#26). **Tier 2** : Réglages (#27), État serveur (#28), Clés d'API CRUD (#29), Compte/profil +
  2FA + logout (#30). **Tier 3** (contrats vérifiés au curl sur le Docker, chaque décodage testé) :
  prises connectées on/off + état (#31), maintenance overview + perform (#32), firmware updates
  lecture (#33), catalogue filaments (#34), liens externes CRUD (#35), sauvegardes locales status/
  list/run (#36), découverte réseau SSDP (#37). Auth vérifiée en activant temporairement l'auth du
  Docker (setup → login → `/auth/me`/`/auth/2fa/status`/`/auth/logout`) puis instance restaurée
  sans-auth. Endpoints scindés (`BambuddyEndpoints+Management.swift`) pour rester < 500 lignes.
  **184 tests SPM** (+38), 11 tests app, build iOS sans warning, lint/format strict OK à chaque PR.
  i18n FR/EN/ES/DE pour chaque écran. Non vérifiables sur cette instance (notés) : print-log (vide),
  makerworld (404), metrics (Prometheus off), slicer-presets (sidecar off), cloud (auth requise).
- **2026-06-04 (29)** — **Captures françaises (DA) + robustesse Keychain.** Cible XCUITest
  `BambuddyPocketScreenshots` rendue **multilingue/multi-thème** : lancement en **locale fr**
  (`-AppleLanguages (fr)` `-AppleLocale fr_FR`), **thème forcé** via `-uitest-appearance dark|light`
  (override `.preferredColorScheme` côté app, sans effet en build normal), sélecteurs basculés
  sur les libellés FR. 15 écrans capturés en **thème sombre** + 2 écrans clés (imprimantes liste/
  détail) en **thème clair** dans `docs/screenshots/` (gitignoré). **Correctif de robustesse** :
  `KeychainSecretStore.secrets(for:)` tolère désormais `errSecMissingEntitlement` (build non signé
  sans groupe d'accès Keychain) en renvoyant des secrets vides — sans quoi tous les écrans réseau
  masquaient leur contenu derrière une erreur Keychain opaque ; pour un serveur sans auth c'est le
  comportement correct, pour un serveur authentifié l'échec se reporte au réseau (message clair).
  Build iOS sans warning, lint/format strict OK.
- **2026-06-04 (28)** — **Refonte UI — diffusion de la DA sur tous les écrans (PR B→F).** Le
  design system (PR A) est appliqué écran par écran, par lots verts mergés au fil de l'eau :
  **B** serveurs/connexion/ajout imprimante/À propos ; **C** imprimantes (liste/détail/caméra/
  feuilles de maintenance) ; **D** file d'attente/archives (+ détail/stats/édition) ; **E**
  inventaire/bibliothèque/projets (+ détails/feuilles) ; **F** notifications (centre + bannière)/
  activité/viewer 3D. Partout : fonds adaptatifs (`dsListBackground()`), typographie **Inter**
  (`DSFont`), **badges de statut sémantiques** (`DSStatusBadge` + `DSStatusIntent`), barres de
  progression en **accent vert**, couleurs d'icônes/actions mappées sur la DA. Les helpers de
  présentation partagés (`PrinterPresentation.stateColor`/`severityColor`,
  `ArchivePresentation.statusColor`) délèguent à `DSStatusIntent` (source unique testée). Ajouts
  DA : `DSStatusIntent.forRawStatus` (testé) + modificateur `dsListBackground()`. **146 tests
  SPM**, tests app verts, build iOS sans warning, lint/format strict OK à chaque lot.
- **2026-06-04 (27)** — **Refonte UI — PR A : fondation design system (DA Bambuddy).** Le module
  SPM `BambuddyPocketDesignSystem` (jusqu'ici quasi vide) porte désormais la direction artistique
  officielle, extraite du frontend web amont (`tailwind.config.js`/`index.css`). **Décision thème :
  app adaptative clair/sombre qui suit le système** (coché au ROADMAP « mode sombre »). **Palette**
  (`DSColor`) : accent vert constant `#00AE42` (+ clair/sombre), statuts sémantiques fixes
  (ok `#22C55E`, error `#EF4444`, warning `#F59E0B`), surfaces et textes **adaptatifs** via
  fournisseur dynamique `UIColor` (clair fond `#F5F5F5`/carte `#FFFFFF` ; sombre fond `#1A1A1A`/
  carte `#2D2D2D`). **Typographie** (`DSFont`) : **Inter** (TTF variable embarqué, déclaré via
  `UIAppFonts`, attribué **OFL** dans `NOTICE`), échelle titres/corps/légendes, poids 400/500/600/700,
  compatible Dynamic Type (`relativeTo:`). **Tokens** étendus (`DSSpacing`/`DSRadius`/`DSBorder`).
  **Composants** : `DSCard`/`dsCardSurface()`, `DSStatusBadge` (mapping état→couleur via
  `DSStatusIntent`, pur et testé), boutons `dsPrimary`/`dsSecondary`/`dsDestructive`,
  `DSScreenBackground`, `DSSeparator`. Accent vert global (`.tint(DSColor.accent)` + AccentColor
  asset passé au vert). Aucun écran modifié (diffusion en PR B…N). **145 tests SPM** (+8 : mapping
  statut→couleur), build iOS OK, lint/format strict OK.
- **2026-06-04 (26)** — Transverse : **notifications en-app dérivées du WebSocket** au **niveau
  serveur**. Nouveau service `ServerNotificationCenter` (`@MainActor @Observable`) qui possède une
  **session WS persistante** (mise en cache par `ServerListModel`, vivante tant que le serveur est
  sélectionné, indépendante de l'écran), fusionne les deltas de statut et dérive des notifications.
  `PrinterListModel` ne porte plus son propre flux WS : il consomme les statuts/temps réel partagés.
  **Dérivation** (Domain, testée) : `print_start`/`print_complete` (avec nom du travail),
  `missing_spool_assignment`, `plate_not_empty` (avec message), `archive_created` (libellé extrait),
  et **HMS grave** par **transition d'état** (`PrinterStatus.severeHMSEvent(comparedTo:)`, pas un
  type WS distinct — l'erreur arrive via `printer_status.hms_errors` ; notifiée une seule fois).
  `WebSocketEvent` étendu : décodage `archive_created` + `message`/`printer_name` sur
  `plate_not_empty`. **UI** : centre de notifications (feed horodaté, **lu/non-lu + badge**,
  effacement), **bannières non intrusives** auto-repliables, accessibles **au niveau serveur**
  (`ServerDetailView`) **et** sur l'écran imprimantes. Contrats WS vérifiés au réel (Docker + source
  amont `backend/app/core/websocket.py` / `main.py`). i18n FR/EN/ES/DE (6 clés, dont un pluriel).
  137 tests SPM verts (+9), 11 tests app (+5), build iOS sans warning, lint/format OK.
- **2026-06-04 (25)** — Tier 1 (caméra en profondeur) : **détection de plateau vide** par vision
  (`GET /printers/{id}/camera/check-plate`), **état du flux** (`GET …/camera/status`), **jeton de
  flux** (`POST /printers/camera/stream-token`). Modèles `PlateCheck`/`CameraStatus`/
  `CameraStreamToken` (Domain). Contrats vérifiés au réel sur le Docker (l'imprimante virtuelle n'a
  pas de flux → message « Failed to capture camera frame », confiance 0). UI : bouton « Vérifier le
  plateau » dans l'écran caméra avec alerte de résultat (confiance %, besoin de calibration, alerte
  lumière). i18n FR/EN/ES/DE (5 clés). 128 tests SPM verts, 6 tests app, lint/format OK.
- **2026-06-04 (24)** — Tier 1 (projets en profondeur) : **détail** (`GET /projects/{id}`, champs
  riches : description, notes, tags, priorité, budget, URL), **création** (`POST /projects/`),
  **édition** (`PATCH /projects/{id}` — statut, objectif, priorité, notes…), **suppression**
  (`DELETE /projects/{id}`). Modèles `ProjectCreate`/`ProjectUpdate` + champs supplémentaires sur
  `Project` (Domain). Note : `progress_percent` est top-niveau dans la liste mais sous `stats` dans
  le détail — le détail réutilise la progression de la liste et enrichit le reste. Contrats vérifiés
  au réel sur le Docker. UI : écran de détail, feuille création/édition partagée (`ProjectFormSheet`),
  bouton « + » et swipe suppression. i18n FR/EN/ES/DE (13 clés). 122 tests SPM verts, 6 tests app,
  lint/format OK.
- **2026-06-04 (23)** — Tier 1 (bibliothèque en profondeur) : **détail de fichier** (`GET
  /library/files/{id}`), **ajout à la file** (via `POST /queue/` avec `library_file_id`, fichiers
  tranchés uniquement), **édition** nom + notes (`PUT /library/files/{id}`), **suppression/corbeille**
  (`DELETE /library/files/{id}`). Modèle `LibraryFileUpdate` + champs `folderId`/`notes`/
  `slicedForModel` + `isSliced` sur `LibraryFile` (Domain). Contrats vérifiés au réel sur le Docker.
  UI : écran de détail (métadonnées, estimation, notes), feuille d'édition, swipes enqueue/suppression.
  i18n FR/EN/ES/DE (6 clés). 115 tests SPM verts, 6 tests app, lint/format OK.
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
