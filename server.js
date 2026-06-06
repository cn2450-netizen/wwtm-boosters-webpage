'use strict';

const express    = require('express');
const session    = require('express-session');
const bcrypt     = require('bcryptjs');
const helmet     = require('helmet');
const multer     = require('multer');
const path       = require('path');
const fs         = require('fs');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─── Paths ───────────────────────────────────────────────
const DATA_DIR    = path.join(__dirname, 'data');
const UPLOADS_DIR = path.join(__dirname, 'public', 'uploads');
const STATE_FILE  = path.join(DATA_DIR, 'state.json');
const AUTH_FILE   = path.join(DATA_DIR, 'auth.json');

[DATA_DIR, UPLOADS_DIR].forEach(d => fs.mkdirSync(d, { recursive: true }));

// ─── Default site state ──────────────────────────────────
const DEFAULT_STATE = {
  clubName:        'WWT Music Club',
  heroEyebrow:     'Est. 2018 · Live Music · Community',
  heroTitle:       'WWT\nMUSIC\nCLUB',
  heroSub:         'A passionate community of musicians and music lovers coming together to celebrate the art of live performance.',
  aboutBadgeNum:   '6+',
  aboutP1:         'Founded in 2018, WWT Music Club was born from a shared love of live music and the belief that great sounds bring people together.',
  aboutP2:         'Our community hosts weekly jam sessions, workshops, open mic nights, and major seasonal concerts.',
  stat1: '120+', stat2: '48', stat3: '6',
  contactEmail:    'info@wwtmusic.club',
  contactLocation: '123 Main Street, Anytown, USA',
  contactPhone:    '(555) 123-4567',
  socialFb: '#', socialIg: '#', socialYt: '#',
  studentAccountUrl: '',
  bylawsUrl:         '',
  documentTree: [],
  onlineStoreUrl: '',
  footerCopy:      '© 2025 WWT Music Club. All rights reserved.',
  calendarUrl:     '',
  calendarIcsUrl:  '',
  aboutImgSrc:     'https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=800&q=80',
  galleryImages: [
    { src: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&q=80', caption: 'Live Summer Concert · 2024' },
    { src: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80', caption: 'Weekly Rehearsal' },
    { src: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&q=80', caption: 'Open Jam Night' },
    { src: 'https://images.unsplash.com/photo-1415201364774-f6f0bb35f28f?w=600&q=80', caption: 'Studio Session' },
    { src: 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=600&q=80', caption: 'Acoustic Evening' },
  ],
  events: [
    { id: 1, title: 'Open Mic Night',     date: '2025-07-12', time: '7:00 PM', location: 'The Studio',              tag: 'Free'     },
    { id: 2, title: 'Summer Jam Festival', date: '2025-07-19', time: '3:00 PM', location: 'City Park Amphitheater', tag: 'Ticketed'  },
    { id: 3, title: 'Beginner Workshop',  date: '2025-07-26', time: '10:00 AM', location: 'Club HQ',                tag: 'Members'  },
    { id: 4, title: 'Acoustic Showcase',  date: '2025-08-02', time: '6:30 PM',  location: 'The Grove Venue',        tag: 'Free'     },
  ],
  boardMembers: [
    { id: 1, name: 'John Smith', title: 'President', email: 'president@wwtmusic.club' },
    { id: 2, name: 'Sarah Johnson', title: 'Vice President', email: 'vicepresident@wwtmusic.club' },
    { id: 3, name: 'Mike Davis', title: 'Secretary', email: 'secretary@wwtmusic.club' },
    { id: 4, name: 'Lisa Wong', title: 'Treasurer', email: 'treasurer@wwtmusic.club' },
    { id: 5, name: 'Tom Brady', title: 'Fundraising Manager', email: 'fundraising@wwtmusic.club' },
  ],
};

// ─── Data helpers ────────────────────────────────────────
function readJSON(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch { return fallback; }
}
function writeJSON(file, data) {
  fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
}

function getState()  { return { ...DEFAULT_STATE, ...readJSON(STATE_FILE, {}) }; }
function saveState(s) { writeJSON(STATE_FILE, s); }

function getAuth() {
  const a = readJSON(AUTH_FILE, null);
  if (!a) {
    // First run — store bcrypt hash of 'admin', mark as default
    const hash = bcrypt.hashSync('admin', 10);
    const fresh = { passwordHash: hash, isDefault: true };
    writeJSON(AUTH_FILE, fresh);
    return fresh;
  }
  return a;
}
function saveAuth(a) { writeJSON(AUTH_FILE, a); }

// ─── Multer (image uploads) ──────────────────────────────
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
  filename:    (_req, file, cb) => {
    const safe = Date.now() + '-' + file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, safe);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB
  fileFilter: (_req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('Only image files allowed'));
  },
});

// ─── Middleware ──────────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: false, // disabled so the HTML page can load external fonts/images
}));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(session({
  secret: process.env.SESSION_SECRET || 'wwtmc-secret-change-in-production',
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: false,          // set true if running HTTPS
    maxAge: 8 * 60 * 60 * 1000, // 8-hour session
  },
}));

// Serve uploaded images and the front-end
app.use('/uploads', express.static(UPLOADS_DIR));
app.use(express.static(path.join(__dirname, 'public')));

// ─── Auth middleware ─────────────────────────────────────
function requireAuth(req, res, next) {
  if (req.session && req.session.admin) return next();
  res.status(401).json({ error: 'Unauthorized' });
}

// ─── Rate limiter (simple in-memory) ────────────────────
const loginAttempts = {};
function loginRateLimit(req, res, next) {
  const ip  = req.ip;
  const now = Date.now();
  const rec = loginAttempts[ip] || { count: 0, until: 0 };
  if (now < rec.until) {
    return res.status(429).json({ error: `Too many attempts. Try again in ${Math.ceil((rec.until - now) / 1000)}s.` });
  }
  req._loginRec = rec;
  req._loginIp  = ip;
  next();
}
function recordFailedLogin(req) {
  const rec = req._loginRec;
  rec.count++;
  if (rec.count >= 5) { rec.until = Date.now() + 30000; rec.count = 0; }
  loginAttempts[req._loginIp] = rec;
}
function clearLoginAttempts(req) {
  delete loginAttempts[req._loginIp];
}

// ─── Calendar ICS helpers ────────────────────────────────
let _calCache = { data: null, url: '', fetchedAt: 0 };
const CAL_TTL = 15 * 60 * 1000; // 15 minutes

async function fetchICSText(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'WWTMC-Calendar/1.0' },
    signal:  AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

function parseICS(raw) {
  const lines = raw.replace(/\r\n[ \t]/g, '').replace(/\r\n/g, '\n').split('\n');
  const evs = [];
  let ev = null;
  for (const line of lines) {
    const t = line.trim();
    if (t === 'BEGIN:VEVENT') { ev = {}; continue; }
    if (t === 'END:VEVENT')   { if (ev) evs.push(ev); ev = null; continue; }
    if (!ev) continue;
    const ci = line.indexOf(':');
    if (ci < 0) continue;
    const key = line.slice(0, ci).split(';')[0].trim().toUpperCase();
    ev[key] = line.slice(ci + 1).trim();
  }
  return evs;
}

// Extract YYYY-MM-DD directly from DTSTART string — avoids timezone conversion bugs
function icsDateStr(s) {
  const m = (s || '').match(/^(\d{4})(\d{2})(\d{2})/);
  return m ? `${m[1]}-${m[2]}-${m[3]}` : null;
}

// Extract 12-hour time from DTSTART string (uses the local/floating time as written)
function icsTimeStr(s) {
  const m = (s || '').match(/T(\d{2})(\d{2})/);
  if (!m) return 'All Day';
  const h = parseInt(m[1]);
  return `${h % 12 || 12}:${m[2]} ${h >= 12 ? 'PM' : 'AM'}`;
}

// ════════════════════════════════════════════════════════
//  API ROUTES
// ════════════════════════════════════════════════════════

// ── Auth ─────────────────────────────────────────────────

// Check session / default-pw status
app.get('/api/auth/status', (req, res) => {
  const auth = getAuth();
  res.json({
    loggedIn:  !!(req.session && req.session.admin),
    isDefault: auth.isDefault,
  });
});

// Login
app.post('/api/auth/login', loginRateLimit, (req, res) => {
  const { password } = req.body;
  if (!password) return res.status(400).json({ error: 'Password required' });
  const auth = getAuth();
  if (!bcrypt.compareSync(password, auth.passwordHash)) {
    recordFailedLogin(req);
    return res.status(401).json({ error: 'Incorrect password' });
  }
  clearLoginAttempts(req);
  req.session.admin = true;
  res.json({ ok: true, isDefault: auth.isDefault });
});

// Logout
app.post('/api/auth/logout', (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

// Change password
app.post('/api/auth/change-password', requireAuth, (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const auth = getAuth();
  if (!bcrypt.compareSync(currentPassword, auth.passwordHash))
    return res.status(401).json({ error: 'Current password is incorrect' });
  if (!newPassword || newPassword.length < 8)
    return res.status(400).json({ error: 'New password must be at least 8 characters' });
  if (newPassword === 'admin')
    return res.status(400).json({ error: 'New password cannot be the default password' });
  if (bcrypt.compareSync(newPassword, auth.passwordHash))
    return res.status(400).json({ error: 'New password must differ from current' });
  auth.passwordHash = bcrypt.hashSync(newPassword, 10);
  auth.isDefault    = false;
  saveAuth(auth);
  res.json({ ok: true });
});

// ── Site state ────────────────────────────────────────────

// Public read
app.get('/api/state', (_req, res) => {
  res.json(getState());
});

// Admin write (full state replace)
app.post('/api/state', requireAuth, (req, res) => {
  const current = getState();
  const updated  = { ...current, ...req.body };
  // Ensure arrays are not accidentally replaced with non-arrays
  if (!Array.isArray(updated.galleryImages)) updated.galleryImages = current.galleryImages;
  if (!Array.isArray(updated.events))        updated.events        = current.events;
  if (!Array.isArray(updated.documentTree))  updated.documentTree  = current.documentTree;
  if (!Array.isArray(updated.boardMembers))  updated.boardMembers  = current.boardMembers;
  saveState(updated);
  res.json({ ok: true });
});

// ── Events ────────────────────────────────────────────────

app.post('/api/events', requireAuth, (req, res) => {
  const s  = getState();
  const ev = {
    id:       Date.now(),
    title:    req.body.title    || 'Untitled',
    date:     req.body.date     || new Date().toISOString().split('T')[0],
    time:     req.body.time     || '7:00 PM',
    location: req.body.location || 'TBA',
    tag:      req.body.tag      || 'Free',
  };
  s.events.push(ev);
  s.events.sort((a, b) => new Date(a.date) - new Date(b.date));
  saveState(s);
  res.json({ ok: true, event: ev });
});

app.put('/api/events/:id', requireAuth, (req, res) => {
  const s   = getState();
  const idx = s.events.findIndex(e => e.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'Event not found' });
  s.events[idx] = { ...s.events[idx], ...req.body, id: s.events[idx].id };
  s.events.sort((a, b) => new Date(a.date) - new Date(b.date));
  saveState(s);
  res.json({ ok: true });
});

app.delete('/api/events/:id', requireAuth, (req, res) => {
  const s = getState();
  s.events = s.events.filter(e => e.id !== parseInt(req.params.id));
  saveState(s);
  res.json({ ok: true });
});

// ── Gallery ───────────────────────────────────────────────

// Upload image file
app.post('/api/gallery/upload', requireAuth, upload.single('image'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const s   = getState();
  const img = {
    src:     '/uploads/' + req.file.filename,
    caption: req.body.caption || req.file.originalname.replace(/\.[^.]+$/, ''),
  };
  s.galleryImages.push(img);
  saveState(s);
  res.json({ ok: true, image: img });
});

// Add image by URL
app.post('/api/gallery/url', requireAuth, (req, res) => {
  const { src, caption } = req.body;
  if (!src) return res.status(400).json({ error: 'Image URL required' });
  const s = getState();
  s.galleryImages.push({ src, caption: caption || 'New Image' });
  saveState(s);
  res.json({ ok: true });
});

// Delete gallery image
app.delete('/api/gallery/:index', requireAuth, (req, res) => {
  const s   = getState();
  const idx = parseInt(req.params.index);
  if (isNaN(idx) || idx < 0 || idx >= s.galleryImages.length)
    return res.status(404).json({ error: 'Image not found' });
  // Delete uploaded file if it lives on this server
  const img = s.galleryImages[idx];
  if (img.src.startsWith('/uploads/')) {
    const filePath = path.join(UPLOADS_DIR, path.basename(img.src));
    fs.unlink(filePath, () => {}); // ignore errors
  }
  s.galleryImages.splice(idx, 1);
  saveState(s);
  res.json({ ok: true });
});

// ── About photo upload ────────────────────────────────────
app.post('/api/about/upload', requireAuth, upload.single('image'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const s = getState();
  // Delete old uploaded about image if it was a local file
  if (s.aboutImgSrc && s.aboutImgSrc.startsWith('/uploads/')) {
    const oldPath = path.join(UPLOADS_DIR, path.basename(s.aboutImgSrc));
    fs.unlink(oldPath, () => {});
  }
  s.aboutImgSrc = '/uploads/' + req.file.filename;
  saveState(s);
  res.json({ ok: true, src: s.aboutImgSrc });
});

// ── Reset ─────────────────────────────────────────────────
app.post('/api/reset', requireAuth, (req, res) => {
  saveState(DEFAULT_STATE);
  const hash = bcrypt.hashSync('admin', 10);
  saveAuth({ passwordHash: hash, isDefault: true });
  req.session.destroy(() => res.json({ ok: true }));
});

// ── Calendar events feed ──────────────────────────────────
app.get('/api/calendar/events', async (req, res) => {
  const s = getState();
  if (!s.calendarIcsUrl) return res.json({ events: [] });

  const now = Date.now();
  if (_calCache.url === s.calendarIcsUrl && now - _calCache.fetchedAt < CAL_TTL)
    return res.json({ events: _calCache.data });

  try {
    const raw      = await fetchICSText(s.calendarIcsUrl);
    const allEvs   = parseICS(raw);
    const todayStr = new Date().toISOString().split('T')[0]; // YYYY-MM-DD UTC

    console.log(`[calendar] fetched ICS — ${allEvs.length} total events, today=${todayStr}`);

    const upcoming = allEvs
      .map(ev => {
        const dateStr = icsDateStr(ev['DTSTART']);
        if (!dateStr) return null;
        if (dateStr < todayStr) return null;
        return {
          id:       ev['UID'] || `${now}-${Math.random()}`,
          title:    (ev['SUMMARY']  || 'Untitled').replace(/\\,/g, ',').replace(/\\n/g, ' '),
          date:     dateStr,
          time:     icsTimeStr(ev['DTSTART']),
          location: (ev['LOCATION'] || 'TBA').replace(/\\,/g, ',').replace(/\\n/g, ' '),
          tag:      'Event',
        };
      })
      .filter(Boolean)
      .sort((a, b) => a.date.localeCompare(b.date))
      .slice(0, 6);

    console.log(`[calendar] ${upcoming.length} upcoming events returned`);
    _calCache = { data: upcoming, url: s.calendarIcsUrl, fetchedAt: now };
    res.json({ events: upcoming });
  } catch (err) {
    console.error('[calendar] fetch error:', err.message);
    if (_calCache.data && _calCache.url === s.calendarIcsUrl)
      return res.json({ events: _calCache.data });
    res.json({ events: [] });
  }
});

// ── Serve SPA ─────────────────────────────────────────────
app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── Start ───────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n  WWT Music Club server running on http://localhost:${PORT}`);
  console.log(`  Data stored in: ${DATA_DIR}`);
  console.log(`  Uploads stored in: ${UPLOADS_DIR}\n`);
});
