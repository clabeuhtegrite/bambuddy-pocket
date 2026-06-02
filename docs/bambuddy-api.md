# Bambuddy API — Contrat pour le client iOS (Bambuddy Pocket)

> **Statut** : rédigé à partir de la reconnaissance de l'Étape 1 (clone du dépôt
> [`maziggy/bambuddy`](https://github.com/maziggy/bambuddy) + instance Docker locale).
> Ce document est le **contrat de référence** pour la couche réseau et les modèles de l'app.
> La source machine fait foi : [`docs/api/openapi.json`](api/openapi.json) (OpenAPI 3.1) et
> le catalogue exhaustif [`docs/api/rest-endpoints.md`](api/rest-endpoints.md).
>
> Version cartographiée : **Bambuddy 0.2.4.4** — 493 chemins, **621 opérations REST**, 346 schémas.

---

## 1. Vue d'ensemble

Bambuddy est un gestionnaire auto-hébergé d'imprimantes 3D Bambu Lab (backend Python/FastAPI).
Il expose :

| Surface | Détail |
|---|---|
| **REST** | Préfixe `\/api/v1`. Ex. `GET http://host:8000/api/v1/printers/`. |
| **WebSocket** | `GET ws(s)://host/api/v1/ws` — statut temps réel + événements. |
| **Flux caméra** | MJPEG HTTP (`multipart/x-mixed-replace`) + snapshots JPEG. |
| **OpenAPI** | `GET /openapi.json` (non préfixé). Swagger UI sur `/docs`. |
| **Santé** | `GET /health` → `{"status":"healthy"}`. `GET /api/v1/system/health`, `/system/info`. |

- **Port par défaut** : `8000` (configurable via `PORT`).
- **Base de données** : SQLite par défaut, PostgreSQL en option.
- L'API n'est **pas versionnée au-delà de `v1`** ; pas de header de version requis.

---

## 2. Modèle de connexion (côté app)

L'app gère une liste de **serveurs**, chacun défini par une URL de base (`schéma + hôte + port`).
Cas à supporter (cf. mission) :

1. **LAN en HTTP** — `http://192.168.x.y:8000`. Nécessite l'exception ATS (HTTP sur adresses
   privées) + autorisation réseau local iOS (`NSLocalNetworkUsageDescription`).
2. **Tailscale / VPN** — viser l'hôte ou le MagicDNS (`http(s)://machine.tailnet.ts.net:8000`).
3. **Reverse proxy HTTPS** — `https://bambuddy.exemple.com`.
4. **Cloudflare Access (service token)** — ajouter sur **toutes** les requêtes (REST **et**
   upgrade WebSocket **et** flux caméra) les en-têtes :
   - `CF-Access-Client-Id: <client-id>`
   - `CF-Access-Client-Secret: <client-secret>`
   Ces secrets vont au **Keychain**. Jamais en clair, jamais dans le dépôt.

> Implémentation : un `ServerConfiguration` { baseURL, auth, cfAccess?, allowInsecureHTTP } ;
> l'URL WebSocket dérive de la baseURL (`http→ws`, `https→wss`, même hôte/port, chemin `/api/v1/ws`).

---

## 3. Authentification

L'auth est **optionnelle et configurable par instance**. Toujours commencer par sonder l'état.

### 3.1 État

`GET /api/v1/auth/status` → `{ "auth_enabled": bool, "requires_setup": bool }`
- Instance fraîche (notre Docker de dev) : `{auth_enabled:false, requires_setup:true}` → **aucune
  auth requise**, toutes les routes sont ouvertes.
- `POST /api/v1/auth/setup` `{auth_enabled, admin_username?, admin_password?}` active l'auth
  et crée l'admin (`SetupResponse`).

### 3.2 Connexion par identifiants (JWT)

`POST /api/v1/auth/login` `LoginRequest { username, password }` →
`LoginResponse { access_token?, token_type, user?, requires_2fa, pre_auth_token?, two_fa_methods[] }`

- Si `requires_2fa == false` : `access_token` est un **JWT**. L'utiliser ensuite via
  `Authorization: Bearer <access_token>`.
- Si `requires_2fa == true` : pas de token encore. Le serveur renvoie `pre_auth_token` +
  `two_fa_methods` (`["totp","email","backup"]`). Il faut alors :
  `POST /api/v1/auth/2fa/verify` `TwoFAVerifyRequest { pre_auth_token, code, method }`
  → `TwoFAVerifyResponse` (contient le token final).
  - OTP e-mail : `POST /api/v1/auth/2fa/email/send` d'abord.
- `GET /api/v1/auth/me` → `UserResponse { id, username, email?, role, is_active, is_admin,
  auth_source, groups[], permissions[], created_at }` — valide le token et renvoie l'utilisateur.
- `POST /api/v1/auth/logout`.

### 3.3 Clés d'API (recommandé pour un client headless)

Deux transports équivalents :
- `X-API-Key: <clé>`
- `Authorization: Bearer bb_xxx` (les clés sont préfixées `bb_`).

Création : `POST /api/v1/api-keys/` `APIKeyCreate { name, can_queue, can_control_printer,
can_read_status, can_access_cloud, can_update_energy_cost, printer_ids?[], expires_at? }`
→ `APIKeyCreateResponse` qui inclut le champ **`key`** (montré **une seule fois**). Permissions
**granulaires** par capacité et par imprimante. CRUD : `GET/PATCH/DELETE /api/v1/api-keys/{id}`.

> **Choix d'app** : supporter (a) instance sans auth, (b) login user/pass + 2FA → JWT,
> (c) clé d'API. Stocker tout token/clé/secret au **Keychain**. Le JWT pouvant expirer,
> gérer le rafraîchissement/relogin ; la clé d'API est plus simple pour une session longue.

### 3.4 OIDC / LDAP / SSO

Présents (`/auth/oidc/*`, `/auth/ldap/*`). Hors périmètre MVP ; à considérer plus tard.

### 3.5 Cloudflare Access

Orthogonal à l'auth Bambuddy : c'est une couche de proxy. Les en-têtes CF (§2.4) s'ajoutent
**en plus** du Bearer/X-API-Key éventuel.

---

## 4. WebSocket temps réel

### 4.1 Cycle de vie

- URL : `ws(s)://host/api/v1/ws` (le front web l'ouvre en same-origin, sans token explicite ;
  il s'appuie sur le cookie de session. Pour le natif : ajouter les en-têtes CF Access, et —
  si l'instance est authentifiée — vérifier si un cookie/JWT est requis sur l'upgrade
  → **à valider sur instance auth activée**, cf. §12).
- À la connexion, le serveur **pousse l'état initial** : un message `printer_status` par
  imprimante connue, puis éventuellement `background_dispatch` si une distribution est en cours.
- **Keepalive** : le client envoie `{"type":"ping"}` → serveur répond `{"type":"pong"}`.
- **Demande ciblée** : `{"type":"get_status","printer_id":<int>}` → renvoie un `printer_status`.

### 4.2 Événements poussés par le serveur (client ← serveur)

Tous les messages ont la forme `{ "type": <str>, ... }`.

| `type` | Charge utile | Usage app |
|---|---|---|
| `printer_status` | `{ printer_id, data: <PrinterStatus partiel> }` | **Cœur** : MAJ live de l'imprimante. Fusionner `data` dans l'état courant. |
| `print_start` | `{ printer_id, data }` | Début d'impression → notif en-app. |
| `print_complete` | `{ printer_id, data }` | Fin d'impression → notif en-app. |
| `archive_created` | `{ data: <Archive> }` | Nouvelle archive d'impression. |
| `archive_updated` | `{ data: <Archive> }` | Archive modifiée (photo, métadonnées…). |
| `missing_spool_assignment` | `{ printer_id, printer_name, missing_slots[] }` | Impression lancée sans bobine assignée → alerte. |
| `plate_not_empty` | détection plateau non vide | Alerte avant impression suivante. |
| `background_dispatch` | `{ data: { dispatched, processing, … } }` | Progression de la distribution en file. |
| `inventory_changed` | — | Rafraîchir l'inventaire filaments. |
| `spool_assignment_changed`, `spool_usage_logged`, `spool_auto_assigned` | — | Suivi bobines/AMS. |
| `spoolbuddy_*` (`_online`, `_offline`, `_weight`, `_tag_matched`, `_tag_written`, `_tag_link_failed`, `_unknown_tag`, `_update`…) | — | Lecteur RFID SpoolBuddy (hors MVP). |
| `firmware_upload_progress` | progression | Mise à jour firmware. |
| `unknown_tag` | tag RFID inconnu | SpoolBuddy. |
| `spoolman_unavailable`, `spoolman_ssrf_blocked` | — | Intégration Spoolman. |
| `pong` | — | Réponse keepalive. |

> Liste dérivée du code (`backend/app/core/websocket.py` + occurrences `"type": "…"`).
> Les `printer_status` initiaux + `print_start`/`print_complete` + `archive_*` couvrent le MVP.

### 4.3 Forme de `printer_status.data`

C'est le sérialiseur `printer_state_to_dict` (cf. §5.1). Le WS pousse un **sous-ensemble vivant**
de `PrinterStatus` ; le REST `GET /printers/{id}/status` renvoie le **sur-ensemble complet**.
→ Modéliser un seul type `PrinterStatus` (tous champs optionnels sauf `id`/`name`/`connected`)
et **fusionner** les deltas WS dessus.

---

## 5. Modèles de données clés

> Champs marqués `*` = requis (selon OpenAPI). `?` = nullable. Listes = `[]`.

### 5.1 `PrinterStatus` — modèle central (REST `GET /printers/{id}/status`, 53 champs)

```
id*:int, name*:str, connected*:bool
state?:str            // "RUNNING" | "PAUSE" | "IDLE" | "FINISH" | "FAILED" | "PREPARE" | "SLICING" ...
current_print?:str, subtask_name?:str, gcode_file?:str
progress?:num         // 0–100
remaining_time?:int   // minutes
layer_num?:int, total_layers?:int
temperatures?:obj     // { nozzle, nozzle_target, bed, bed_target, chamber, chamber_target, ... }
cover_url?:str        // "/api/v1/printers/{id}/cover" si impression active, sinon null
hms_errors:HMSErrorResponse[]
ams:AMSUnit[], ams_exists:bool, vt_tray:AMSTray[]
sdcard:bool, store_to_sdcard:bool, timelapse:bool, ipcam:bool
wifi_signal?:int, wired_network:bool, door_open?:bool
nozzles:NozzleInfoResponse[], nozzle_rack:NozzleRackSlot[]
print_options?:PrintOptionsResponse
stg_cur:int, stg_cur_name?:str, stg:int[]    // étape de calibration en cours
airduct_mode:int, speed_level:int            // 1=silencieux,2=standard,3=sport,4=ludicrous
chamber_light:bool, active_extruder:int      // 0=droite,1=gauche
ams_mapping:int[], ams_extruder_map:obj, tray_now:int
ams_status_main:int, ams_status_sub:int, mc_print_sub_stage:int, last_ams_update:num
fila_switch?:FilaSwitchResponse
printable_objects_count:int                  // pour "skip objects"
cooling_fan_speed?:int, big_fan1_speed?:int, big_fan2_speed?:int, heatbreak_fan_speed?:int
firmware_version?:str, developer_mode?:bool
awaiting_plate_clear:bool, supports_drying:bool
current_archive_id?:int, current_plate_id?:int
```

**`AMSUnit`** : `{ id, humidity?, temp?, is_ams_ht, serial_number, sw_ver, dry_time, dry_status,
dry_sub_status, dry_sf_reason[], module_type, tray: AMSTray[] }`

**`AMSTray`** (slot filament) : `{ id, tray_color (hex RGBA), tray_type ("PLA"/"PETG"/…),
tray_sub_brands, tray_id_name, tray_info_idx, remain (0–100), k, cali_idx, tag_uid?, tray_uuid?,
nozzle_temp_min?, nozzle_temp_max?, drying_temp?, drying_time?, state }`

**`HMSErrorResponse`** : `{ code*:str, attr?:int, module*:int, severity*:int }`
- Pas d'endpoint code→texte côté serveur ; embarquer une table HMS (code → message localisé)
  dans l'app. `severity` permet de hiérarchiser (fatal/sérieux/info).

### 5.2 `PrinterResponse` / `PrinterCreate` (config d'une imprimante côté serveur)

```
PrinterCreate*: name, serial_number, ip_address, access_code   // identifiants LAN Bambu
  + model?, location?, auto_archive, external_camera_url?/type?/enabled, camera_rotation
PrinterResponse: + id, is_active, nozzle_count, print_hours_offset, plate_detection_*, created_at, updated_at
```
> « Ajouter une imprimante » dans l'app = `POST /printers/` (serial + IP + access code Bambu).
> À distinguer de « ajouter un serveur » (config app, §2).

### 5.3 `ArchiveResponse` (55 champs) / `ArchiveSlim` (vue liste, 13)

```
ArchiveSlim: printer_id?, print_name?, print_time_seconds?, actual_time_seconds?,
  filament_used_grams?, filament_type?, filament_color?, status, started_at?, completed_at?,
  cost?, quantity, created_at
ArchiveResponse (sélection): id, printer_id?, filename, file_path, file_size, content_hash?,
  thumbnail_path?, timelapse_path?, source_3mf_path?, f3d_path?, object_count?, print_name?,
  print_time_seconds?, actual_time_seconds?, time_accuracy?, filament_used_grams?, filament_type?,
  filament_color?, layer_height?, total_layers?, nozzle_diameter?, bed_temperature?, bed_type?,
  nozzle_temperature?, sliced_for_model?, status, started_at?, completed_at?, makerworld_url?,
  designer?, is_favorite, tags?, notes?, cost?, photos[]?, failure_reason?, quantity, energy_kwh?,
  energy_cost?, run_count, last_run_at?, created_by_username?
```
- Vignette : via `thumbnail_path` (servie par l'API). Photos de fin : `photos[]`.

### 5.4 `PrintQueueItemResponse` (47 champs) / `PrintQueueItemCreate` / `PrintBatchResponse`

```
PrintQueueItemCreate: archive_id? | library_file_id?, printer_id?, target_model?, target_location?,
  scheduled_time?, quantity, project_id?, ams_mapping?[], plate_id?, manual_start,
  require_previous_success, auto_off_after, use_ams, bed_levelling, flow_cali, vibration_cali,
  layer_inspect, timelapse, gcode_injection, required_filament_types?[], filament_overrides?[]
PrintQueueItemResponse: + id, position, status (pending|printing|completed|failed|skipped|cancelled),
  waiting_reason?, started_at?, completed_at?, error_message?, archive_name?, archive_thumbnail?,
  printer_name?, print_time_seconds?, filament_used_grams?, batch_id?, batch_name?, been_jumped, ...
```
- Réordonnancement : `POST /queue/reorder` `{ items: [{id, position}] }`.
- Lots (batches) : `GET /queue/batches`, compteurs pending/printing/completed/failed/cancelled.

### 5.5 `UserResponse`, `AppSettings`

- `UserResponse` : cf. §3.2.
- `AppSettings` : **105 champs** de config serveur (thème, langue, devise, coût énergie, Spoolman,
  MQTT, HA, LDAP, Obico, slicer…). La plupart sont admin-only ; l'app peut **lire** quelques
  champs utiles (`language`, `date_format`, `time_format`, `currency`, `default_printer_id`,
  `camera_view_mode`). `GET /api/v1/settings/…`.

---

## 6. Caméra

- **Flux MJPEG** : `GET /api/v1/printers/{id}/camera/stream` → `multipart/x-mixed-replace;
  boundary=frame`. Le backend transcode le RTSP chambre (ffmpeg) ou la caméra externe en MJPEG.
  → Côté iOS : **pas de lecteur RTSP nécessaire**, consommer le flux multipart (parseur de
  frames JPEG sur `URLSession` data task, ou WebView). 
- **Snapshot** : `GET /api/v1/printers/{id}/camera/snapshot` → `image/jpeg` (image unique).
- **Statut caméra** : `GET /api/v1/printers/{id}/camera/status`.
- **Token de flux** : `POST /api/v1/printers/camera/stream-token` → `{ "token": "…" }`.
  ⚠️ Quand l'auth est activée (`RequireCameraStreamTokenIfAuthEnabled`), `stream` et `snapshot`
  **exigent** ce token — à passer en **query string** (`?token=…`), car une balise image/un flux
  ne peut pas porter d'en-tête `Authorization`. Sans auth : pas de token nécessaire.
- Détection IA « plateau vide » : `/camera/check-plate`, `/camera/plate-detection/*` (avancé).

---

## 7. Contrôles d'impression (Phase 2 — écritures)

Endpoints `POST` sous `/api/v1/printers/{id}/…` :

| Action | Endpoint |
|---|---|
| Pause / Reprise / Stop | `print/pause`, `print/resume`, `print/stop` |
| Sauter des objets | `print/skip-objects` (body : `int[]` des ids ; cf. `print/objects` pour la liste) |
| Lumière chambre | `chamber-light` |
| Vitesse d'impression | `print-speed` (1–4) |
| Options d'impression | `print-options` |
| Libérer le plateau | `clear-plate` |
| Axes / jog | `home-axes`, `bed-jog` |
| Calibration | `calibration` |
| AMS charger / décharger | `ams/load`, `ams/unload`, `ams/{ams}/tray/{tray}/reset` |
| Séchage AMS | `drying/start`, `drying/stop` |
| Effacer erreurs HMS | `hms/clear` |
| (Dé)connecter | `connect`, `disconnect` |

File d'attente (Phase 2) : CRUD `/api/v1/queue/`, `reorder`, `bulk`, `{id}/start|stop|cancel`,
`batches`. Distribution auto : `background-dispatch`.

> Sur la **démo (lecture seule)** ces écritures ne sont pas testables → les développer/tester sur
> le Docker local (idéalement avec une **imprimante virtuelle**, cf. §11).

---

## 8. Notifications

- Les routes `/api/v1/notifications/*` configurent des **fournisseurs côté serveur** (webhook,
  e-mail, ntfy, Discord, etc.) — ce n'est **pas** la notification en-app demandée.
- `GET /api/v1/notifications/logs` → `NotificationLogResponse[]` : **historique** des notifications
  émises (event_type, title, message, success, printer_id, created_at). Exploitable comme flux
  d'activité en lecture dans l'app.
- **Notifications EN-APP** (objectif mission) : à **dériver côté client** des événements WS
  (`print_complete`, `print_start`, `missing_spool_assignment`, `plate_not_empty`, `hms_errors`
  passant en sévérité haute…). Pas d'APNs, pas de push serveur.

---

## 9. Découverte, système, divers

- **Découverte** `/api/v1/discovery/*` : mDNS + scan de sous-réseau. **Ne marche pas** en Docker
  bridge (cf. note macOS) → ajout d'imprimante par IP manuel. `DiscoveredPrinterResponse
  { serial, name, ip_address, model?, discovered_at? }`.
- **Système** : `/system/info`, `/system/health`, `/system/storage-usage`.
- Autres domaines présents (cf. catalogue) : `inventory`, `library`, `projects`, `spoolman`,
  `spoolbuddy`, `cloud` (Bambu Cloud), `smart-plugs`, `maintenance`, `firmware`, `groups`,
  `kprofiles`, `labels`, `makerworld`, `obico`, `slice-jobs`, `slicer-presets`, `local-backup`,
  `github-backup`, `metrics`, `updates`, `support`, `webhook`, `virtual-printers`.

---

## 10. Cartographie domaine → phase de l'app

| Domaine API (tag) | Ops | Phase | Rôle dans l'app |
|---|---:|---|---|
| `printers` | 59 | **1**/2 | Liste, statut, détail, contrôles. |
| WebSocket `/ws` | — | **1** | Temps réel (cœur). |
| `archives` | 63 | **1** | Archive d'impressions (consultation, photos, métadonnées). |
| `camera` | 17 | **1** | Flux MJPEG + snapshots. |
| `authentication` + `2fa` + `api-keys` | 53 | **0** | Connexion serveur (login/2FA/clé). |
| `queue` + `background-dispatch` | 14 | **2** | File, planification, distribution. |
| `notifications` (logs) | 11 | **2** | Flux d'activité ; en-app dérivé du WS. |
| `inventory` `spoolman` `filament-catalog` `spoolbuddy` | 79 | 2/3 | Bobines/AMS/RFID. |
| `library` `projects` `pending-uploads` | 69 | 3 | Bibliothèque de modèles/fichiers. |
| `slice-jobs` `slicer-presets` `Slicer Presets` `kprofiles` | 22 | **3** | Slicing (sidecar). |
| `settings` `system` `updates` `maintenance` `firmware` | 52 | transverse | Réglages/état serveur. |
| `cloud` `smart-plugs` `obico` `makerworld` `groups` `labels` … | — | 3+ | Intégrations avancées. |

Le catalogue **exhaustif** (621 ops) est dans [`docs/api/rest-endpoints.md`](api/rest-endpoints.md).

---

## 11. Lancer l'instance de dev (Docker, macOS)

Docker Desktop ne supporte pas `network_mode: host`. Dans `docker-compose.yml` :
commenter `network_mode: host`, décommenter la section `ports:` (au minimum `8000`).
La découverte d'imprimantes ne marchera pas → **ajout par IP manuel**.

```bash
# dans une copie du dépôt bambuddy
docker compose up -d            # tire l'image ghcr.io/maziggy/bambuddy:latest
curl -s http://localhost:8000/health                 # {"status":"healthy"}
curl -s http://localhost:8000/api/v1/auth/status      # {auth_enabled:false, requires_setup:true}
open http://localhost:8000/docs                       # Swagger
```

- **Imprimante virtuelle** : Bambuddy embarque un simulateur (`virtual-printers`, ports 3000/3002/
  8883). Piste pour tester les **écritures** (Phase 2) sans matériel — à explorer.
- La **démo** <https://bambuddy.cool> est en **lecture seule** : recette pour valider l'UI/lecture,
  jamais pour les écritures.

---

## 12. Points à valider / questions ouvertes

1. **Auth WebSocket sur instance authentifiée** : le handler `/ws` n'a pas de dépendance d'auth
   explicite ; le front s'appuie sur le cookie same-origin. Vérifier si un JWT/cookie est exigé
   sur l'upgrade quand l'auth est activée (tester via Docker en activant l'auth).
2. **HMS code→texte** : confirmer la table de correspondance (le front embarque-t-il un mapping ?
   sinon, sourcer une table HMS Bambu et la localiser).
3. **Expiration JWT** : durée de vie + mécanisme de refresh (sinon, relogin ou clé d'API).
4. **Pagination** des gros listings (`archives`, `inventory`, `library`) : vérifier params
   `limit`/`offset`/`cursor` dans l'OpenAPI avant d'implémenter les listes.
5. **Flux caméra derrière Cloudflare Access** : confirmer que les en-têtes CF passent sur une
   requête de streaming longue (timeouts proxy) ; sinon fallback snapshots périodiques.
6. **Imprimante virtuelle** : faisabilité pour tester start/pause/stop en CI/local.
