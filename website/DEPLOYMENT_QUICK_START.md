# FamQuest Marketing Website - Quick Deployment Guide

## 🚀 Deploy to Vercel (Recommended - 5 minutes)

### Prerequisites
- GitHub account
- Vercel account (free tier is fine)
- Git installed locally

### Step-by-Step

1. **Push to GitHub**
```bash
cd "c:\Ai Projecten\AiFamQuest"
git add website/
git commit -m "Add new marketing website"
git push origin master
```

2. **Connect to Vercel**
- Go to [vercel.com](https://vercel.com)
- Click "Import Project"
- Select your GitHub repository
- **Root Directory**: Set to `website/`
- **Build Command**: Leave empty (static site)
- **Output Directory**: `.` (current directory)
- Click "Deploy"

3. **Custom Domain (Optional)**
- In Vercel project settings → Domains
- Add `famquest.app` (or your domain)
- Update DNS records as instructed

**Done!** Your site is live at `your-project.vercel.app`

---

## 🎨 Before Going Live Checklist

### Critical (Must-Do)

- [ ] **Replace placeholder images**
  - Create mockup screenshots of actual app
  - Add to `website/images/` folder
  - Update image paths in `index-new.html`

- [ ] **Update links**
  - App Store URL (line 570)
  - Google Play URL (line 580)
  - Web app URL (line 599)
  - Social media links (footer)

- [ ] **Add Google Analytics**
  - Replace `GA_MEASUREMENT_ID` with your tracking ID (line 32)

- [ ] **Test all CTAs**
  - "Probeer Gratis" buttons work
  - "Download" links go to correct stores
  - Email links work

### Important (Should-Do)

- [ ] **Optimize images**
  - Convert to WebP/AVIF
  - Compress (TinyPNG, ImageOptim)
  - Add loading="lazy"

- [ ] **Minify assets**
```bash
# Install tools
npm install -g csso-cli terser html-minifier

# Minify CSS
csso styles-new.css -o styles-new.min.css

# Minify JS
terser app-new.js -o app-new.min.js -c -m

# Update HTML to use minified files
```

- [ ] **Test mobile responsiveness**
  - iOS Safari
  - Android Chrome
  - Tablet views

- [ ] **Run Lighthouse audit**
  - Chrome DevTools → Lighthouse
  - Target: All scores > 90

### Nice-to-Have

- [ ] Add real customer testimonials (with permission)
- [ ] Record demo video
- [ ] Create FAQ content from real user questions
- [ ] Setup cookie consent banner
- [ ] Add live chat widget (Intercom/Crisp)

---

## 📱 Quick Local Test

```bash
# Option 1: Python
cd "c:\Ai Projecten\AiFamQuest\website"
python -m http.server 8000

# Option 2: Node.js
npx http-server -p 8000

# Visit: http://localhost:8000/index-new.html
```

---

## 🎯 Marketing Website vs App Routing

**Important**: This marketing website is separate from the Flutter web app!

### Recommended URL Structure

```
famquest.app/                → Marketing website (Vercel)
famquest.app/app/            → Flutter web app (Firebase/separate hosting)
famquest.app/blog/           → Blog (Ghost/WordPress)
famquest.app/help/           → Help center (Zendesk/custom)
```

### DNS Setup Example

```
# Marketing site (Vercel)
famquest.app                 → Vercel
www.famquest.app             → Vercel

# Flutter app (Firebase)
app.famquest.app             → Firebase Hosting

# Or subdirectory routing via Vercel
/app/*                       → Proxy to Firebase
```

---

## 🔍 SEO Quick Wins

### Google Search Console
1. Add property: famquest.app
2. Verify ownership (HTML tag method)
3. Submit sitemap: `famquest.app/sitemap.xml`

### Sitemap Generation
```xml
<!-- website/sitemap.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://famquest.app/</loc>
    <lastmod>2025-11-19</lastmod>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://famquest.app/pricing/</loc>
    <lastmod>2025-11-19</lastmod>
    <priority>0.8</priority>
  </url>
</urlset>
```

### robots.txt
```txt
# website/robots.txt
User-agent: *
Allow: /

Sitemap: https://famquest.app/sitemap.xml
```

---

## 📊 Analytics Setup (5 minutes)

### Google Analytics 4

1. **Create Property**
   - Go to [analytics.google.com](https://analytics.google.com)
   - Create new GA4 property
   - Copy Measurement ID (G-XXXXXXXXXX)

2. **Add to Website**
   - Replace `GA_MEASUREMENT_ID` in `index-new.html` (line 32, 37)

3. **Setup Events**
   - CTAs already tracked via `data-cta` attributes
   - FAQ opens tracked automatically
   - Scroll depth tracked via Intersection Observer

### Optional: Hotjar Heatmaps
```html
<!-- Add before </head> -->
<script>
  (function(h,o,t,j,a,r){
    h.hj=h.hj||function(){(h.hj.q=h.hj.q||[]).push(arguments)};
    h._hjSettings={hjid:YOUR_HOTJAR_ID,hjsv:6};
    a=o.getElementsByTagName('head')[0];
    r=o.createElement('script');r.async=1;
    r.src=t+h._hjSettings.hjid+j+h._hjSettings.hjsv;
    a.appendChild(r);
  })(window,document,'https://static.hotjar.com/c/hotjar-','.js?sv=');
</script>
```

---

## 🧪 A/B Testing with Vercel

### Setup Experiments

1. **Create Variants**
```bash
# Clone homepage for variant
cp index-new.html index-variant-b.html

# Edit headline in variant B
# "Stop Met Zeuren: FamQuest Regelt Het"
```

2. **Vercel Edge Middleware** (vercel.json)
```json
{
  "rewrites": [
    {
      "source": "/",
      "destination": "/index-new.html",
      "has": [
        {
          "type": "cookie",
          "key": "variant",
          "value": "b"
        }
      ]
    }
  ]
}
```

3. **Split Traffic** (50/50)
```javascript
// middleware.js (Vercel Edge Function)
export default function middleware(req) {
  const variant = Math.random() < 0.5 ? 'a' : 'b';
  const response = NextResponse.next();
  response.cookies.set('variant', variant);
  return response;
}
```

---

## 💰 Conversion Optimization Tips

### Above the Fold
- **Hero visible immediately** (no scrolling)
- **CTA in first 3 seconds** (clear action)
- **Social proof visible** (500+ families)

### Trust Signals
- Add badges: "AVG Compliant", "Made in NL", "AI-Powered"
- Show real testimonials (with photos)
- Display app store ratings (when available)

### Friction Reduction
- **No signup required** to browse
- **Free tier always available** (no credit card)
- **30-day money back** (risk reversal)

### Mobile Optimization
- **Thumb-friendly CTAs** (large buttons, bottom placement)
- **Fast loading** (<2s on 3G)
- **Readable text** (min 16px font size)

---

## 🐛 Common Issues & Fixes

### Issue: Images not loading
```html
<!-- Bad: Relative path -->
<img src="images/hero.png">

<!-- Good: Absolute path -->
<img src="/images/hero.png">
```

### Issue: CSS/JS not loading after deploy
- Check file paths (absolute vs relative)
- Clear browser cache (Ctrl+F5)
- Verify files uploaded to hosting

### Issue: Mobile menu not working
- Check JavaScript loaded (`app-new.js`)
- Test `.nav-toggle` click event
- Verify CSS for `.nav-links.active`

### Issue: Slow page load
- Compress images (WebP, AVIF)
- Lazy load below-fold images
- Minify CSS/JS
- Use CDN (Cloudflare, Vercel Edge)

---

## 📈 Week 1 Post-Launch Actions

### Day 1
- [ ] Deploy to production
- [ ] Setup analytics
- [ ] Test all links
- [ ] Share on social media

### Day 2-3
- [ ] Monitor analytics (bounce rate, time on page)
- [ ] Check for broken links (Screaming Frog)
- [ ] Test on multiple devices

### Day 4-7
- [ ] Collect user feedback
- [ ] Fix any reported bugs
- [ ] Start A/B testing headlines
- [ ] Optimize low-performing sections

---

## 🎯 Success Metrics (Week 1)

### Traffic
- **Unique visitors**: 100+ (organic + ads)
- **Bounce rate**: <60%
- **Avg session duration**: >1min 30s

### Engagement
- **Scroll depth**: 50%+ reach features
- **CTA clicks**: 5%+ click-through rate
- **FAQ opens**: 20%+ interaction

### Conversion
- **Download clicks**: 2%+ of visitors
- **Email signups**: 1%+ (if you have newsletter)

---

## 🚨 Emergency Rollback

If something breaks after deployment:

```bash
# Vercel: Rollback to previous deployment
vercel rollback

# Or redeploy previous version
git revert HEAD
git push origin master
vercel --prod
```

---

## 📞 Support

- **Questions**: marketing@famquest.app
- **Bugs**: GitHub Issues
- **Updates**: Check MARKETING_WEBSITE_README.md

---

**Ready to launch? Ship it! 🚀**