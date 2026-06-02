# ADR-0002 — Architecture de l'application

- **Statut** : ✅ Accepté
- **Date** : 2026-06-02

## Contexte
App iOS native (iPhone+iPad, iOS 18+), SwiftUI, MVVM, `async/await`, DI, séparation nette
réseau/domaine/UI, tests sur chemins critiques, dépendances tierces minimales.

## Décision

### Modularisation (paquets SPM locaux + cible app)
Un projet Xcode `Spoolside.xcodeproj` (cible app SwiftUI) qui dépend d'un paquet SPM local
`Packages/SpoolsideKit` découpé en cibles à dépendances orientées :

```
SpoolsideDomain        // modèles métier + protocoles de service. AUCUNE dépendance.
SpoolsideNetworking    // REST + WebSocket + caméra. dépend de Domain.
SpoolsideDesignSystem  // tokens, couleurs, typo Dynamic Type, composants. dépend de Domain (types légers).
SpoolsideFeatures      // (option, extrait plus tard) vues + view-models par feature.
+ cibles de test : DomainTests, NetworkingTests, …
```
La cible app contient le point d'entrée (`@main`), la composition root (DI) et, au début, les
features ; on extrait `SpoolsideFeatures` quand ça stabilise. Bénéfice : tests unitaires rapides
sans hôte d'app, frontières de dépendances imposées par le compilateur.

### MVVM + Observation
- Vues **SwiftUI** ; view-models en `@Observable` (framework Observation, iOS 17+).
- Le view-model ne connaît que des **protocoles de service** (Domain), jamais `URLSession`.
- Pas de logique réseau/persistance dans les vues.

### Injection de dépendances (maison, sans framework tiers)
- **Composition root** dans la cible app : un `AppEnvironment` (struct) qui instancie les
  services concrets et les expose aux view-models par **injection par constructeur**.
- Pour SwiftUI, exposer l'environnement via `@Environment`/`EnvironmentValues` (clé dédiée).
- Services définis comme **protocoles** dans Domain → impl concrètes dans Networking → **fakes**
  dans les tests. Pas de singleton mutable global.

### Couche réseau
- `APIClient` (protocole, `async throws`) au-dessus d'`URLSession`.
- `RequestFactory` : construit les requêtes, **injecte l'auth** (Bearer/X-API-Key) **et les
  en-têtes Cloudflare Access** de façon centralisée (cf. ADR-0003).
- `WebSocketClient` : `URLSessionWebSocketTask`, reconnexion avec back-off, keepalive ping/pong,
  flux d'événements typés (`AsyncStream`/`AsyncThrowingStream`).
- **Décodage** : modèles `Codable` dans Domain pour le **sous-ensemble** utilisé (MVP), écrits à
  la main. `PrinterStatus` à champs optionnels (fusion des deltas WS). Génération depuis
  `openapi.json` envisageable plus tard si le volume le justifie.
- Mapping réseau→domaine : si des DTO divergent du domaine, mapper dans Networking ; sinon
  réutiliser les `Codable` directement pour limiter la verbosité.

### Persistance
- **Secrets** (tokens, secret Cloudflare, access codes) → **Keychain** uniquement (cf. ADR-0003).
- **Liste de serveurs** (champs non secrets : URL, libellé, options) → `Codable` en
  `UserDefaults` (ou SwiftData ultérieurement). Référence au secret par identifiant de serveur.

### Concurrence
- `async/await` partout ; isolation `@MainActor` pour les view-models et l'UI.
- Acteurs (`actor`) pour l'état réseau partagé si nécessaire (gestion connexions WS).

### Tests
- Unitaires : Domain (logique de fusion d'état, mapping HMS), Networking (décodage via fixtures
  JSON tirées de `docs/api/openapi.json`/réponses réelles), view-models (avec services fakes).
- UI : chemins critiques (ajout serveur, liste imprimantes, détail) via XCUITest.

## Conséquences
- Frontières claires, testabilité élevée, zéro dépendance tierce pour l'archi.
- Léger surcoût de configuration SPM initial (assumé).
