#!/usr/bin/env bash
#
# notify.sh — envoie un message hors-bande à l'utilisateur (pour signaler un VRAI blocage,
# une fin de quota, ou un échec) pendant les exécutions autonomes/headless.
#
# Usage : notify.sh "message" ["titre"]
#
# Configuration via scripts/notify/notify.env (ignoré par git) ou variables d'env :
#   NOTIFY_METHOD = ntfy (défaut) | telegram
#   ntfy :     NTFY_TOPIC (requis), NTFY_SERVER (défaut https://ntfy.sh), NTFY_PRIORITY
#   telegram : TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
#
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/notify.env" ] && . "$SCRIPT_DIR/notify.env"

MESSAGE="${1:-(message vide)}"
TITLE="${2:-Bambuddy Pocket}"          # garder ASCII (en-tête HTTP)
METHOD="${NOTIFY_METHOD:-ntfy}"

case "$METHOD" in
  ntfy)
    SERVER="${NTFY_SERVER:-https://ntfy.sh}"
    if [ -z "${NTFY_TOPIC:-}" ]; then
      echo "notify: NTFY_TOPIC non défini (voir notify.env)" >&2; exit 2
    fi
    if curl -fsS --max-time 20 \
        -H "Title: $TITLE" \
        -H "Priority: ${NTFY_PRIORITY:-default}" \
        -H "Tags: construction" \
        -d "$MESSAGE" "$SERVER/$NTFY_TOPIC" >/dev/null; then
      echo "notify: envoyé via ntfy ($SERVER/$NTFY_TOPIC)"
    else
      echo "notify: échec ntfy" >&2; exit 1
    fi
    ;;
  telegram)
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
      echo "notify: config telegram incomplète (TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID)" >&2; exit 2
    fi
    if curl -fsS --max-time 20 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${TITLE} — ${MESSAGE}" >/dev/null; then
      echo "notify: envoyé via telegram"
    else
      echo "notify: échec telegram" >&2; exit 1
    fi
    ;;
  *)
    echo "notify: NOTIFY_METHOD inconnu '$METHOD' (attendu: ntfy|telegram)" >&2; exit 2
    ;;
esac
