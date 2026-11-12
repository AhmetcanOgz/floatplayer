#!/usr/bin/env bash
# Builds FloatPlayer.app, installs it into ~/Applications and launches it.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

bash "$SCRIPT_DIR/make-app.sh"

quit_app

log "$INSTALLED_APP konumuna kuruluyor"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
ditto "$APP_BUNDLE" "$INSTALLED_APP"

log "başlatılıyor"
open "$INSTALLED_APP"
log "kuruldu — menü çubuğundaki simgeyi ya da ⌘L'yi kullanın"
