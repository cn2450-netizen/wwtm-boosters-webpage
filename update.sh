#!/bin/bash
# WWT Music Club — Update Script
# Run on your server to update the app without losing data
# Usage: sudo bash update.sh /path/to/new/wwtmc

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  WWT Music Club — Update Script${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ This script must be run as root (use: sudo bash update.sh)${NC}"
   exit 1
fi

if [ -z "$1" ]; then
  echo -e "${RED}✗ Usage: sudo bash update.sh /path/to/new/wwtmc${NC}"
  exit 1
fi

SOURCE_DIR="$1"
INSTALL_DIR="/var/www/wwtmc"

if [ ! -f "$SOURCE_DIR/server.js" ]; then
  echo -e "${RED}✗ $SOURCE_DIR/server.js not found${NC}"
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
cp -r "$SOURCE_DIR/public/" "$INSTALL_DIR/public/"
echo -e "${GREEN}✓${NC} Files updated"

# Reinstall npm dependencies
echo -e "${GREEN}[4/4]${NC} Updating npm dependencies..."
cd "$INSTALL_DIR"
npm install --omit=dev > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Dependencies updated"

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
