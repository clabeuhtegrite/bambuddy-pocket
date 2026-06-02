# Superviseur externe (autonomie & résilience aux quotas)

Pourquoi : une session Claude Code interactive **ne peut pas se réveiller seule** après un
blocage (quota, fin de session). Ce superviseur **externe** relance périodiquement Claude en
mode **headless**, en lui demandant de reprendre le travail à partir de [`../../PROGRESS.md`](../../PROGRESS.md).

## Composants
- [`spoolside-supervisor.sh`](spoolside-supervisor.sh) — le worker : lance `claude -p …` en
  headless, détecte les erreurs de quota et **réessaie avec back-off exponentiel**, journalise.
- [`com.spoolside.supervisor.plist.template`](com.spoolside.supervisor.plist.template) — agent
  **launchd** (toutes les heures), avec placeholders.
- [`install-supervisor.sh`](install-supervisor.sh) — rend le template avec les chemins absolus
  de la machine et charge l'agent.
- `logs/` — journaux d'exécution (ignoré par git).

## Pré-requis
- CLI **Claude Code** installée et **authentifiée** sous ton compte (`claude` dans le PATH, ou
  exporter `CLAUDE_BIN`).
- Xcode présent ; `DEVELOPER_DIR` pointant sur Xcode (le template le règle).
- Le dépôt cloné en local avec l'identité git et `gh` déjà configurés.

## ⚠️ Avertissement de sécurité
Le worker lance Claude avec `--dangerously-skip-permissions` : en mode non interactif, les outils
(écritures fichier, `git`, `xcodebuild`, `docker`, réseau…) s'exécutent **sans confirmation**.
N'utilise ce superviseur que sur **cette machine de confiance** et **ce projet**. Tu peux
décharger l'agent quand tu travailles toi-même en interactif (voir « Désinstaller »).

## Installation (launchd, recommandé sur macOS)
```bash
cd "$(git rev-parse --show-toplevel)/scripts/supervisor"
./install-supervisor.sh
```
- S'exécute au chargement, puis **toutes les heures**.
- Déclencher immédiatement :
  `launchctl kickstart -k gui/$(id -u)/com.spoolside.supervisor`
- Suivre les logs : `tail -f logs/run-*.log`

## Désinstaller / mettre en pause
```bash
launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/com.spoolside.supervisor.plist"
rm "$HOME/Library/LaunchAgents/com.spoolside.supervisor.plist"
```

## Variante cron (si tu préfères)
```cron
# crontab -e — toutes les heures à la minute 7
7 * * * * /bin/bash "/CHEMIN/ABSOLU/scripts/supervisor/spoolside-supervisor.sh" >> "/CHEMIN/ABSOLU/scripts/supervisor/logs/cron.log" 2>&1
```
> Pense à fournir un `PATH` complet dans l'environnement cron (cron a un PATH minimal),
> ou exporte `CLAUDE_BIN` et `DEVELOPER_DIR` en tête de la ligne/du crontab.

## Réglages (variables d'environnement)
| Variable | Défaut | Rôle |
|---|---|---|
| `CLAUDE_BIN` | (auto) | Chemin du binaire `claude`. |
| `SPOOLSIDE_MODEL` | (défaut CLI) | `--model` à utiliser. |
| `MAX_RETRIES` | `5` | Tentatives sur quota dans une exécution. |
| `BASE_BACKOFF` | `300` | Back-off initial (s), doublé à chaque essai. |
| `RUN_TIMEOUT` | `5400` | Durée max d'une exécution (s) ; `0` = illimité (nécessite `timeout`/`gtimeout`). |

## Test manuel (sans launchd)
```bash
./spoolside-supervisor.sh ; echo "rc=$?"
cat logs/run-*.log
```
Codes de sortie : `0` succès · `75` quota épuisé (réessai à la prochaine planification) ·
autre = échec dur (voir logs).
