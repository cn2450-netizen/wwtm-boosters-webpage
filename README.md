# WWT Music Club — Deployment Guide

## ⚡ Quick Start

**Fastest way to deploy — directly from GitHub:**

```bash
sudo bash install.sh https://github.com/cn2450-netizen/wwtm-boosters-webpage.git
```

That's it! Everything is set up. See [**QUICKSTART.md**](QUICKSTART.md) for full details.

**Or from a local directory:**
```bash
sudo bash install.sh /path/to/wwtmc
```

---

## What You Get

- ✅ **Full website** — hero, gallery, events, board, documents, contact
- ✅ **Admin panel** — manage everything from the browser
- ✅ **Google Calendar sync** — auto-pull next 6 upcoming events
- ✅ **Board members** — customizable roster with email buttons
- ✅ **Document library** — folder/file tree for resources, links
- ✅ **Image gallery** — upload images, managed via admin
- ✅ **Auto-start service** — runs on reboot, managed by systemd
- ✅ **Nginx-ready** — optional reverse proxy with HTTPS/Let's Encrypt

---

## Requirements

- **OS:** Ubuntu 20.04+, Debian 11+, or any modern Linux (incl. WSL)
- **Access:** Root or sudo
- **Disk:** ~500MB free space
- **Network:** Port 3000 (or 80/443 if using Nginx)

---

## Installation

### Option 1: Automated (Recommended)

```bash
sudo bash install.sh /path/to/wwtmc
```

The script will:
1. Install Node.js 20.x
2. Create directories and copy files
3. Install npm dependencies
4. Set up systemd service
5. **Optionally** install Nginx with your domain

**Example:**
```bash
# Copy files to server first:
scp -r wwtmc/ user@your-server:/tmp/wwtmc

# Then SSH in and run:
sudo bash install.sh /tmp/wwtmc
```

### Option 2: Manual Installation

See the detailed steps below.

---

## Manual Installation (Step by Step)

### Step 1: Install Node.js 20.x

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v  # verify: should be v20.x.x
```

### Step 2: Create directories and copy files

```bash
sudo mkdir -p /var/www/wwtmc
sudo cp -r /tmp/wwtmc/* /var/www/wwtmc/
```

### Step 3: Install npm dependencies

```bash
cd /var/www/wwtmc
sudo npm install --omit=dev
```

### Step 4: Set permissions

```bash
sudo chown -R www-data:www-data /var/www/wwtmc
sudo chmod -R 755 /var/www/wwtmc
```

### Step 5: Set up the systemd service

```bash
# Copy the service file
sudo cp /var/www/wwtmc/wwtmc.service /etc/systemd/system/

# Generate a random session secret
SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# Edit the service file and update the SECRET
sudo sed -i "s/change-this-to-a-long-random-secret/$SESSION_SECRET/g" /etc/systemd/system/wwtmc.service

# Reload systemd and start the service
sudo systemctl daemon-reload
sudo systemctl enable wwtmc   # auto-start on reboot
sudo systemctl start wwtmc
sudo systemctl status wwtmc
```

### Step 6: Verify it's running

```bash
# Check service status
sudo systemctl status wwtmc

# View live logs
sudo journalctl -u wwtmc -f

# Test the site
curl http://localhost:3000
```

The site is now live at **http://your-server-ip:3000**

### Step 7: (Optional) Set up Nginx

For a cleaner URL and HTTPS support:

```bash
sudo apt install -y nginx

# Copy and customize the config
sudo cp /var/www/wwtmc/nginx.conf /etc/nginx/sites-available/wwtmc
sudo nano /etc/nginx/sites-available/wwtmc
# Change "yourdomain.com" to your actual domain

# Enable the site
sudo ln -s /etc/nginx/sites-available/wwtmc /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 8: (Optional) Add HTTPS with Let's Encrypt

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Certbot will auto-configure HTTPS and renew certificates.

---

## First Login

1. Visit your site and click **⚙ Admin** in the navbar
2. Password: `admin` (default)
3. **You'll be forced to change it on first login** — do this!
4. Now manage your site:
   - **Content** — edit hero text, about, club name, etc.
   - **Gallery** — upload images
   - **Events** — add/edit events (or use Calendar sync)
   - **Calendar** — paste Google Calendar iCal URL for auto-sync
   - **Board** — add team members with contact emails
   - **Documents** — create a folder/file tree for resources
   - **Settings** — backup, reset, change password

---

## Updating the Application

When you have new code, use the update script to apply it without losing data:

```bash
sudo bash update.sh /path/to/new/wwtmc
```

It will:
1. Backup your current data
2. Update all application files
3. Update npm dependencies
4. Restart the service

Data in `state.json` is **never** touched.

---

## Service Management

```bash
# Start
sudo systemctl start wwtmc

# Stop
sudo systemctl stop wwtmc

# Restart (after code changes)
sudo systemctl restart wwtmc

# View status
sudo systemctl status wwtmc

# View live logs
sudo journalctl -u wwtmc -f

# View last 50 log lines
sudo journalctl -u wwtmc -n 50

# Disable auto-start on reboot
sudo systemctl disable wwtmc

# Enable auto-start on reboot
sudo systemctl enable wwtmc
```

---

## Data & Backups

### Where Your Data Lives

```
/var/www/wwtmc/
├── data/
│   ├── state.json    ← ALL SITE CONTENT (edit times, images, text, etc.)
│   └── auth.json     ← Password hash (DO NOT SHARE)
└── public/
    └── uploads/      ← Uploaded gallery images
```

### Backup

**Method 1: Manual**
```bash
sudo cp /var/www/wwtmc/data/state.json ~/wwtmc-backup-$(date +%Y%m%d).json
```

**Method 2: Admin Panel**
- Admin → Settings → **Export Data** (downloads as JSON)

**Method 3: Full directory**
```bash
sudo tar -czf ~/wwtmc-backup-$(date +%Y%m%d).tar.gz /var/www/wwtmc/data/
```

### Restore from Backup

```bash
# Restore state.json
sudo cp ~/wwtmc-backup-20250610.json /var/www/wwtmc/data/state.json
sudo systemctl restart wwtmc
```

---

## Google Calendar Integration

1. In **Google Calendar** → Settings
2. Find your calendar → **"Integrate calendar"**
3. Copy the **"Public address in iCal format"** (ends in `.ics`)
4. In admin panel → **Calendar** tab → paste the iCal URL
5. Click **Save & Embed**

The events list will now auto-sync with Google Calendar every 2 minutes (configurable in `server.js`).

---

## Security Tips

1. **Change the default password immediately** (you'll be forced to on first login)
2. **Use HTTPS** — set up Let's Encrypt (see Step 8 above)
3. **Set `secure: true`** in `server.js` session cookie once HTTPS is active
4. **Firewall:** Don't expose port 3000 to the internet; use Nginx instead
5. **Backups:** Keep regular backups of `state.json`
6. **Updates:** Update Node.js periodically (currently v20.x)

---

## Troubleshooting

### Service won't start
```bash
# Check what went wrong
sudo journalctl -u wwtmc -n 30

# Check permissions
ls -la /var/www/wwtmc/data/
sudo chown -R www-data:www-data /var/www/wwtmc/data
```

### Permission denied on data directory
```bash
sudo chmod -R 775 /var/www/wwtmc/data
sudo chmod -R 775 /var/www/wwtmc/public/uploads
```

### Port 3000 already in use
```bash
sudo lsof -i :3000
# Kill the process using it, then restart
```

### Nginx not forwarding
```bash
# Test Nginx config
sudo nginx -t

# Reload if OK
sudo systemctl reload nginx

# Check Nginx error log
sudo tail -f /var/log/nginx/error.log
```

### Google Calendar not syncing
- Verify calendar is **Public** in Google Calendar settings
- Verify iCal URL ends in `.ics` (not the embed URL)
- Check server logs: `sudo journalctl -u wwtmc -f`

---

## File Structure

```
/var/www/wwtmc/
├── server.js              ← Express app (main backend)
├── package.json           ← Node dependencies
├── package-lock.json      ← Locked versions
├── install.sh             ← Installation script
├── update.sh              ← Update script
├── wwtmc.service          ← Systemd service file
├── nginx.conf             ← Nginx reverse proxy config
├── README.md              ← This file
├── QUICKSTART.md          ← Quick reference
├── data/                  ← Created automatically
│   ├── state.json         ← All site content (auto-created on first run)
│   └── auth.json          ← Password hash (auto-created on first run)
└── public/
    ├── index.html         ← The website (HTML/CSS/JS)
    └── uploads/           ← Gallery images (uploaded via admin)
```

---

## Environment Variables

Optional — set these in the systemd service file:

```bash
# In /etc/systemd/system/wwtmc.service
Environment=PORT=3000
Environment=SESSION_SECRET=your-random-secret-here
```

Defaults are fine for most setups.

---

## Performance & Scaling

- **Single server:** Handles ~1000 concurrent users easily
- **Data size:** `state.json` can grow to several MB without issues
- **Uploads:** Images stored on disk; use CDN for very large galleries
- **Database:** Optional — currently uses JSON files (good for small/medium sites)

For larger deployments:
- Add a reverse proxy (Nginx) — handled by `install.sh`
- Consider a database (PostgreSQL) — requires code changes
- Use object storage (S3) for images — requires code changes

---

## Tested On

- ✅ Ubuntu 22.04 LTS
- ✅ Ubuntu 24.04 LTS
- ✅ Debian 11, 12
- ✅ WSL2 (Ubuntu)
- ✅ Node.js 20.x LTS
- ✅ Nginx 1.18+

---

## Support & Contributing

For issues or improvements, check:
1. Logs: `sudo journalctl -u wwtmc -f`
2. This guide's "Troubleshooting" section
3. The `QUICKSTART.md` for quick reference

---

## License & Credits

WWT Music Club website platform — Node.js/Express, vanilla JavaScript, dark theme UI.

Built with ❤️ for music communities.
