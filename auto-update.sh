#!/bin/bash
# WWT Music Club — Auto-Update Script
# Runs in background; periodically checks for updates and applies them
#
# Usage:
#   - Manual run: bash auto-update.sh
#   - Background: nohup bash auto-update.sh &
#   - Cron job:   0 */4 * * * bash /var/www/wwtmc/auto-update.sh (every 4 hours)
#   - Systemd:    See auto-update.timer

set -e

# Configuration
INSTALL_DIR="/var/www/wwtmc"
SOURCE_REPO="${SOURCE_REPO:-}"  # Git repo URL (optional)
SOURCE_DIR="${SOURCE_DIR:-}"    # Local directory to check (optional)
LOG_FILE="/var/log/wwtmc-auto-update.log"
CHECK_INTERVAL="${CHECK_INTERVAL:-3600}"  # 1 hour default
MAX_LOG_SIZE=10485760  # 10 MB

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
  local level="$1"
  shift
  local msg="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

# Rotate log if it gets too big
rotate_log() {
  if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
    mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d_%H%M%S)"
    log "INFO" "Log rotated"
  fi
}

# Check if running as root (required for systemctl)
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log "ERROR" "This script must be run as root (or via systemd)"
    exit 1
  fi
}

# Fetch updates from git repo
fetch_from_git() {
  if [ -z "$SOURCE_REPO" ]; then
    return 1
  fi

  log "INFO" "Checking git repository: $SOURCE_REPO"
  local temp_dir="/tmp/wwtmc-update-$$"
  mkdir -p "$temp_dir"

  if git clone --quiet --depth 1 "$SOURCE_REPO" "$temp_dir" 2>&1; then
    if [ -f "$temp_dir/server.js" ]; then
      log "INFO" "Git repository cloned successfully"
      bash "$INSTALL_DIR/update.sh" "$temp_dir"
      rm -rf "$temp_dir"
      return 0
    else
      log "ERROR" "server.js not found in cloned repository"
      rm -rf "$temp_dir"
      return 1
    fi
  else
    log "ERROR" "Failed to clone git repository"
    rm -rf "$temp_dir"
    return 1
  fi
}

# Check local source directory for changes
check_local_source() {
  if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    return 1
  fi

  if [ ! -f "$SOURCE_DIR/server.js" ]; then
    log "ERROR" "server.js not found in SOURCE_DIR: $SOURCE_DIR"
    return 1
  fi

  log "INFO" "Checking local source: $SOURCE_DIR"

  # Compare modification times
  local source_time=$(stat -f%m "$SOURCE_DIR/server.js" 2>/dev/null || stat -c%Y "$SOURCE_DIR/server.js")
  local installed_time=$(stat -f%m "$INSTALL_DIR/server.js" 2>/dev/null || stat -c%Y "$INSTALL_DIR/server.js")

  if [ "$source_time" -gt "$installed_time" ]; then
    log "INFO" "Updates detected in source directory"
    bash "$INSTALL_DIR/update.sh" "$SOURCE_DIR"
    return 0
  else
    log "INFO" "No updates available"
    return 1
  fi
}

# Main loop
main() {
  log "INFO" "━━━ WWT Music Club Auto-Update Service Started ━━━"
  log "INFO" "Install dir: $INSTALL_DIR"
  log "INFO" "Check interval: ${CHECK_INTERVAL}s"
  [ ! -z "$SOURCE_REPO" ] && log "INFO" "Git repo: $SOURCE_REPO"
  [ ! -z "$SOURCE_DIR" ] && log "INFO" "Local source: $SOURCE_DIR"

  # Create log file if it doesn't exist
  touch "$LOG_FILE"

  # If running as a one-time check (not background loop)
  if [ "$1" = "once" ]; then
    log "INFO" "Running one-time check..."
    rotate_log

    if [ ! -z "$SOURCE_REPO" ]; then
      fetch_from_git && log "INFO" "Update completed from git" || log "WARN" "No updates from git"
    elif [ ! -z "$SOURCE_DIR" ]; then
      check_local_source && log "INFO" "Update completed from local source" || true
    else
      log "ERROR" "No SOURCE_REPO or SOURCE_DIR configured"
      return 1
    fi
    return 0
  fi

  # Continuous background loop
  while true; do
    rotate_log

    if [ ! -z "$SOURCE_REPO" ]; then
      fetch_from_git && log "INFO" "✓ Update completed from git" || log "WARN" "No updates available from git"
    elif [ ! -z "$SOURCE_DIR" ]; then
      check_local_source || true
    else
      log "ERROR" "No SOURCE_REPO or SOURCE_DIR configured. Exiting."
      log "INFO" "Set SOURCE_REPO or SOURCE_DIR environment variable"
      exit 1
    fi

    log "INFO" "Sleeping for ${CHECK_INTERVAL}s..."
    sleep "$CHECK_INTERVAL"
  done
}

# Entry point
if [ -z "$SOURCE_REPO" ] && [ -z "$SOURCE_DIR" ]; then
  echo "Usage:"
  echo "  SOURCE_REPO='https://github.com/user/repo.git' bash auto-update.sh"
  echo "  SOURCE_DIR='/path/to/code' bash auto-update.sh"
  echo ""
  echo "Environment variables:"
  echo "  SOURCE_REPO    — Git repository URL"
  echo "  SOURCE_DIR     — Local directory to monitor"
  echo "  CHECK_INTERVAL — Seconds between checks (default: 3600)"
  echo ""
  echo "Examples:"
  echo "  # Check git repo every 2 hours"
  echo "  SOURCE_REPO='https://github.com/user/wwtmc.git' CHECK_INTERVAL=7200 nohup bash auto-update.sh &"
  echo ""
  echo "  # Check local dir every 30 minutes"
  echo "  SOURCE_DIR='/mnt/updates' CHECK_INTERVAL=1800 nohup bash auto-update.sh &"
  echo ""
  echo "  # One-time check"
  echo "  SOURCE_DIR='/mnt/updates' bash auto-update.sh once"
  exit 1
fi

check_root
main "$@"
