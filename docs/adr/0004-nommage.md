# ADR-0004 — Nom du projet

- **Statut** : ✅ Accepté — **« Bambuddy Pocket »** (décidé le 2026-06-03 ; remplace le code « Spoolside »)
- **Date** : 2026-06-03

## Contexte

Le brief initial fixait le nom de code provisoire « **Spoolside** » et demandait d'**éviter
« Bambuddy »/« Bambu » partout** (nom d'affichage, bundle ID, assets, dépôt) tant que les droits
ne sont pas confirmés — par prudence vis-à-vis de la **marque**. Le dépôt, les docs et la config
ont d'abord été créés sous « Spoolside ».

L'utilisateur a ensuite demandé de renommer le projet en « **Bambuddy Pocket** » et, après que le
**risque de marque a été explicitement signalé**, a confirmé vouloir **tout renommer** (dépôt,
bundle, docs, identifiants de code).

## Décision

Adopter « **Bambuddy Pocket** » comme nom (de code, provisoire) :

| Élément | Valeur |
|---|---|
| Nom d'affichage / marque (prose) | **Bambuddy Pocket** (avec espace) |
| Dépôt GitHub | `clabeuhtegrite/bambuddy-pocket` |
| Bundle ID (provisoire) | `app.bambuddy.pocket` (reverse-DNS à ajuster sur un domaine possédé) |
| Cible/scheme Xcode, identifiants de code | `BambuddyPocket` (sans espace) |
| Paquet SPM / modules | `BambuddyPocketKit` → `BambuddyPocketDomain`, `…Networking`, `…DesignSystem` |
| Label launchd superviseur | `com.bambuddypocket.supervisor` |

## Conséquences & risques

- ⚠️ **Risque de marque** : « Bambuddy » est le nom du projet amont (et évoque « Bambu Lab »).
  Utiliser « Bambuddy » dans le nom d'une app publique **expose à un conflit de marque**. Le
  risque a été **signalé et accepté** par le titulaire du projet.
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
