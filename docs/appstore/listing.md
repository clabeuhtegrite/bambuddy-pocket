# Fiche App Store — BamPocket v0.1

> Prêt à coller dans **App Store Connect**. Rien n'est soumis automatiquement. Les URL sont des
> **placeholders** à remplacer avant publication. Données de captures 100 % synthétiques (mode démo).

---

## Identité

| Champ | Valeur |
|---|---|
| **Nom de l'app** | BamPocket |
| **Sous-titre (FR)** | Pilotez vos imprimantes 3D Bambu |
| **Sous-titre (EN)** | Control your Bambu 3D printers |
| **Catégorie principale** | Utilitaires |
| **Catégorie secondaire** | Productivité |
| **Bundle ID** | com.bampocket.app |
| **Classification d'âge** | **4+** (voir justification) |

Le nom « BamPocket » est juridiquement clear (la marque « Bambuddy » n'est pas utilisée comme nom
public). BamPocket est un client tiers **non affilié** à Bambu Lab ; à mentionner dans la description.

---

## Description — Français

**BamPocket met votre atelier d'impression 3D dans votre poche.**

Client mobile pour serveur Bambuddy, BamPocket vous donne une vue temps réel sur toutes vos
imprimantes Bambu Lab, où que vous soyez.

• **Tableau de bord en direct** — état de chaque imprimante, impression en cours, températures
  buse / plateau / caisson, progression et temps restant, d'un coup d'œil.
• **Détail imprimante** — cartes de température, suivi par couche, unités AMS et bobines (couleur,
  matière, niveau restant), erreurs HMS, ventilateurs et profils de calibration.
• **Archives d'impression** — historique complet : durée, filament, coût et énergie, vignettes,
  favoris, tags et notes. Recherche serveur intégrée.
• **Aperçu 3D** — visualisez le parcours d'outil G-code ou le modèle 3D directement dans l'app.
• **File d'attente** — suivez et réordonnez vos travaux, planifiez des impressions, gérez les lots.
• **Multi-serveurs et multi-imprimantes** — basculez entre ateliers en un geste.
• **Mode sombre, Dynamic Type, VoiceOver** — soigné et accessible.
• **Confidentialité** — vos identifiants restent sur votre appareil (Trousseau iOS). Aucune
  télémétrie, aucune publicité.

BamPocket est une application **tierce** et **non affiliée** à Bambu Lab. Elle nécessite un serveur
Bambuddy accessible. Logiciel libre.

## Description — English

**BamPocket puts your 3D printing workshop in your pocket.**

A mobile client for your Bambuddy server, BamPocket gives you a real-time view of every Bambu Lab
printer, wherever you are.

• **Live dashboard** — printer state, active print, nozzle / bed / chamber temperatures, progress
  and time remaining, at a glance.
• **Printer detail** — temperature cards, per-layer tracking, AMS units and spools (color, material,
  remaining level), HMS errors, fans and calibration profiles.
• **Print archive** — full history: duration, filament, cost and energy, thumbnails, favorites,
  tags and notes, with server-side search.
• **3D preview** — view the G-code toolpath or 3D model right in the app.
• **Print queue** — track and reorder jobs, schedule prints, manage batches.
• **Multi-server and multi-printer** — switch between workshops in one tap.
• **Dark mode, Dynamic Type, VoiceOver** — polished and accessible.
• **Privacy** — your credentials stay on your device (iOS Keychain). No telemetry, no ads.

BamPocket is a **third-party** app and is **not affiliated** with Bambu Lab. It requires an
accessible Bambuddy server. Open-source software.

---

## Mots-clés (≤ 100 caractères)

**FR** : `imprimante 3D,Bambu,impression,AMS,filament,atelier,maker,3D,monitoring,file,archive`

**EN** : `3d printer,Bambu,printing,AMS,filament,workshop,maker,3D,monitor,queue,archive,bambuddy`

---

## Classification d'âge — justification

**4+ proposé.** L'app est un outil de **supervision et contrôle d'imprimantes 3D** :
- aucun contenu généré par utilisateur public, aucun chat, aucun réseau social ;
- aucune violence, contenu sexuel, jeux d'argent, ni substances ;
- aucun navigateur web non restreint (le viewer 3D est un canvas local hors-ligne) ;
- aucune localisation, aucune fonctionnalité sensible.

Dans le questionnaire App Store Connect, répondre **None / Aucun** à toutes les catégories de
contenu → note **4+**.

---

## Notes de version — v0.1

**FR**
```
Première version de BamPocket.
• Tableau de bord temps réel multi-imprimantes Bambu Lab (via serveur Bambuddy).
• Détail imprimante : températures, couches, AMS, erreurs HMS.
• Archives d'impression avec recherche, favoris, coût et énergie.
• Aperçu 3D (parcours G-code et modèles).
• File d'attente : suivi, réordonnancement, planification.
• Multi-serveurs, mode sombre, accessibilité (Dynamic Type, VoiceOver).
```

**EN**
```
First release of BamPocket.
• Real-time dashboard for multiple Bambu Lab printers (via a Bambuddy server).
• Printer detail: temperatures, layers, AMS, HMS errors.
• Print archive with search, favorites, cost and energy.
• 3D preview (G-code toolpaths and models).
• Print queue: tracking, reordering, scheduling.
• Multi-server, dark mode, accessibility (Dynamic Type, VoiceOver).
```

---

## URL & métadonnées (placeholders — à remplacer)

| Champ | Valeur |
|---|---|
| **URL d'assistance** | `https://bampocket.example.com/support` |
| **URL marketing** | `https://bampocket.example.com` |
| **URL politique de confidentialité** | `https://bampocket.example.com/privacy` |
| **Copyright** | `© 2026 BamPocket` |
| **Coordonnées dev** | à compléter dans App Store Connect |

### Confidentialité (App Privacy)
- **Données collectées : aucune.** Pas de tracking, pas d'analytics, pas de tiers publicitaires.
- Les identifiants de serveur sont stockés **localement** (Trousseau iOS) et ne quittent jamais
  l'appareil sauf vers le serveur Bambuddy que l'utilisateur configure lui-même.
- Renseigner « Data Not Collected » dans le questionnaire App Privacy.

### Chiffrement
- `ITSAppUsesNonExemptEncryption = false` (déjà déclaré dans `Info.plist`) → pas de documentation
  export supplémentaire.

---

## Captures d'écran

Résolution **iPhone 6.9"** : **1320 × 2868** (iPhone 17 Pro Max). App Store Connect accepte ce
jeu pour toutes les tailles supérieures ; un jeu 6.5"/6.7" distinct est optionnel pour v0.1.

Emplacement : `docs/appstore/screenshots/<langue>/` (génération : `docs/appstore/screenshots/README.md`).

| Ordre | Fichier | Écran |
|---|---|---|
| 1 | `01-accueil.png` | Accueil — tableau de bord temps réel |
| 2 | `02-detail-imprimante.png` | Détail imprimante — températures + AMS |
| 3 | `03-archives.png` | Archives d'impression |
| 4 | `04-viewer-3d.png` | Aperçu 3D — parcours G-code |
| 5 | `05-file-attente.png` | File d'attente |

Langues fournies : **fr** et **en** (jeux identiques, UI localisée).
