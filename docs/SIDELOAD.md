# Installer BamPocket sur votre iPhone (sideload, sans compte développeur payant)

Ce guide explique comment installer **BamPocket** sur **votre propre iPhone** depuis Xcode, en
utilisant le **free provisioning** (signature avec une **équipe personnelle** liée à votre identifiant
Apple — aucun compte Apple Developer payant requis).

> Limite Apple du free provisioning : le certificat est valable **7 jours**. Passé ce délai, l'app
> ne se lance plus tant qu'on ne l'a pas **réinstallée** depuis Xcode (re-signature). Avec un
> identifiant Apple gratuit, on peut signer **jusqu'à 3 apps** simultanément sur l'appareil.

## Pré-requis

- Un **Mac** avec **Xcode 26+** et les outils du projet (`brew install xcodegen swiftlint swiftformat`).
- Votre **identifiant Apple** ajouté à Xcode : `Xcode ▸ Settings… ▸ Accounts ▸ +` → *Apple ID*.
  Xcode crée automatiquement une **Personal Team** (« Votre nom (Personal Team) »).
- Un **iPhone** sous iOS 18 ou plus récent, et un **câble** (ou l'appairage Wi-Fi déjà configuré).

## 1. Générer le projet Xcode

Le `.xcodeproj` n'est **pas** versionné : il est généré depuis `project.yml`. À la racine du dépôt :

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "/chemin/vers/Bambuddy Pocket"
xcodegen generate
open BamPocket.xcodeproj
```

> Refaites `xcodegen generate` après chaque `git pull` qui touche `project.yml`, les sources ou les
> ressources (assets, String Catalog). Le projet ouvert dans Xcode est alors à jour.

## 2. Sélectionner l'équipe personnelle et régler la signature

Dans Xcode :

1. Sélectionnez le projet **BamPocket** dans le navigateur, puis la **cible** `BamPocket`.
2. Onglet **Signing & Capabilities**.
3. Cochez **Automatically manage signing**.
4. **Team** : choisissez votre **Personal Team** (« Votre nom (Personal Team) »).
5. **Bundle Identifier** : `com.bampocket.app` par défaut.
   - Si Xcode signale que l'identifiant est déjà pris (un autre compte l'a utilisé), remplacez-le
     par un identifiant **unique à vous**, par ex. `com.<votre-nom>.bampocket`. Aucune autre
     modification n'est nécessaire : l'app ne dépend d'aucun identifiant en dur (le **trousseau**
     utilise une chaîne de service fixe, indépendante du bundle id).

Xcode crée alors automatiquement un **profil de provisionnement de développement** pour votre
appareil. **Aucune capability spéciale n'est requise** : BamPocket n'utilise ni Push, ni Associated
Domains, ni App Groups, ni groupe d'accès trousseau partagé — uniquement des API standard
(réseau local, `UserDefaults`, trousseau via un service applicatif). Tout cela est **compatible
free provisioning**.

## 3. Brancher l'iPhone et l'autoriser

1. Connectez l'iPhone au Mac. Au premier branchement, déverrouillez-le et touchez **Se fier** à
   l'invite « Faire confiance à cet ordinateur ? ».
2. Dans Xcode, en haut, ouvrez le sélecteur de destination et choisissez **votre iPhone** (et non un
   simulateur). S'il apparaît grisé « Preparing… », laissez Xcode finir la préparation des symboles.

## 4. Compiler et lancer sur l'appareil

1. Cliquez sur **Run** (▶) ou `Cmd+R`.
2. Au premier lancement, iOS refuse l'app non vérifiée. Sur l'iPhone, allez dans :
   **Réglages ▸ Général ▸ VPN et gestion de l'appareil** (ou *Gestion des profils*), touchez le
   profil **développeur** à votre nom, puis **Faire confiance**.
3. Relancez l'app (depuis Xcode avec ▶, ou en touchant l'icône sur l'écran d'accueil).

L'icône **BamPocket** (pastille verte « B » sur fond sombre) doit apparaître sur l'écran d'accueil.

## 5. Première utilisation

- À l'ouverture, ajoutez votre serveur Bambuddy : bouton **+** → saisissez l'**URL** (par ex.
  `http://192.168.1.50:8000`) et un **libellé**, choisissez la méthode d'authentification, puis
  **Save**.
- Sur un **iPhone réel**, la première connexion à une adresse du réseau local déclenche l'invite
  **« BamPocket souhaite trouver et se connecter aux appareils de votre réseau local »** :
  touchez **Autoriser** (sinon l'app ne pourra pas joindre votre serveur/imprimante). Cette
  autorisation est gérée par la clé `NSLocalNetworkUsageDescription` déjà incluse.

## Renouveler après 7 jours

Quand l'app cesse de se lancer (« cette app n'est plus disponible »), il suffit de la **réinstaller**
depuis Xcode : iPhone branché, destination = votre iPhone, **Run** (▶). Le certificat est
re-signé pour 7 jours de plus.

## Notes pour la CI et le build « device »

- La **CI** du dépôt cible le **simulateur** avec `CODE_SIGNING_ALLOWED=NO` : elle ne nécessite
  aucune signature et n'est pas affectée par le sideload.
- Un build **device** en ligne de commande **sans identité de signature échoue volontairement** :

  ```bash
  xcodebuild -project BamPocket.xcodeproj -scheme BamPocket \
    -destination 'generic/platform=iOS' build
  # → error: Signing for "BamPocket" requires a development team.
  ```

  C'est **attendu** : la signature device se fait via l'équipe personnelle dans Xcode (étape 2),
  pas en CLI anonyme. Ce n'est **pas** un échec de la CI.
