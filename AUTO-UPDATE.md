# WWT Music Club — Auto-Update Guide

The auto-update system allows your server to check for updates and apply them automatically without manual intervention.

---

## Three Ways to Use Auto-Updates

### 1️⃣ **Background Service (Continuous Monitoring)**

Best for: Monitoring a live git repository or network share

```bash
# Set up the auto-update service
sudo cp auto-update.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable auto-update
sudo systemctl start auto-update
sudo systemctl status auto-update

# View logs
sudo journalctl -u auto-update -f
```

**Pros:**
- Runs continuously in the background
- Checks for updates at regular intervals
- Auto-restarts if it crashes
- Easy to enable/disable

**Cons:**
- Continuously running process

---

### 2️⃣ **Systemd Timer (Scheduled)**

Best for: Running at specific times (like cron)

```bash
# Set up the timer
sudo cp auto-update.timer /etc/systemd/system/
sudo cp auto-update.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable auto-update.timer
sudo systemctl start auto-update.timer
sudo systemctl status auto-update.timer

# View timer schedule
sudo systemctl list-timers auto-update.timer

# View logs
sudo journalctl -u auto-update -f
```

**Pros:**
- Runs only at scheduled times (more efficient)
- Predictable check times
- Similar to cron but better integrated

**Cons:**
- Only checks at scheduled intervals

---

### 3️⃣ **Manual/Cron (One-Time or Scheduled)**

Best for: Running on a schedule via cron

```bash
# One-time check
SOURCE_DIR=/mnt/updates bash /var/www/wwtmc/auto-update.sh once

# Add to crontab for every 4 hours
sudo crontab -e
# Add this line:
0 */4 * * * SOURCE_DIR=/mnt/updates bash /var/www/wwtmc/auto-update.sh once >> /var/log/wwtmc-auto-update.log 2>&1
```

**Pros:**
- No background process
- Can use standard cron scheduling
- Full control

**Cons:**
- Requires crontab setup

---

## Configuration

### From Git Repository

```bash
# Edit the service
sudo nano /etc/systemd/system/auto-update.service

# Change the Environment lines to:
Environment="SOURCE_REPO=https://github.com/your-org/wwtmc.git"
Environment="CHECK_INTERVAL=3600"

# Restart the service
sudo systemctl restart auto-update
```

### From Local Directory

```bash
# Edit the service
sudo nano /etc/systemd/system/auto-update.service

# Change the Environment lines to:
Environment="SOURCE_DIR=/mnt/updates/wwtmc"
Environment="CHECK_INTERVAL=1800"

# Restart the service
sudo systemctl restart auto-update
```

### Interval Options

| Interval | Seconds |
|----------|---------|
| Every 30 minutes | 1800 |
| Every 1 hour | 3600 |
| Every 2 hours | 7200 |
| Every 4 hours | 14400 |
| Every 12 hours | 43200 |
| Every 24 hours | 86400 |

---

## Usage Scenarios

### Scenario 1: Auto-Update from GitHub

You maintain a GitHub repo with your custom code.

```bash
# Edit /etc/systemd/system/auto-update.service
Environment="SOURCE_REPO=https://github.com/your-org/wwtmc.git"
Environment="CHECK_INTERVAL=3600"

# Start the service
sudo systemctl start auto-update
```

The server will:
1. Check the git repo every hour
2. If new code is detected, pull it
3. Run `update.sh` to safely apply changes
4. Backup `state.json` automatically
5. Restart the service

---

### Scenario 2: Auto-Update from Network Share

You push updates to a network share, and the server checks for them.

```bash
# Mount a network share
sudo mount -t nfs server.local:/share /mnt/updates

# Edit /etc/systemd/system/auto-update.service
Environment="SOURCE_DIR=/mnt/updates/wwtmc"
Environment="CHECK_INTERVAL=1800"

# Start the service
sudo systemctl start auto-update
```

The server will:
1. Check the network share every 30 minutes
2. Compare modification times of `server.js`
3. If newer files exist, apply the update
4. Backup data automatically

---

### Scenario 3: Scheduled Updates via Timer

You want updates to run at specific times (like 2am when no one is using the site).

```bash
# Edit /etc/systemd/system/auto-update.timer
[Timer]
OnCalendar=*-*-* 02:00:00  # Run at 2 AM daily
OnCalendar=*-*-* 14:00:00  # Also run at 2 PM daily
Persistent=true

# Or every 6 hours:
# OnUnitActiveSec=6h

# Start the timer
sudo systemctl start auto-update.timer
sudo systemctl enable auto-update.timer
```

---

## How It Works

1. **Checks for updates** (git or local directory)
2. **Detects changes** (comparing file modification times)
3. **Creates backup** of `state.json` before updating
4. **Runs `update.sh`** which:
   - Stops the service
   - Updates code files
   - Installs npm dependencies
   - Restarts the service
5. **Logs the result** to `/var/log/wwtmc-auto-update.log`

**Your data is always safe** — `state.json` is backed up before each update.

---

## Logs & Monitoring

### View Live Logs

```bash
# Service logs
sudo journalctl -u auto-update -f

# Timer logs
sudo journalctl -u auto-update.timer -f

# Log file
sudo tail -f /var/log/wwtmc-auto-update.log
```

### Check Service Status

```bash
# Service status
sudo systemctl status auto-update

# Timer status
sudo systemctl status auto-update.timer
sudo systemctl list-timers auto-update.timer
```

### Log Rotation

The auto-update script automatically rotates logs when they exceed 10MB. Old logs are saved as `wwtmc-auto-update.log.YYYYMMDD_HHMMSS`.

---

## Troubleshooting

### Service won't start

```bash
# Check the service file for errors
sudo systemctl status auto-update
sudo journalctl -u auto-update -n 30

# Validate the service file
sudo systemctl daemon-reload
```

### Updates not applying

```bash
# Verify SOURCE_REPO or SOURCE_DIR is set
sudo systemctl show auto-update | grep Environment

# Check git repo is accessible
git clone --depth 1 https://github.com/your-org/wwtmc.git /tmp/test-clone

# Check local directory is readable
ls -la /mnt/updates/wwtmc/
```

### Permission denied

```bash
# Auto-update must run as root
sudo systemctl show auto-update -p User

# If not root, edit the service file
sudo nano /etc/systemd/system/auto-update.service
# Change: User=root
```

### Out of disk space

```bash
# Check disk usage
df -h

# Clear old backups
sudo ls -lh /var/www/wwtmc/data/state.json.backup.*
sudo rm /var/www/wwtmc/data/state.json.backup.* # Keep recent ones!
```

---

## Disabling Auto-Updates

### Temporarily (keep enabled on boot)
```bash
sudo systemctl stop auto-update
```

### Permanently (disable on boot)
```bash
sudo systemctl disable auto-update
sudo systemctl stop auto-update
```

### Re-enable
```bash
sudo systemctl enable auto-update
sudo systemctl start auto-update
```

---

## Best Practices

1. **Test on staging first** — before enabling auto-updates on production
2. **Keep git repo in sync** — if using git source, push your updates to the repo first
3. **Monitor logs regularly** — check `/var/log/wwtmc-auto-update.log` for errors
4. **Keep backups** — auto-update creates backups, but also backup externally
5. **Use reasonable intervals** — 1-4 hours is usually good, not every minute
6. **Run updates off-peak** — use systemd timer to schedule updates during low-traffic times

---

## Example: Complete Setup (GitHub + Timer)

```bash
# 1. Copy the files
sudo cp auto-update.service /etc/systemd/system/
sudo cp auto-update.timer /etc/systemd/system/
sudo cp auto-update.sh /var/www/wwtmc/

# 2. Edit the service
sudo tee /etc/systemd/system/auto-update.service > /dev/null <<EOF
[Unit]
Description=WWT Music Club Auto-Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
Environment="SOURCE_REPO=https://github.com/your-org/wwtmc.git"
ExecStart=/bin/bash /var/www/wwtmc/auto-update.sh once
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 3. Edit the timer
sudo tee /etc/systemd/system/auto-update.timer > /dev/null <<EOF
[Unit]
Description=WWT Music Club Auto-Update Timer
Requires=auto-update.service

[Timer]
OnBootSec=5min
OnCalendar=*-*-* 02:00:00
OnCalendar=*-*-* 14:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 4. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable auto-update.timer
sudo systemctl start auto-update.timer

# 5. Verify
sudo systemctl list-timers auto-update.timer
sudo journalctl -u auto-update -f
```

Updates will now run automatically at 2 AM and 2 PM every day! 🚀
