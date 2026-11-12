#!/usr/bin/env bash
# Removes FloatPlayer.app from ~/Applications.
#   --purge  also deletes settings and web data (cookies / YouTube sign-in).

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    -h|--help) echo "usage: $0 [--purge]"; exit 0 ;;
    *) die "bilinmeyen argüman: $arg" ;;
  esac
done

quit_app

if [[ -d "$INSTALLED_APP" ]]; then
  log "$INSTALLED_APP siliniyor"
  rm -rf "$INSTALLED_APP"
else
  warn "$INSTALLED_APP bulunamadı"
fi

if [[ "$PURGE" == 1 ]]; then
  log "ayarlar ve web verileri siliniyor"
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  rm -rf \
    "$HOME/Library/Preferences/$BUNDLE_ID.plist" \
    "$HOME/Library/WebKit/$BUNDLE_ID" \
    "$HOME/Library/Caches/$BUNDLE_ID" \
    "$HOME/Library/HTTPStorages/$BUNDLE_ID" \
    "$HOME/Library/HTTPStorages/$BUNDLE_ID.binarycookies" \
    "$HOME/Library/Cookies/$BUNDLE_ID.binarycookies" \
    "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
fi

log "kaldırıldı"
