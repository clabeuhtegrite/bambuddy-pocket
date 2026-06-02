#!/usr/bin/env bash
#
# spoolside-supervisor.sh — relance Claude Code en mode headless pour faire avancer
# le projet Spoolside de façon autonome, avec retry/back-off sur erreur de quota.
#
# Conçu pour être déclenché toutes les heures par launchd (cf. README de ce dossier) ou cron.
# Il NE peut PAS « réveiller » une session interactive bloquée : il démarre une NOUVELLE
# exécution headless qui reprend l'état depuis PROGRESS.md.
#
# Variables d'environnement (optionnelles) :
#   CLAUDE_BIN        chemin du binaire claude (sinon : recherche dans le PATH/emplacements connus)
#   SPOOLSIDE_MODEL   modèle à utiliser (passe --model si défini)
#   MAX_RETRIES       tentatives en cas de quota (défaut 5)
#   BASE_BACKOFF      back-off initial en secondes (défaut 300 = 5 min ; doublé à chaque essai)
#   RUN_TIMEOUT       durée max d'une exécution claude en secondes (défaut 5400 = 90 min ; 0 = illimité)
#
set -uo pipefail

# --- Localisation du projet (ce script est dans <repo>/scripts/supervisor/) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOCK_DIR="$SCRIPT_DIR/.lock"
mkdir -p "$LOG_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/run-$TS.log"

MAX_RETRIES="${MAX_RETRIES:-5}"
BASE_BACKOFF="${BASE_BACKOFF:-300}"
RUN_TIMEOUT="${RUN_TIMEOUT:-5400}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# --- Verrou anti-chevauchement (mkdir est atomique) ---
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "Une exécution est déjà en cours (verrou $LOCK_DIR présent). Abandon."
  exit 0
fi
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# --- Résolution du binaire claude ---
resolve_claude() {
  if [ -n "${CLAUDE_BIN:-}" ] && [ -x "$CLAUDE_BIN" ]; then echo "$CLAUDE_BIN"; return; fi
  if command -v claude >/dev/null 2>&1; then command -v claude; return; fi
  for c in "$HOME/.claude/local/claude" "/opt/homebrew/bin/claude" "/usr/local/bin/claude" \
           "$HOME/.local/bin/claude" "$HOME/.bun/bin/claude" "$HOME/.npm-global/bin/claude"; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  return 1
}
CLAUDE="$(resolve_claude)" || { log "ERREUR : binaire 'claude' introuvable. Définir CLAUDE_BIN."; exit 1; }
log "Binaire claude : $CLAUDE"

# --- Détection de timeout dispo (coreutils) ---
TIMEOUT_BIN=""
if command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout";
elif command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"; fi

# --- Prompt de reprise ---
read -r -d '' PROMPT <<'EOF' || true
Tu es l'agent de développement autonome du projet Spoolside (client iOS open source pour le
serveur auto-hébergé Bambuddy). Tu tournes en mode non interactif, déclenché par un superviseur.

1. Lis PROGRESS.md et ROADMAP.md à la racine du dépôt, et les ADR dans docs/adr/.
2. Reprends à la « Prochaine action » de PROGRESS.md. Exécute la PROCHAINE tâche utile et
   atomique : implémente -> compile -> teste -> commit (Conventional Commits, sur une branche
   de feature) -> pousse -> ouvre/mets à jour la PR -> mets à jour PROGRESS.md.
3. Respecte strictement : ne JAMAIS modifier la config git globale ; ne JAMAIS commiter de
   secret ; build sans warning ; SwiftLint/SwiftFormat propres ; i18n FR/EN/ES/DE ; ADR à jour.
4. Pour les builds iOS : exporte DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer.
   L'instance Bambuddy de dev tourne en Docker sur http://localhost:8000 (la relancer au besoin
   depuis /Users/ad/bambuddy-upstream : `docker compose up -d`).
5. Si tu rencontres un VRAI point bloquant (décision utilisateur requise, ex. licence/viewer 3D),
   documente-le clairement dans PROGRESS.md (section « Décisions en attente ») et arrête-toi
   proprement sans bricoler de contournement risqué.
6. Termine toujours par : mettre à jour PROGRESS.md (fait/en cours/à faire + journal daté) et
   commiter cette mise à jour.

Avance d'un incrément utile et sûr, puis rends la main.
EOF

run_claude() {
  local out_file="$1"
  local -a cmd=("$CLAUDE" -p "$PROMPT" --dangerously-skip-permissions)
  [ -n "${SPOOLSIDE_MODEL:-}" ] && cmd+=(--model "$SPOOLSIDE_MODEL")
  if [ -n "$TIMEOUT_BIN" ] && [ "$RUN_TIMEOUT" != "0" ]; then
    "$TIMEOUT_BIN" "$RUN_TIMEOUT" "${cmd[@]}" >"$out_file" 2>&1
  else
    "${cmd[@]}" >"$out_file" 2>&1
  fi
}

is_quota_error() {
  # Heuristique : motifs de limite d'usage / surcharge dans la sortie
  grep -qiE 'usage limit|rate limit|quota|too many requests|overloaded|429|529|exceeded your|capacity' "$1"
}

cd "$PROJECT_DIR" || { log "ERREUR : cd $PROJECT_DIR a échoué."; exit 1; }
log "Démarrage superviseur dans $PROJECT_DIR"

attempt=0
backoff="$BASE_BACKOFF"
while :; do
  attempt=$((attempt + 1))
  OUT="$LOG_DIR/claude-$TS-try$attempt.out"
  log "Tentative $attempt/$MAX_RETRIES — exécution de claude (timeout=${RUN_TIMEOUT}s, bin=${TIMEOUT_BIN:-none})…"
  run_claude "$OUT"
  rc=$?
  # Joindre la sortie au log principal (tronquée)
  { echo "----- sortie claude (tentative $attempt, rc=$rc) -----"; tail -n 200 "$OUT"; echo "----- fin -----"; } >>"$LOG_FILE"

  if [ "$rc" -eq 0 ] && ! is_quota_error "$OUT"; then
    log "Succès (rc=0). Fin du superviseur."
    exit 0
  fi

  if is_quota_error "$OUT"; then
    log "Limite de quota détectée (rc=$rc)."
  else
    log "Échec non lié au quota (rc=$rc) — voir $OUT."
    # Échec « dur » : ne pas marteler ; laisser la prochaine planification réessayer.
    exit "$rc"
  fi

  if [ "$attempt" -ge "$MAX_RETRIES" ]; then
    log "Quota : $MAX_RETRIES tentatives épuisées. Abandon ; la prochaine planification réessaiera."
    exit 75   # EX_TEMPFAIL
  fi

  log "Back-off ${backoff}s avant nouvelle tentative…"
  sleep "$backoff"
  backoff=$((backoff * 2))
done
