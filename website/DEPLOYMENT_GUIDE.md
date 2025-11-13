# FamQuest Website - Quick Deployment Guide

## 5-Minute Quick Start

### Option 1: Firebase Hosting (Recommended)

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login
firebase login

# 3. Deploy
cd website
firebase deploy

# Done! Your site is live at: https://[project-id].web.app
```

### Option 2: Netlify

```bash
# 1. Install Netlify CLI
npm install -g netlify-cli

# 2. Deploy
cd website
netlify deploy --prod

# Done! Your site is live
```

### Option 3: Manual Deployment (Any Host)

1. Upload `website/` folder to your hosting via SFTP/FTP
2. Set document root to `website/` folder
3. Enable GZIP compression
4. Set cache headers (see below)

---

## Pre-Deployment Checklist

Before deploying, complete these tasks:

### 1. Image Assets (2 hours)

Create/add these images:

```
website/assets/
├── favicon.svg (any size, recommend 200x200)
├── icon-192.png (192x192 pixels)
├── icon-512.png (512x512 pixels)
├── icon-maskable.png (192x192 with safe area)
├── og-image.png (1200x630 pixels)
├── og-features.png (1200x630)
└── og-pricing.png (1200x630)

website/images/
├── hero-screenshot.webp (600x500 pixels)
├── feature-calendar-full.webp (500x400)
├── feature-tasks-full.webp (500x400)
├── feature-ai-full.webp (500x400)
├── feature-gamification-full.webp (500x400)
├── feature-vision-voice.webp (500x400)
├── feature-themes.webp (500x400)
└── feature-calendar.webp (300x200)
```

**Image Tools:**
- Figma: Create mockups
- TinyPNG.com: Compress
- ImageOptim: Batch optimize
- FFmpeg: Convert to WebP

### 2. Analytics Setup (15 minutes)

Add Google Analytics 4:

```html
<!-- Add this to <head> section of index.html -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

**Steps:**
1. Go to google.com/analytics
2. Create new property for famquest.app
3. Copy measurement ID
4. Replace GA_MEASUREMENT_ID above
5. Deploy

### 3. Email Backend Setup (1 hour)

Contact form needs backend. Choose one:

**Option A: Firebase Cloud Functions**
```javascript
// functions/contact.js
exports.contact = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');

  const { name, email, subject, message } = req.body;

  // Send email via Sendgrid, Mailgun, etc
  // Then respond
  res.json({ success: true });
});
```

**Option B: Use Netlify Forms**
```html
<form name="contact" method="POST" netlify>
  <input type="text" name="name" required>
  <input type="email" name="email" required>
  <input type="text" name="subject" required>
  <textarea name="message" required></textarea>
  <button type="submit">Send</button>
</form>
```

**Option C: Third-party service**
- Formspree.io
- Basin.io
- Getform.io

---

## Deployment Steps by Platform

### Firebase Hosting (Step-by-Step)

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login to Google
firebase login

# 3. Go to project directory
cd "c:/Ai Projecten/AiFamQuest/website"

# 4. Initialize Firebase (if first time)
firebase init hosting
# Select: Use existing project
# Public directory: . (current dir)
# Configure as SPA: No
# Overwrite public/index.html: No

# 5. Deploy
firebase deploy

# 6. View results
firebase open hosting:site
```

**Important Firebase Settings:**

Add to `firebase.json`:
```json
{
  "hosting": {
    "public": ".",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "redirects": [
      {
        "source": "/index.html",
        "destination": "/index.html",
        "type": 200
      }
    ],
    "headers": [
      {
        "source": "/css/**",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      },
      {
        "source": "/js/**",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      },
      {
        "source": "/**/*.@(jpg|jpeg|gif|png|webp|svg)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      },
      {
        "source": "/**/*.html",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=3600, must-revalidate"
          }
        ]
      }
    ]
  }
}
```

### Netlify (Step-by-Step)

```bash
# 1. Install Netlify CLI
npm install -g netlify-cli

# 2. Login to Netlify
netlify login

# 3. Go to project
cd "c:/Ai Projecten/AiFamQuest/website"

# 4. Deploy
netlify deploy --prod

# 5. Visit dashboard
netlify open site
```

**Important Netlify Settings:**

Create `netlify.toml`:
```toml
[build]
  publish = "."
  command = "echo 'No build required'"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[[headers]]
  for = "/css/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/js/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"

[[headers]]
  for = "/*.html"
  [headers.values]
    Cache-Control = "public, max-age=3600, must-revalidate"
```

---

## Post-Deployment Tasks (Essential)

### 1. Verify Site Works (5 minutes)

```
Test:
- [ ] Homepage loads
- [ ] Mobile menu works
- [ ] All links work
- [ ] Images load
- [ ] Footer visible
```

### 2. Google Search Console Setup (10 minutes)

```
1. Go to search.google.com/search-console
2. Click "URL prefix" property
3. Enter: https://famquest.app
4. Verify ownership (pick any method)
5. Submit sitemap: https://famquest.app/sitemap.xml
6. Request indexing
```

### 3. Bing Webmaster Setup (10 minutes)

```
1. Go to bing.com/webmasters
2. Add site: https://famquest.app
3. Verify ownership
4. Submit sitemap
```

### 4. Test Core Web Vitals (10 minutes)

```
Go to: https://pagespeed.web.dev/
Enter: https://famquest.app
Check scores:
- Performance: aim for > 90
- Accessibility: aim for > 90
- SEO: aim for > 90
- Best Practices: aim for > 90
```

### 5. Run Lighthouse Audit (5 minutes)

```
Chrome Browser:
1. Press F12 (DevTools)
2. Go to "Lighthouse" tab
3. Click "Analyze page load"
4. Check all scores > 90
```

---

## Ongoing Maintenance

### Weekly
```
- Check Google Search Console for errors
- Monitor Core Web Vitals
- Review organic traffic (Analytics)
```

### Monthly
```
- Update blog content
- Check for broken links
- Review search rankings
- Monitor performance metrics
```

### Quarterly
```
- Security audit
- Performance review
- SEO audit
- Update dependencies
```

---

## File Structure Reference

```
website/
├── index.html                 ← Homepage
├── features/index.html        ← Features page
├── pricing/index.html         ← Pricing page
├── support/
│   ├── index.html            ← Support/FAQ
│   └── privacy.html          ← Privacy policy
├── css/
│   ├── styles.css            ← Main stylesheet
│   └── responsive.css        ← Mobile breakpoints
├── js/
│   └── main.js               ← Core functionality
├── assets/                   ← Icons, OG images
│   ├── favicon.svg
│   ├── icon-192.png
│   ├── icon-512.png
│   ├── og-image.png
│   └── ...
├── images/                   ← Content images
│   ├── hero-screenshot.webp
│   ├── feature-*.webp
│   └── ...
├── manifest.json             ← PWA config
├── service-worker.js         ← Offline support
├── sitemap.xml               ← SEO sitemap
├── robots.txt                ← Search engines
└── README.md                 ← Documentation
```

---

## Troubleshooting

### Site Not Appearing in Google

**Solution:**
1. Verify ownership in Search Console
2. Submit sitemap
3. Request indexing
4. Wait 1-7 days

### Performance Score Low

**Check:**
1. Images are optimized (< 100KB each)
2. CSS/JS minified
3. No render-blocking scripts
4. Server response time < 600ms

### Mobile Menu Not Working

**Check:**
1. JavaScript loaded (F12 console)
2. Hamburger button visible
3. No console errors

### Images Not Showing

**Check:**
1. Image paths are correct
2. Images exist in assets/images folder
3. Alt text present
4. File names match exactly (case-sensitive on Linux)

---

## Contact & Support

**Issues:**
- Email: support@famquest.app
- GitHub Issues: [link]
- Twitter: @famquest

**Documentation:**
- README.md - Full setup guide
- SEO_CHECKLIST.md - Verification tasks
- CONTENT_PLAN.md - Content strategy

---

## Final Checklist Before Going Live

```
Pre-Launch:
[ ] All images created and optimized
[ ] Analytics script added
[ ] Email backend configured
[ ] Forms tested
[ ] Mobile menu tested
[ ] All links work
[ ] Meta tags verified
[ ] Favicon displays

Deployment:
[ ] Deploy to Firebase/Netlify
[ ] Verify site loads
[ ] Test on mobile device
[ ] Run Lighthouse audit (>90 scores)
[ ] Check OpenGraph preview

Post-Launch:
[ ] Submit to Google Search Console
[ ] Submit to Bing Webmaster
[ ] Add to Google Business Profile
[ ] Monitor Core Web Vitals
[ ] Check analytics data flowing
[ ] Monitor for errors (Firebase console)

```

---

**Ready to deploy?** → Run `firebase deploy` or `netlify deploy --prod`

**Need help?** → See README.md and SEO_CHECKLIST.md

**Last Updated:** January 15, 2025
