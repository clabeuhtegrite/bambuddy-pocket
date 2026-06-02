# ADR-0003 — Connectivité, transport et sécurité

- **Statut** : ✅ Accepté
- **Date** : 2026-06-02

## Contexte
Serveurs Bambuddy auto-hébergés, joignables de façons variées : LAN HTTP, Tailscale/VPN, reverse
proxy HTTPS, Cloudflare Access (service token). Secrets sensibles. Cible App Store (ATS, réseau
local, privacy).

## Décisions

### Modèle « serveur »
`ServerConfiguration` :
```
id: UUID
label: String
baseURL: URL                 // schéma + hôte + port (ex. http://192.168.1.50:8000)
authMethod: .none | .apiKey | .userPassword
cloudflareAccess: Bool       // si vrai, en-têtes CF sur TOUTES les requêtes
allowInsecureLocalHTTP: Bool // HTTP autorisé seulement si hôte privé/local
```
- L'URL **WebSocket** dérive de `baseURL` : `http→ws`, `https→wss`, même hôte/port, chemin
  `/api/v1/ws`.
- Secrets associés (api key, mot de passe/JWT, `CF-Access-Client-Id`/`-Secret`) **jamais** dans
  `ServerConfiguration` : stockés à part au **Keychain**, référencés par `id`.

### Authentification (cf. `docs/bambuddy-api.md` §3)
- Sonder `GET /api/v1/auth/status` à l'ajout/connexion.
- `.none` : rien à envoyer. `.apiKey` : `X-API-Key` (ou `Authorization: Bearer bb_…`).
  `.userPassword` : login → JWT (+ 2FA via `pre_auth_token`), `Authorization: Bearer <jwt>`.
- Centraliser l'ajout des en-têtes dans `RequestFactory` (REST) et à l'ouverture du `WebSocket`
  (en-têtes d'upgrade) et sur les URL caméra.

### Cloudflare Access (service token)
- Si activé : ajouter `CF-Access-Client-Id` + `CF-Access-Client-Secret` sur **toutes** les
  requêtes REST, sur l'**upgrade WebSocket** (`URLRequest` du `webSocketTask`), et sur les
  requêtes **caméra** (flux + snapshot).
- Le flux/snapshot caméra ne pouvant pas toujours porter d'en-tête (balise image), prévoir aussi
  le **stream token** Bambuddy en query (`?token=…`) quand l'auth Bambuddy est active.

### App Transport Security (ATS)
- **HTTPS par défaut.** Exception **limitée** pour HTTP sur **adresses locales/privées**
  (serveur auto-hébergé sur LAN), documentée pour la revue App Store.
- Approche : `NSAllowsLocalNetworking` (autorise les noms `.local` et adresses privées sans
  affaiblir le reste) plutôt que `NSAllowsArbitraryLoads`. Si un cas exige HTTP vers une IP
  publique (rare, déconseillé), le restreindre par domaine via `NSExceptionDomains` documentés.
- L'app **avertit** l'utilisateur quand une connexion est en clair (HTTP).

### Réseau local iOS
- `NSLocalNetworkUsageDescription` requis (accès aux imprimantes/serveurs sur le LAN).
- (Découverte mDNS hors MVP ; ajout par IP.)

### Stockage des secrets — Keychain
- Wrapper `SecretStore` (protocole) au-dessus de `Security.framework` (`kSecClassGenericPassword`).
- Accessibilité `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (pas de synchro iCloud par
  défaut). Clés namespacées par `serverID` + type de secret.
- **Aucun secret** en `UserDefaults`, en logs, ni dans le dépôt.

### Confidentialité / réseau
- Aucune télémétrie tierce. Trafic uniquement vers les serveurs configurés par l'utilisateur.
- Privacy manifest (`PrivacyInfo.xcprivacy`) : déclarer l'absence de collecte/tracking ; raisons
  d'API requises le cas échéant.

## Conséquences
- Sécurité par défaut (HTTPS, Keychain, pas de collecte), tout en supportant le LAN HTTP encadré.
- Logique d'en-têtes centralisée → un seul endroit à auditer.
