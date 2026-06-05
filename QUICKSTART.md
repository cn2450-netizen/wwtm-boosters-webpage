# WWT Music Club — Quick Start Guide

## Installation (Linux/WSL)

### Prerequisites
- Ubuntu 20.04+ or Debian 11+ (or WSL with Ubuntu)
- Root or sudo access
- ~500MB free disk space

### One-Command Install
```bash
sudo bash install.sh /path/to/wwtmc
```

Replace `/path/to/wwtmc` with where your files are located.

**Example:**
```bash
sudo bash install.sh /tmp/wwtmc
```

The script will:
1. ✓ Install Node.js 20.x
2. ✓ Create `/var/www/wwtmc/` directory
3. ✓ Copy all files
4. ✓ Install npm dependencies
5. ✓ Set up permissions
6. ✓ Configure systemd service (auto-start on reboot)
7. ✓ Optionally install Nginx for domain/HTTPS

---

## Manual Installation (if you prefer)

```bash
# 1. Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Create directory and copy files
sudo mkdir -p /var/www/wwtmc
sudo cp -r wwtmc/* /var/www/wwtmc/

# 3. Set ownership
sudo chown -R www-data:www-data /var/www/wwtmc
sudo chmod -R 755 /var/www/wwtmc

# 4. Install dependencies
cd /var/www/wwtmc
sudo npm install --omit=dev

# 5. Start the server
sudo systemctl start wwtmc
# or manually:
node server.js
```

---

## First Use

1. **Access the site:** 
   - Local: `http://localhost:3000`
   - If using domain: `http://yourdomain.com`

2. **Login to Admin Panel:**
   - Click **⚙ Admin** button in nav
   - Password: `admin` (default)
   - You'll be forced to change it on first login

3. **Configure the site:**
   - Admin → **Content** tab: Edit club name, hero text, about section
   - Admin → **Gallery** tab: Upload images
   - Admin → **Events** tab: Add upcoming events
   - Admin → **Calendar** tab: Paste your Google Calendar iCal URL
   - Admin → **Board** tab: Add your board members with emails
   - Admin → **Documents** tab: Create a folder/file tree for resources

---

## Service Management

```bash
# Start service
sudo systemctl start wwtmc

# Stop service
sudo systemctl stop wwtmc

# Restart service
sudo systemctl restart wwtmc

# Check status
sudo systemctl status wwtmc

# View live logs
sudo journalctl -u wwtmc -f

# Disable auto-start (won't run on reboot)
sudo systemctl disable wwtmc

# Enable auto-start
sudo systemctl enable wwtmc
```

---

## Data & Backups

All site content is stored in JSON files:
- **State:** `/var/www/wwtmc/data/state.json` (all site content)
- **Auth:** `/var/www/wwtmc/data/auth.json` (password hash)
- **Uploads:** `/var/www/wwtmc/public/uploads/` (gallery images)

### Backup
```bash
# Quick backup
sudo cp /var/www/wwtmc/data/state.json ~/wwtmc-backup-$(date +%Y%m%d).json

# Or use the Admin panel:
# Admin → Settings → Export Data
```

---

## HTTPS / SSL (with Let's Encrypt)

If you installed Nginx:

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Certbot will auto-renew certificates. After installing HTTPS:

Edit `/var/www/wwtmc/server.js`, find the session cookie config, and change:
```javascript
secure: true,  // ← change from false to true
```

Then restart:
```bash
sudo systemctl restart wwtmc
```

---

## Troubleshooting

### Service won't start
```bash
sudo journalctl -u wwtmc -n 50  # View last 50 lines of logs
```

### Permission denied errors
```bash
sudo chown -R www-data:www-data /var/www/wwtmc
sudo chmod -R 775 /var/www/wwtmc/data
sudo chmod -R 775 /var/www/wwtmc/public/uploads
```

### Port 3000 already in use
```bash
sudo lsof -i :3000  # See what's using it
sudo systemctl stop wwtmc  # Stop the service
```

### Nginx not forwarding requests
```bash
sudo nginx -t  # Test config
sudo systemctl reload nginx  # Reload if OK
```

---

## Files & Structure

```
/var/www/wwtmc/
├── server.js              ← Express backend
├── package.json           ← Dependencies
├── package-lock.json
├── install.sh             ← This script
├── wwtmc.service          ← Systemd service
├── nginx.conf             ← Nginx config
├── data/
│   ├── state.json         ← ALL SITE CONTENT (auto-created)
│   └── auth.json          ← Password hash (auto-created)
└── public/
    ├── index.html         ← The website
    └── uploads/           ← Uploaded images
```

---

## Support

For issues, check:
1. Service logs: `sudo journalctl -u wwtmc -f`
2. Nginx logs: `sudo tail -f /var/log/nginx/error.log`
3. File permissions: `ls -la /var/www/wwtmc/`
4. Node version: `node -v` (should be v20.x)
