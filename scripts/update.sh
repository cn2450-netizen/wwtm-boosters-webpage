#!/bin/bash
# WWT Music Club — Update Script
# Run on your server to update the app without losing data
#
# Usage: sudo bash scripts/update.sh [source]
#
# [source] is optional and can be:
#   - omitted                        → clones DEFAULT_REPO
#   - https://github.com/user/repo.git (or git@...)  → clones that repo
#   - /path/to/local/wwtmc           → uses that local directory as-is

set -e

DEFAULT_REPO="https://github.com/cn2450-netizen/wwtm-boosters-webpage.git"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  WWT Music Club — Update Script${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ This script must be run as root (use: sudo bash scripts/update.sh)${NC}"
   exit 1
fi

SOURCE_INPUT="${1:-$DEFAULT_REPO}"
INSTALL_DIR="/opt/wwtmc"
CLONED_DIR=""

# Detect if source is a git URL or local directory
if [[ "$SOURCE_INPUT" == http* ]] || [[ "$SOURCE_INPUT" == git@* ]]; then
  # Prune leftover temp clones from any previous run that failed before its
  # own cleanup step ran (e.g. /tmp/wwtmc-update-12345 from a crashed update).
  find /tmp -maxdepth 1 -name 'wwtmc-update-*' -exec rm -rf {} + 2>/dev/null || true

  echo -e "${YELLOW}→${NC} Cloning from: $SOURCE_INPUT"
  SOURCE_DIR="/tmp/wwtmc-update-$$"
  git clone --quiet --depth 1 "$SOURCE_INPUT" "$SOURCE_DIR" || {
    echo -e "${RED}✗ Failed to clone repository${NC}"
    rm -rf "$SOURCE_DIR"
    exit 1
  }
  CLONED_DIR="$SOURCE_DIR"
else
  SOURCE_DIR="$SOURCE_INPUT"
fi

if [ ! -f "$SOURCE_DIR/server.js" ]; then
  echo -e "${RED}✗ $SOURCE_DIR/server.js not found${NC}"
  [ -n "$CLONED_DIR" ] && rm -rf "$CLONED_DIR"
  exit 1
fi

echo ""
echo -e "${YELLOW}→${NC} Updating from: $SOURCE_DIR"
echo -e "${YELLOW}→${NC} Installing to: $INSTALL_DIR"
echo ""

# Backup state.json
echo -e "${GREEN}[1/4]${NC} Backing up current state..."
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
cp "$INSTALL_DIR/data/state.json" "$INSTALL_DIR/data/state.json.backup.$BACKUP_TIME"
echo -e "${GREEN}✓${NC} Backup saved to: state.json.backup.$BACKUP_TIME"

# Stop service
echo -e "${GREEN}[2/4]${NC} Stopping service..."
systemctl stop wwtmc
echo -e "${GREEN}✓${NC} Service stopped"

# Copy files (except data/)
echo -e "${GREEN}[3/4]${NC} Updating application files..."
cp "$SOURCE_DIR/server.js" "$INSTALL_DIR/"
cp "$SOURCE_DIR/package.json" "$INSTALL_DIR/"
cp "$SOURCE_DIR/package-lock.json" "$INSTALL_DIR/" 2>/dev/null || true
cp -r "$SOURCE_DIR/public/." "$INSTALL_DIR/public/"
mkdir -p "$INSTALL_DIR/scripts"
# update.sh/auto-update.sh may be the very script (or the parent script)
# currently executing this update — copy-then-rename instead of overwriting
# in place, so a live interpreter reading the old inode isn't corrupted mid-run.
for f in update.sh auto-update.sh start.sh stop.sh; do
  cp "$SOURCE_DIR/scripts/$f" "$INSTALL_DIR/scripts/$f.new"
  mv "$INSTALL_DIR/scripts/$f.new" "$INSTALL_DIR/scripts/$f"
done
chmod +x "$INSTALL_DIR/scripts/"*.sh
echo -e "${GREEN}✓${NC} Files updated"

# Reinstall npm dependencies
echo -e "${GREEN}[4/4]${NC} Updating npm dependencies..."
cd "$INSTALL_DIR"
npm install --omit=dev > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Dependencies updated"

# Clean up temp clone
[ -n "$CLONED_DIR" ] && rm -rf "$CLONED_DIR"

# Restart service
systemctl start wwtmc
sleep 2

if systemctl is-active --quiet wwtmc; then
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  ✓ Update Complete!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "Service restarted. Your data is safe."
  echo -e "Backup: ${YELLOW}$INSTALL_DIR/data/state.json.backup.$BACKUP_TIME${NC}"
  echo ""
else
  echo ""
  echo -e "${RED}✗ Service failed to start!${NC}"
  echo -e "Check logs: ${YELLOW}sudo journalctl -u wwtmc -n 30${NC}"
  exit 1
fi
