# FamQuest Marketing Website

A modern, SEO-optimized marketing website for FamQuest - the AI-powered family task management app.

## Project Structure

```
website/
├── index.html                 # Homepage
├── features/
│   └── index.html            # Features page
├── pricing/
│   └── index.html            # Pricing page
├── themes/
│   └── index.html            # Theme previews
├── blog/
│   └── index.html            # Blog listing
├── support/
│   ├── index.html            # Support & FAQ
│   ├── privacy.html          # Privacy policy
│   └── terms.html            # Terms of service
├── app/                       # PWA entry point
│   └── index.html
├── css/
│   ├── styles.css            # Main stylesheet
│   └── responsive.css        # Mobile-first responsive design
├── js/
│   └── main.js               # Core JavaScript
├── assets/                   # Images, icons, OG images
│   ├── favicon.svg
│   ├── icon-192.png
│   ├── icon-512.png
│   ├── og-image.png
│   └── ...
├── images/                   # Content images
│   ├── hero-screenshot.webp
│   ├── feature-calendar.webp
│   └── ...
├── manifest.json             # PWA manifest
├── service-worker.js         # Offline support
├── sitemap.xml               # SEO sitemap
├── robots.txt                # Search engine instructions
└── README.md                 # This file
```

## Features

- Mobile-first responsive design
- SEO optimized with JSON-LD structured data
- Progressive Web App (PWA) support
- Offline functionality via Service Worker
- Accessible (WCAG 2.1 AA compliant)
- Fast performance (Core Web Vitals optimized)
- Multi-language support (hreflang tags)
- Analytics ready (Google Analytics integration)
- Form handling with email backend

## Getting Started

### Local Development

```bash
# Serve locally (requires Python 3+)
python -m http.server 8000

# Or with Node.js/npm
npm install -g http-server
http-server

# Visit http://localhost:8000
```

### Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+
- Mobile browsers (iOS Safari 14+, Android Chrome 90+)

## SEO Features

### Metadata

- Unique H1 per page (no duplicates)
- Descriptive meta titles (50-60 chars)
- Meta descriptions (150-160 chars)
- OpenGraph tags for social sharing
- Twitter Card support
- JSON-LD structured data

### Technical SEO

- Valid HTML5 markup
- Clean URL structure
- XML sitemap (sitemap.xml)
- Robots.txt configuration
- hreflang for language variants (nl/en)
- Mobile-friendly design (viewport meta tag)
- Fast page load (LCP < 2.5s target)
- Zero layout shift (CLS < 0.1)
- Keyboard navigation
- ARIA labels and landmarks

### Content SEO

Primary keywords:
- "gezinsplanner" (family planner)
- "klusjesapp" (chore app)
- "taken voor kinderen" (tasks for children)
- "AI planning" (AI planning)
- "gamification" (gamification)

### Internal Linking

Every page links to:
- Home
- Features
- Pricing
- Blog
- Support
- Footer links for additional navigation

## Performance Optimization

### Image Optimization

Images should be:
- WebP format (with PNG fallback)
- Compressed (tools: TinyPNG, ImageOptim)
- Responsive (srcset attributes)
- Lazy loaded (loading="lazy")
- Descriptive alt text

```html
<img
  src="/images/feature.webp"
  alt="Descriptive alt text"
  width="300"
  height="200"
  loading="lazy">
```

### CSS & JavaScript

- CSS is minified in production
- JavaScript is deferred (loads at end)
- Service Worker caching strategy
- Critical CSS is inlined

### Web Vitals Targets

- LCP (Largest Contentful Paint): < 2.5s
- FID (First Input Delay): < 100ms
- CLS (Cumulative Layout Shift): < 0.1

## Deployment

### Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (if needed)
firebase init hosting

# Deploy
firebase deploy
```

### Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod --dir=website
```

### Manual Deployment

1. Build/minify assets (CSS, JS)
2. Compress images (WebP format)
3. Upload to hosting provider
4. Set 404.html for SPA routing
5. Enable HTTPS
6. Configure cache headers
7. Monitor Core Web Vitals

## Cache Headers Recommendations

```
# Static assets (images, fonts)
Cache-Control: public, max-age=31536000, immutable

# CSS/JS bundles
Cache-Control: public, max-age=31536000

# HTML pages
Cache-Control: public, max-age=3600, must-revalidate
```

## Accessibility

- WCAG 2.1 AA compliant
- Keyboard navigation (Tab, Enter, Escape)
- Skip to main content link
- Proper heading hierarchy
- ARIA labels for interactive elements
- Alt text for all images
- Color contrast ratio > 4.5:1
- Focus visible on all interactive elements

### Keyboard Shortcuts

- Tab: Navigate between elements
- Enter/Space: Activate buttons/links
- Escape: Close mobile menu
- Alt+M: Skip to main content

## Analytics Integration

Add Google Analytics:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_ID');
</script>
```

## Form Handling

Contact form posts to `/api/contact` endpoint. Requires backend implementation:

```json
{
  "name": "string",
  "email": "email",
  "subject": "string",
  "message": "string"
}
```

Response:
```json
{
  "success": true,
  "message": "Thank you for your message"
}
```

## Email Notifications

Forms can be integrated with:
- Sendgrid
- Mailgun
- AWS SES
- Firebase Cloud Functions

## Lighthouse Checklist

Target scores:
- Performance: > 90
- SEO: > 90
- Accessibility: > 90
- Best Practices: > 90
- PWA: Installable

Run audit:
```bash
# Chrome DevTools (F12)
# Lighthouse tab

# Or via CLI
npm install -g lighthouse
lighthouse https://famquest.app
```

## Content Calendar

Blog topics planned:
1. Eerlijke taakverdeling in het gezin
2. Kinderen motiveren zonder geld
3. AI plannen - hoe het werkt
4. Tips voor gamification
5. Work-life balance family edition
6. Opvoedingstips
7. Product updates
8. Feature guides
9. Customer stories
10. Best practices

## Language Support

Currently Dutch (nl) is primary.

To add English (en):
1. Create `/en/index.html`
2. Update hreflang tags
3. Create `/sitemap-en.xml`
4. Add language selector (optional)

```html
<link rel="alternate" hreflang="en" href="https://famquest.app/en/">
<link rel="alternate" hreflang="nl" href="https://famquest.app/">
```

## Maintenance

### Regular Tasks

- Monitor Core Web Vitals (weekly)
- Check search console (weekly)
- Update blog content (bi-weekly)
- Review analytics (monthly)
- Audit links (quarterly)
- Update dependencies (monthly)
- Security patches (as needed)

### Tools

- Google Search Console
- Google PageSpeed Insights
- Lighthouse
- Screaming Frog SEO Spider
- Google Analytics 4
- Hotjar (optional)

## Support & Issues

For issues or questions:
- GitHub Issues: [link]
- Email: support@famquest.app
- Twitter: @famquest

## License

Copyright © 2025 FamQuest. All rights reserved.

## Version History

- v1.0.0 (2025-01-15): Initial launch
  - 7 main pages
  - Mobile-responsive design
  - SEO optimization
  - PWA support
  - Service Worker
  - Accessibility WCAG 2.1 AA

---

Last updated: 2025-01-15
