#!/bin/bash
# WWT Music Club — Linux Installation Script
# Run: sudo bash install.sh <source>
#
# <source> can be:
#   - /path/to/local/wwtmc (local directory)
#   - https://github.com/user/repo.git (GitHub repo URL)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  WWT Music Club — Installation Script${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ This script must be run as root (use: sudo bash install.sh <source>)${NC}"
   exit 1
fi

# Check for source argument
if [ -z "$1" ]; then
  echo -e "${RED}✗ Usage: sudo bash install.sh <source>${NC}"
  echo ""
  echo "Examples:"
  echo "  # From local directory:"
  echo "  sudo bash install.sh /tmp/wwtmc"
  echo ""
  echo "  # From GitHub repository:"
  echo "  sudo bash install.sh https://github.com/cn2450-netizen/wwtm-boosters-webpage.git"
  exit 1
fi

SOURCE_INPUT="$1"
INSTALL_DIR="/var/www/wwtmc"

# Detect if source is a git URL or local directory
if [[ "$SOURCE_INPUT" == http* ]] || [[ "$SOURCE_INPUT" == git@* ]]; then
  # It's a git URL — clone it
  echo -e "${YELLOW}→${NC} Detected Git repository"
  echo -e "${YELLOW}→${NC} Cloning from: $SOURCE_INPUT"
  SOURCE_DIR="/tmp/wwtmc-install-$$"
  mkdir -p "$SOURCE_DIR"
  git clone --quiet --depth 1 "$SOURCE_INPUT" "$SOURCE_DIR" 2>&1 || {
    echo -e "${RED}✗ Failed to clone repository${NC}"
    rm -rf "$SOURCE_DIR"
    exit 1
  }
else
  # It's a local path
  SOURCE_DIR="$SOURCE_INPUT"
fi

if [ ! -f "$SOURCE_DIR/server.js" ]; then
  echo -e "${RED}✗ $SOURCE_DIR/server.js not found${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}→${NC} Source: $SOURCE_DIR"
echo -e "${YELLOW}→${NC} Install to: $INSTALL_DIR"
echo ""

# Step 1: Update system
echo -e "${GREEN}[1/8]${NC} Updating package manager..."
apt-get update -qq

# Step 2: Install Node.js 20.x
echo -e "${GREEN}[2/8]${NC} Installing Node.js 20.x..."
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
  apt-get install -y nodejs > /dev/null 2>&1
fi
NODE_VERSION=$(node -v)
echo -e "${GREEN}✓${NC} Node.js $NODE_VERSION installed"

# Step 3: Create install directory
echo -e "${GREEN}[3/8]${NC} Creating installation directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/public/uploads"
echo -e "${GREEN}✓${NC} Directories created"

# Step 4: Copy files
echo -e "${GREEN}[4/8]${NC} Copying application files..."
cp "$SOURCE_DIR/server.js" "$INSTALL_DIR/"
cp "$SOURCE_DIR/package.json" "$INSTALL_DIR/"
cp -r "$SOURCE_DIR/public/." "$INSTALL_DIR/public/"
if [ ! -f "$INSTALL_DIR/public/index.html" ]; then
  echo -e "${RED}✗ index.html was not copied — aborting${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} Files copied"

# Step 5: Install npm dependencies
echo -e "${GREEN}[5/8]${NC} Installing npm dependencies..."
cd "$INSTALL_DIR"
npm install --omit=dev > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Dependencies installed"

# Step 6: Set permissions
echo -e "${GREEN}[6/8]${NC} Setting file permissions..."
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 775 "$INSTALL_DIR/data"
chmod -R 775 "$INSTALL_DIR/public/uploads"
echo -e "${GREEN}✓${NC} Permissions set"

# Step 7: Copy and set up systemd service
echo -e "${GREEN}[7/8]${NC} Setting up systemd service..."
if [ -f "$SOURCE_DIR/wwtmc.service" ]; then
  cp "$SOURCE_DIR/wwtmc.service" /etc/systemd/system/

  # Generate a random session secret
  SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
  sed -i "s/change-this-to-a-long-random-secret/$SESSION_SECRET/g" /etc/systemd/system/wwtmc.service

  systemctl daemon-reload
  systemctl enable wwtmc > /dev/null 2>&1
  systemctl start wwtmc
  echo -e "${GREEN}✓${NC} Service installed and started"
else
  echo -e "${YELLOW}⚠${NC} wwtmc.service not found (systemd setup skipped)"
fi

# Step 8: Optional Nginx setup
echo -e "${GREEN}[8/8]${NC} Nginx setup..."
if [ -f "$SOURCE_DIR/nginx.conf" ]; then
  read -p "Install Nginx reverse proxy? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt-get install -y nginx > /dev/null 2>&1
    cp "$SOURCE_DIR/nginx.conf" /etc/nginx/sites-available/wwtmc

    read -p "Enter your domain (e.g. wwtmusic.club): " DOMAIN
    if [ ! -z "$DOMAIN" ]; then
      sed -i "s/yourdomain.com/$DOMAIN/g" /etc/nginx/sites-available/wwtmc
    fi

    ln -sf /etc/nginx/sites-available/wwtmc /etc/nginx/sites-enabled/wwtmc
    nginx -t > /dev/null 2>&1 && systemctl reload nginx
    echo -e "${GREEN}✓${NC} Nginx configured"
  else
    echo -e "${YELLOW}→${NC} Nginx setup skipped"
  fi
else
  echo -e "${YELLOW}⚠${NC} nginx.conf not found (Nginx setup skipped)"
fi

# Cleanup temp directory if we cloned from git
if [[ "$SOURCE_INPUT" == http* ]] || [[ "$SOURCE_INPUT" == git@* ]]; then
  rm -rf "$SOURCE_DIR"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "The application is installed at: ${YELLOW}$INSTALL_DIR${NC}"
echo ""
echo -e "Access the site:"
if systemctl is-active --quiet wwtmc; then
  echo -e "  • Local (port 3000):    ${YELLOW}http://localhost:3000${NC}"
  if [ ! -z "$DOMAIN" ] && systemctl is-active --quiet nginx; then
    echo -e "  • Via Nginx/domain:     ${YELLOW}http://$DOMAIN${NC}"
  fi
fi
echo ""
echo -e "Useful commands:"
echo -e "  • Start service:        ${YELLOW}sudo systemctl start wwtmc${NC}"
echo -e "  • Stop service:         ${YELLOW}sudo systemctl stop wwtmc${NC}"
echo -e "  • View logs:            ${YELLOW}sudo journalctl -u wwtmc -f${NC}"
echo -e "  • Restart service:      ${YELLOW}sudo systemctl restart wwtmc${NC}"
echo -e "  • Check status:         ${YELLOW}sudo systemctl status wwtmc${NC}"
echo ""
echo -e "Default password: ${YELLOW}admin${NC} (change on first login)"
echo ""
