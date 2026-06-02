# ADR-0001 — Choix de licence

- **Statut** : 🟡 **PROPOSÉ — en attente de décision de l'utilisateur** (cf. §Décision)
- **Date** : 2026-06-02
- **Décideurs** : propriétaire du projet (toi) ; rédigé par l'assistant.

## Contexte

Bambuddy (le serveur que Spoolside pilote) est sous **GNU AGPL v3** (fichier `LICENSE`,
texte officiel de l'Affero GPL 3.0). La mission demande : « **ALIGNER** sur celle de Bambuddy —
adopte la même (ou une compatible). Signale-moi toute implication copyleft. »

Deux objectifs **en tension** à concilier :

1. **Aligner sur Bambuddy / esprit copyleft** (préférence exprimée).
2. **Publier sur l'App Store** (objectif produit explicite).

### Fait juridique 1 — Spoolside est un client indépendant

Spoolside est une application **séparée** qui dialogue avec Bambuddy via une **API réseau**
(REST + WebSocket). Elle **n'incorpore, ne lie et ne dérive aucun code** de Bambuddy.
Selon l'interprétation de la FSF, communiquer avec un programme via un protocole réseau « à
distance » ne crée **pas** d'œuvre dérivée. **Conséquence : Spoolside n'est PAS juridiquement
contraint par l'AGPL de Bambuddy.** « Aligner » est donc une **préférence**, pas une obligation.

> ⚠️ Cela ne vaut que tant qu'on **ne copie pas** de code amont (p. ex. porter du Python,
> réutiliser le `gcode_viewer` JS, recopier des schémas protégeables). Les **noms d'endpoints
> et de champs JSON** (interface fonctionnelle) ne sont en principe pas protégeables.

### Fait juridique 2 — Conflit GPL/AGPL ↔ App Store (le « problème VLC »)

Les licences GPL/AGPL interdisent d'imposer des **restrictions supplémentaires** aux destinataires.
Or les **conditions d'utilisation de l'App Store** d'Apple imposent des restrictions (DRM,
limitation du nombre d'appareils, etc.) jugées **incompatibles** avec la GPL/AGPL. Précédent connu :
VLC retiré de l'App Store en 2011 sur plainte GPL, revenu ensuite via une décision du **détenteur
des droits**. → **Distribuer un binaire GPL/AGPL sur l'App Store nécessite que le titulaire des
droits accorde une exception explicite.** Comme tu seras **seul titulaire** des droits sur le code
original de Spoolside, tu **peux** accorder cette exception.

## Options

| # | Licence | Alignement Bambuddy | App Store | Remarques |
|---|---|---|---|---|
| 1 | **AGPL-3.0 + exception App Store** | ★★★ (identique) | ✅ via exception | Mirroir exact. Mais la **clause réseau** (§13) de l'AGPL n'a guère de sens pour un **client** local. |
| 2 | **GPL-3.0 + exception App Store** | ★★☆ (copyleft fort, sans clause réseau) | ✅ via exception | Copyleft « classique », plus adapté à un client que l'AGPL. |
| 3 | **MPL-2.0** | ★★☆ (copyleft **par fichier**) | ✅ sans exception | Garde ouverts les fichiers Spoolside ; pas de portée « virale » → pas de conflit App Store. |
| 4 | **Apache-2.0** | ★☆☆ (permissive, **compatible**) | ✅ sans friction | Grant de brevet, adoption maximale ; OSI open source ; pleinement compatible avec l'usage d'un serveur AGPL. |

Notes :
- Toutes ces options sont **open source (OSI)** et **compatibles** avec le fait de piloter un
  serveur AGPL (rien n'oblige le client à être copyleft).
- Les options 1–2 exigent de **rédiger soigneusement** le texte de l'exception App Store et
  d'apposer des en-têtes par fichier.
- Les options 3–4 **évitent** toute friction App Store et la rédaction d'une exception.

## Décision

🟡 **À confirmer par l'utilisateur.** Recommandation par profil :

- Si la priorité est **l'alignement copyleft avec Bambuddy** → **Option 1 (AGPL-3.0 + exception
  App Store)**, ou **Option 2 (GPL-3.0 + exception)** qui est plus cohérente pour un client.
- Si la priorité est **la simplicité de publication + l'adoption** → **Option 4 (Apache-2.0)**
  (recommandation « ingénierie » pour un client public), ou **Option 3 (MPL-2.0)** comme
  compromis copyleft léger.

**En attendant la décision**, aucun fichier `LICENSE` définitif ni en-tête par fichier n'est
posé (pour éviter tout retravail). Le dépôt porte un `NOTICE` pointant vers cet ADR. Le dépôt
restant **privé** pendant le développement, la licence sera **figée avant la publication**.

## Conséquences

- **Tant que privé** : faible enjeu, on code.
- **Avant public/App Store** : figer la licence ici, ajouter `LICENSE` (+ exception App Store si
  options 1–2), en-têtes SwiftLint, mention dans le README, et — par courtoisie — créditer
  Bambuddy + lier son dépôt (le client respecte l'écosystème amont).
- **Ne jamais** copier de code amont sans réévaluer cette analyse.
