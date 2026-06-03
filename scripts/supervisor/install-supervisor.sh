#!/usr/bin/env bash
#
# install-supervisor.sh — rend le template launchd avec les chemins absolus de cette machine,
# l'installe dans ~/Library/LaunchAgents et le charge.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/com.bambuddypocket.supervisor.plist.template"
WORKER="$SCRIPT_DIR/bambuddy-pocket-supervisor.sh"
LOG_DIR="$SCRIPT_DIR/logs"
LABEL="com.bambuddypocket.supervisor"
DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$LOG_DIR" "$HOME/Library/LaunchAgents"
chmod +x "$WORKER"

# PATH typique : homebrew (Apple Silicon + Intel) + emplacements claude + PATH courant.
RENDER_PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.claude/local:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
DEV_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SHELL_BIN="/bin/bash"

sed -e "s#__SHELL__#$SHELL_BIN#g" \
    -e "s#__SCRIPT__#$WORKER#g" \
    -e "s#__LOG__#$LOG_DIR#g" \
    -e "s#__PATH__#$RENDER_PATH#g" \
    -e "s#__DEVELOPER_DIR__#$DEV_DIR#g" \
    "$TEMPLATE" > "$DEST"

echo "Plist installé : $DEST"

# Recharger proprement (bootout puis bootstrap pour les macOS récents, avec repli load/unload)
UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM" "$DEST" 2>/dev/null || true
if launchctl bootstrap "gui/$UID_NUM" "$DEST" 2>/dev/null; then
  echo "Chargé via launchctl bootstrap."
else
  launchctl unload "$DEST" 2>/dev/null || true
  launchctl load "$DEST"
  echo "Chargé via launchctl load."
fi

echo "OK. Le superviseur s'exécutera au chargement puis toutes les 15 minutes."
echo "Logs : $LOG_DIR/"
echo "Déclencher maintenant : launchctl kickstart -k gui/$UID_NUM/$LABEL"
echo "Désinstaller : launchctl bootout gui/$UID_NUM \"$DEST\" && rm \"$DEST\""
