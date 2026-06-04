# ADR-0004 — Nom du projet

- **Statut** : ✅ Accepté — **« BamPocket »** (nom final, décidé le 2026-06-04 ; remplace
  « Bambuddy Pocket », lui-même successeur du code « Spoolside »)
- **Date** : 2026-06-04 (révision ; original 2026-06-03)

## Contexte

Le brief initial fixait le nom de code provisoire « **Spoolside** » et demandait d'**éviter
« Bambuddy »/« Bambu » partout** (nom d'affichage, bundle ID, assets, dépôt) tant que les droits
ne sont pas confirmés — par prudence vis-à-vis de la **marque**. Le dépôt, les docs et la config
ont d'abord été créés sous « Spoolside ».

L'utilisateur a ensuite demandé de renommer le projet en « **Bambuddy Pocket** ». Le **2026-06-04**,
il a tranché pour le nom final **« BamPocket »** (un seul mot, B et P majuscules) et **assume le
choix du nom côté droits** — la clearance/relecture pré-publication demeure de son ressort.

## Décision

Adopter « **BamPocket** » comme nom final de l'app :

| Élément | Valeur |
|---|---|
| Nom d'affichage / marque (prose) | **BamPocket** (un mot, `CFBundleDisplayName`) |
| Dépôt GitHub | `clabeuhtegrite/bambuddy-pocket` (slug **historique conservé** — ne pas renommer) |
| Bundle ID | `com.bampocket.app` (`.tests` / `.uitests` pour les cibles de test) |
| Cible/scheme Xcode, produit | `BamPocket` (schemes `BamPocket` + `BamPocketScreenshots`) |
| Paquet SPM / modules **internes** | `BambuddyPocketKit` → `BambuddyPocketDomain`, `…Networking`, `…DesignSystem` — **noms conservés** (non visibles par l'utilisateur ; un renommage toucherait tous les `import` pour aucun gain produit) |
| Service Keychain | `app.bambuddy.pocket.secrets` (chaîne fixe, indépendante du bundle ID — conservée pour ne pas invalider les secrets déjà stockés) |
| Label launchd superviseur | `com.bambuddypocket.supervisor` (hors app, conservé) |

## Conséquences & risques

- ✅ **Nom final « BamPocket »** : ne contient plus « Bambuddy » dans le nom d'affichage, ce qui
  réduit la surface de conflit de marque côté identité produit. L'app reste un **client tiers de
  Bambuddy** ; la prose (README/NOTICE/À propos) référence « Bambuddy » comme la cible logicielle,
  pas comme la marque de l'app.
- ⚠️ **Clearance / relecture pré-publication = ressort de l'utilisateur** : il assume le choix du
  nom côté droits. Une vérification de marque et la mention « non affilié » restent recommandées
  avant publication, mais ce sont des étapes hors-code à sa charge.
- **À faire avant toute publication / soumission App Store** :
  1. Vérification de disponibilité/again de marque (au moins une recherche sérieuse ; idéalement
     conseil juridique).
  2. **Contacter l'auteur amont** (maziggy/Bambuddy) pour obtenir son accord/bénédiction sur le
     nom dérivé, voire un co-branding clair (« … for Bambuddy »).
  3. Mention « non affilié » visible (README, NOTICE, à terme la fiche App Store).
- **Plan de repli** : si un problème de droits surgit, un **renommage** reste possible (le code
  isole le nom dans peu d'endroits : bundle ID, target, `*Kit`, assets, chaînes localisées). Garder
  cette ADR pour retrouver rapidement la liste des points à changer.

> Cet ADR remplace l'usage du code « Spoolside » présent dans les premiers commits.
