# Roadmap — BamPocket

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
- ✅ Design system (✅ tokens, ✅ **composants** — carte/badge/boutons/fond/séparateur, ✅
  **typographie Inter** Dynamic Type, ✅ palette adaptative), ✅ **mode sombre** (app adaptative
  clair/sombre suivant le système, DA Bambuddy — PR A).
- ✅ i18n FR/EN/ES/DE (String Catalog) ; ✅ accessibilité (VoiceOver) : éléments interactifs via
  `Label`, icônes décoratives masquées, lignes combinées, **Dynamic Type** sur les cartes
  AMS/Accueil/Timeline (`DSFont` relatifs, audit B2 clos).
- ✅ Privacy manifest + `NSLocalNetworkUsageDescription` + ATS (exception HTTP local).
- ✅ CI : build + tests + lint (SwiftLint/SwiftFormat) + shellcheck sur push/PR.

## Phase 1 — MVP cœur (lecture, testable sur la démo) 🟦
- ✅ **Liste multi-imprimantes** + statut **temps réel** (WebSocket, fusion des deltas).
- ✅ **Détail imprimante** : température (buse/plateau/chambre), progression (couches, temps
  restant), état, AMS/bobines, **erreurs HMS** (code+sévérité), ✅ **ventilateurs détaillés**
  (refroidissement de pièce, auxiliaire, chambre, heatbreak — champs réels du status),
  ✅ **profils K (avance de pression)** en consultation seule (`/kprofiles/`).
- ✅ **Caméra** : snapshot rafraîchi + flux MJPEG, **détection de plateau vide** (check-plate),
  **état du flux** (camera/status), **jeton de flux** (stream-token) + **flux/snapshot/vignette
  authentifiés via `?token=`** (requis quand l'auth est activée ; en-têtes auth/Cloudflare conservés).
- 🟦 **Archive d'impressions** : ✅ liste + détail (statut, durée, filament, coût/énergie,
  chronologie) + **recherche serveur** (`/archives/search`), ✅ **favori** (PATCH/toggle),
  ✅ **édition** (tags, notes, nom, lien), ✅ **suppression**, ✅ **vignette** d'impression +
  **métadonnées de timelapse** (résolution, durée, débit, taille) dans le détail.
- ✅ État serveur (`/system/info`, `/system/health`, ressources/stockage/base) — écran dédié.

## Phase 2 — Actions (écritures, Docker local / imprimante virtuelle) 🟦
- ✅ **Contrôles d'impression** : pause/reprise/stop, vitesse, lumière chambre, clear HMS,
  AMS unload/load/reset, séchage, **skip-objects**, **clear-plate**, **home-axes**, **calibration**,
  **connect/disconnect**, **suppression d'imprimante**, **print-options** (détecteurs IA : lecture
  via `/status` + bascule via `POST …/print-options`), **bed-jog** (écart buse-plateau ±0,1 mm),
  **airduct-mode** (refroidissement/chauffage).
- ✅ **File d'attente** : liste + **réordonnancement (drag/drop)**, ajout, start/stop/cancel/delete,
  **édition d'item** (PATCH : planification `scheduled_time`, réassignation, options), **lots
  (batches)** (liste + annulation), **mise à jour en lot** (`PATCH /queue/bulk`), **distribution
  auto** (`background_dispatch` : état temps réel via WS — travaux actifs/en attente + progression
  de téléversement — et **annulation** `DELETE /background-dispatch/{id}`).
- ✅ **Notifications EN-APP** : ✅ flux d'activité (`notifications/logs`) en lecture ; ✅ **dérivation
  temps réel depuis le WebSocket** au niveau serveur (`ServerNotificationCenter`, session WS
  persistante) — fin/début d'impression, **HMS grave** (transition), bobine manquante, plateau non
  vide, archive créée ; feed lu/non-lu + badge + bannières.
- ✅ Gestion d'imprimante côté serveur : ajout (`PrinterCreate`), suppression, **édition (PATCH)**
  (nom, IP, modèle, emplacement, actif, archivage auto ; code d'accès optionnel — préservé si vide).

## Phase 4 — Réglages, serveur, comptes & intégrations (Tier 2/3) 🟦
- ✅ **Réglages** serveur : langue, devise, imprimante par défaut, coûts (`/settings/`).
- ✅ **État serveur** : `/system/info` + `/system/health` (app, machine, ressources, base).
- ✅ **Clés d'API** : CRUD complet (`/api-keys/`) + secret montré une fois.
- ✅ **Compte** : profil `/auth/me`, état 2FA `/auth/2fa/status`, **logout** `/auth/logout`.
- ✅ **Prises connectées** : liste + état + alim **on/off** (`/smart-plugs/`).
- ✅ **Maintenance** : vue d'ensemble + « effectué » (`/maintenance/`).
- ✅ **Firmware** : disponibilité des mises à jour par imprimante (lecture, `/firmware/updates`).
- ✅ **Catalogue de filaments** : liste de référence consultable (`/filament-catalog/`).
- ✅ **Liens externes** : CRUD (`/external-links/`).
- ✅ **Sauvegardes locales** : état + liste + déclenchement (`/local-backup/`).
- ✅ **Découverte réseau** : SSDP start/stop + liste (`/discovery/`).
- ✅ **Journal d'impression** : liste paginée + recherche serveur + vidage (`/print-log/`).
  Contrat vérifié au réel (entrée semée puis instance restaurée propre).
- ✅ **Sauvegarde distante Git** : état + config (POST/PATCH, jeton écriture seule) + journal +
  run manuel (`/github-backup/`). Contrats lecture vérifiés au réel (config/log semés puis
  supprimés) ; la sauvegarde effective exige un vrai jeton + dépôt privé → non testée.
- ✅ **Spoolman** : état + réglages (activation/URL/sync) + connecter/déconnecter (`/spoolman/`).
  Activé au réel sur le Docker (état activé/non-connecté + 503 confirmés) puis désactivé ; le mode
  connecté exige un serveur Spoolman réel → non testé.
- ✅ **Support / diagnostic** : bascule du journal de débogage + journal applicatif (filtre niveau,
  recherche, effacement) (`/support/`). Contrats vérifiés au réel (lecture seule, instance intacte).
- ✅ **Imprimantes virtuelles** : CRUD complet d'émulateurs Bambu (`/virtual-printers`). Round-trip
  POST/GET/PUT/DELETE vérifié au réel puis instance restaurée à la VP d'origine.
- ⬜ Non vérifiables sur l'instance de dev (notés) : MakerWorld (404), metrics (Prometheus off),
  slicer-presets/slice-jobs (sidecar off), cloud Bambu (auth requise), Spoolman (à activer).

## Phase 3 — Avancé 🟦
- ✅ **Viewer 3D/parcours** des 3MF/STL **et G-code** : WebView Three.js **embarquée** (hors-ligne) ;
  maillage pour STL/3MF, **parcours d'outil** (déplacements d'extrusion en lignes vertes) pour le
  G-code via un parseur G-code minimal côté page (G0/G1, absolu/relatif, E croissant).
- ⬜ **Slicing** : déclenchement du sidecar serveur (OrcaSlicer/Bambu Studio) s'il est activé
  (`use_slicer_api`, `slice-jobs`) — non testable sur la démo.
- 🟦 Bibliothèque de modèles (✅ liste + recherche, détail, ajout à la file, édition nom/notes,
  suppression, ✅ **arbre de dossiers** + navigation, ✅ **déplacement** de fichiers, ✅ **corbeille**
  (restauration/suppression définitive), ✅ **upload** (multipart, sélecteur de fichier, doublon
  détecté)) / projets (✅ liste + recherche, détail, création,
  édition, suppression, ✅ **nomenclature (BOM)** (consultation + ajout/suppression d'éléments),
  ✅ **chronologie** (`/timeline`) ; ⬜ add-archives/add-queue), **inventaire
  filaments** (✅ liste,
  détail, édition, historique de consommation, reset compteur, suppression) ; ⬜ Spoolman/SpoolBuddy,
  intégrations (cloud, smart-plugs, Obico, MakerWorld) selon priorité.

## Phase 5 — Support proactif de la gamme Bambu Lab ✅
Nuances par modèle + décodage tolérant + UI adaptative + effets de bord. Source de vérité :
`backend/app/utils/printer_models.py` (frozensets dual-nozzle / ethernet / rails / map de modèles).
- ✅ **Fondation capacités** (`PrinterModel` + `PrinterCapabilities`, miroir amont) : résolution
  nom 3MF / code interne / nom court → capacités (double buse, ethernet, type de rails
  `get_rod_type`, AMS standard/Lite/HT, chambre chauffée, caméra), normalisation identique amont
  (`upper`, sans espace/tiret). Modèle inconnu/futur → `.unknown` (capacités prudentes sûres).
- ✅ **UI températures dual-extrudeur** : seconde buse affichée seulement si le modèle l'a **et**
  que le statut l'expose (`nozzle_2`).
- ✅ **Variantes AMS** (standard / Lite / HT) : type lu sur l'unité réelle (`is_ams_ht`,
  `module_type` n3f/n3s/n3l, `id ≥ 128`) **prime** sur la capacité modèle ; libellés adaptés.
- ✅ **Détail adaptatif caméra / réseau** par capacité confrontée au statut (rien d'affiché si
  absent).
- ✅ **Robustesse / effets de bord** : tous les modèles Domain décodent sans échec face aux champs
  manquants / `null` / types inattendus / clés inconnues (API future), **firmware ancien**
  (sous-ensembles), **imprimante hors ligne** (étape résiduelle masquée à la fusion), **status
  minimal**, **AMS vide/absent**, températures partielles (mono vs dual). Pas de force-unwrap ;
  `try #require` en test. Fixtures de bord (`offline_minimal_status.json`, `x2d_real_status.json`).
- ✅ **Maintenance des axes par type de rails** (`get_rod_type`) : `MaintenanceOverview` expose
  `capabilities`/`rodType` ; l'en-tête de section Maintenance affiche le type de rails
  (carbone / acier / rail linéaire), masqué pour un modèle inconnu.

## Transverse / sortie App Store ⬜
- ✅ **Refonte UI — direction artistique Bambuddy** sur tous les écrans : design system
  (palette adaptative clair/sombre, accent vert, Inter, composants), **mode sombre** suivant
  le système, badges de statut sémantiques, barres de progression vertes (PR A→F).
- ✅ **Refonte navigation & accueil** (maquettes `docs/mockups/`) :
  - ✅ **Navigation par onglets** (#83) — `ServerHomeView` + `MoreView` : `Accueil · Imprimantes ·
    File · Bibliothèque · Plus`, chaque onglet sa pile `NavigationStack`, écran « Plus » groupé par
    sections ; multi-serveurs préservé (retour à la liste via l'en-tête / « Plus → Serveur »).
  - ✅ **Accueil A — tableau de bord** (#84) — carte hero impression conditionnelle, cartes
    imprimantes (strip températures), bandeau alerte conditionnel, actions rapides.
  - ✅ **Détail imprimante enrichi B** (#85) — en-tête caméra, strip températures, strip AMS.
  - ✅ **Captures de revue** FR sombre/clair des nouveaux écrans (`docs/screenshots/refonte/`) via
    le scheme `BamPocketScreenshots` (`UITEST_LIVE=1`, Docker dev).
  - ⬜ **Variante C — grille flotte** (maquette `06-accueil-C-grille.png`) : disposition alternative
    de l'Accueil en grille de tuiles imprimantes pour parcs multi-machines. **Non implémentée** —
    amélioration future (A retenue comme défaut ; C envisageable en option/iPad).
  - ✅ **Données de revue riches** (#111) : ajout d'un **mode démo intégré** (`-uitest-demo`,
    `BambuddyPocket/App/Demo/`) — un `URLProtocol` local sert des fixtures synthétiques (imprimante
    en cours/au repos, AMS plein, archives, file, bibliothèque, G-code d'aperçu) **sans backend ni
    imprimante réelle**. Remplace le besoin de piloter une VP : les captures phares affichent un
    parc actif. Le Docker dev (X2D réel) reste en lecture seule.
- ✅ **Captures marketing App Store + fiche** (#111) : 5 écrans phares (Accueil, détail imprimante,
  Archives, viewer 3D, File) en **fr/en**, sombre, **6.9" (1320×2868)** →
  `docs/appstore/screenshots/{fr,en}/` (`AppStoreScreenshotTests`, `SCREENSHOT_CAPTURE=1`) ; fiche
  prête à coller → `docs/appstore/listing.md` (descriptions FR/EN, mots-clés, **4+**, catégorie,
  notes v0.1, App Privacy). Jeu 6.5"/6.7" optionnel (App Store Connect accepte le 6.9").
- 🟦 Tests **XCUITest sur chemins critiques** (`CriticalPathUITests`, exécutés en CI, sans backend) :
  ajout d'un serveur via le formulaire → détail → navigation vers Imprimantes → centre de
  notifications ; écran À propos ; annulation d'ajout. Captures (`ScreenshotTests`,
  `AppStoreScreenshotTests`) isolées derrière `UITEST_LIVE=1` / `SCREENSHOT_CAPTURE=1` (skip en CI).
  ✅ unitaire étendu (`StatusPresentationTests`, `DemoFixturesTests` — #111). Build sans warning.
- 🟦 **Icône d'app** (✅ DA BamPocket : « B » sombre dans une pastille verte sur fond `#1A1A1A`,
  générée par script reproductible Core Graphics, toutes tailles + master 1024) et **launch
  screen** (✅ logo centré + fond sombre via `UILaunchScreen`), ✅ **mentions open source**
  (écran À propos complet : licence AGPL + lien, attribution Bambuddy + lien, composants embarqués
  three.js/examples/fflate/Inter avec licences et liens) ; ✅ **captures** App Store + ✅
  **classification d'âge** (4+, justifiée dans `docs/appstore/listing.md`) — #111.
- 🟦 **Privacy manifest** (`PrivacyInfo.xcprivacy`) : aucun tracking, aucune collecte ; **API à
  raison requise** déclarée (UserDefaults `CA92.1`). Clés Info.plist runtime :
  `NSLocalNetworkUsageDescription` (connexions directes aux serveurs/imprimantes locaux). Pas de
  Bonjour/mDNS côté app (SSDP fait par le serveur) ni d'appareil photo (flux réseau). ⬜
  conformité HIG + App Review (étape de soumission).
- ✅ **Sideload iPhone (free provisioning, sans compte payant)** : entitlements minimaux (aucune
  capability bloquante ; trousseau via service applicatif, pas de groupe d'accès ; signature
  automatique compatible équipe personnelle), bundle id unique `com.bampocket.app`, guide
  pas-à-pas [`docs/SIDELOAD.md`](docs/SIDELOAD.md) (caveat des 7 jours, `xcodegen generate`
  préalable, autorisation réseau local sur device).
- ⬜ Étapes nécessitant le compte Apple Developer (à la charge de l'utilisateur) : enrôlement,
  signature distribution, TestFlight, soumission, réponses à la revue.
