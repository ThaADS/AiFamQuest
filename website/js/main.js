/**
 * FamQuest Marketing Website - Main JavaScript
 * Handles navigation, tracking, and interactive features
 */

// ========================================
// Mobile Menu Toggle
// ========================================

const hamburger = document.getElementById('hamburger');
const navMenu = document.getElementById('nav-menu');

if (hamburger && navMenu) {
  hamburger.addEventListener('click', function() {
    const isExpanded = hamburger.getAttribute('aria-expanded') === 'true';
    hamburger.setAttribute('aria-expanded', !isExpanded);
    navMenu.classList.toggle('active');
  });

  // Close menu when a link is clicked
  const navLinks = navMenu.querySelectorAll('a');
  navLinks.forEach(link => {
    link.addEventListener('click', function() {
      hamburger.setAttribute('aria-expanded', 'false');
      navMenu.classList.remove('active');
    });
  });

  // Close menu when clicking outside
  document.addEventListener('click', function(event) {
    if (!event.target.closest('.nav')) {
      hamburger.setAttribute('aria-expanded', 'false');
      navMenu.classList.remove('active');
    }
  });
}

// ========================================
// Smooth Scroll for Anchor Links
// ========================================

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const href = this.getAttribute('href');

    // Skip if it's just '#' or navigation toggle
    if (href === '#' || href === '') {
      return;
    }

    e.preventDefault();
    const target = document.querySelector(href);

    if (target) {
      const offsetTop = target.offsetTop - 80; // Account for sticky header
      window.scrollTo({
        top: offsetTop,
        behavior: 'smooth'
      });
    }
  });
});

// ========================================
// CTA Tracking
// ========================================

/**
 * Track CTA clicks for analytics
 */
function trackCTAClick(event) {
  const ctaName = event.target.getAttribute('data-cta');

  if (ctaName && typeof window.gtag !== 'undefined') {
    window.gtag('event', 'cta_click', {
      cta_name: ctaName,
      cta_destination: event.target.href,
      cta_text: event.target.innerText
    });
  }

  // Local storage tracking as fallback
  const clicks = JSON.parse(localStorage.getItem('cta_clicks') || '{}');
  clicks[ctaName] = (clicks[ctaName] || 0) + 1;
  localStorage.setItem('cta_clicks', JSON.stringify(clicks));
}

// Track all CTA buttons
document.querySelectorAll('[data-cta]').forEach(button => {
  button.addEventListener('click', trackCTAClick);
});

// ========================================
// Intersection Observer for Lazy Loading
// ========================================

/**
 * Animate elements as they come into view
 */
if ('IntersectionObserver' in window) {
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const observer = new IntersectionObserver(function(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animate-fade-in');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  // Observe animatable elements
  document.querySelectorAll('.prop-card, .feature-card, .testimonial-card, .stat').forEach(el => {
    observer.observe(el);
  });
}

// ========================================
// Form Handling (if contact form exists)
// ========================================

const contactForm = document.querySelector('[data-form="contact"]');
if (contactForm) {
  contactForm.addEventListener('submit', async function(e) {
    e.preventDefault();

    const formData = new FormData(contactForm);
    const data = Object.fromEntries(formData);

    try {
      // Send to API endpoint
      const response = await fetch('/api/contact', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data)
      });

      if (response.ok) {
        showNotification('Dank je wel! We nemen snel contact met je op.', 'success');
        contactForm.reset();
      } else {
        showNotification('Er is iets misgegaan. Probeer het later opnieuw.', 'error');
      }
    } catch (error) {
      console.error('Form submission error:', error);
      showNotification('Er is iets misgegaan. Probeer het later opnieuw.', 'error');
    }
  });
}

// ========================================
// Notification System
// ========================================

/**
 * Show a notification message
 * @param {string} message - The message to display
 * @param {string} type - 'success', 'error', 'info', or 'warning'
 */
function showNotification(message, type = 'info') {
  const notification = document.createElement('div');
  notification.className = `notification notification-${type}`;
  notification.setAttribute('role', 'alert');
  notification.textContent = message;

  // Add styles if not already in CSS
  Object.assign(notification.style, {
    position: 'fixed',
    bottom: '20px',
    right: '20px',
    padding: '16px 24px',
    borderRadius: '8px',
    backgroundColor: type === 'success' ? '#10B981' :
                     type === 'error' ? '#EF4444' :
                     type === 'warning' ? '#F59E0B' : '#3B82F6',
    color: 'white',
    zIndex: '1000',
    maxWidth: '300px',
    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
    animation: 'slideIn 0.3s ease-out'
  });

  document.body.appendChild(notification);

  // Auto-remove after 4 seconds
  setTimeout(() => {
    notification.style.animation = 'slideOut 0.3s ease-out';
    setTimeout(() => {
      notification.remove();
    }, 300);
  }, 4000);
}

// ========================================
// Performance Monitoring
// ========================================

/**
 * Log Core Web Vitals
 */
if ('web-vital' in window || 'PerformanceObserver' in window) {
  // Log page load time
  window.addEventListener('load', function() {
    const perfData = window.performance.timing;
    const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;

    if (typeof window.gtag !== 'undefined') {
      window.gtag('event', 'page_load', {
        page_load_time: pageLoadTime
      });
    }

    console.log('Page load time:', pageLoadTime + 'ms');
  });

  // Measure Largest Contentful Paint (LCP)
  if ('PerformanceObserver' in window) {
    try {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (typeof window.gtag !== 'undefined') {
            window.gtag('event', 'LCP', {
              value: Math.round(entry.renderTime || entry.loadTime),
              event_category: 'web_vitals',
              event_label: 'LCP'
            });
          }
        }
      });

      observer.observe({ entryTypes: ['largest-contentful-paint'] });
    } catch (e) {
      console.log('LCP observer not supported');
    }
  }
}

// ========================================
// Service Worker Registration (PWA Support)
// ========================================

/**
 * Register service worker for offline support
 */
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function() {
    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        console.log('Service Worker registered:', registration);
      })
      .catch(error => {
        console.log('Service Worker registration failed:', error);
      });
  });
}

// ========================================
// Accessibility Enhancements
// ========================================

/**
 * Handle keyboard navigation
 */
document.addEventListener('keydown', function(e) {
  // Close menu on Escape
  if (e.key === 'Escape' && navMenu && navMenu.classList.contains('active')) {
    hamburger.setAttribute('aria-expanded', 'false');
    navMenu.classList.remove('active');
  }

  // Skip to main content on Alt+M
  if (e.altKey && e.key === 'm') {
    const mainContent = document.getElementById('main-content');
    if (mainContent) {
      mainContent.focus();
      mainContent.scrollIntoView({ behavior: 'smooth' });
    }
  }
});

// ========================================
// Language Detection (if multilingual support)
// ========================================

/**
 * Detect user language and optionally redirect
 */
function detectLanguage() {
  const supportedLanguages = ['nl', 'en', 'de', 'fr'];
  const userLanguage = (navigator.language || navigator.userLanguage).split('-')[0];
  const currentPath = window.location.pathname;

  // If user is on root and prefers English, optionally suggest redirect
  if (currentPath === '/' && supportedLanguages.includes(userLanguage) && userLanguage !== 'nl') {
    // Could show a language selector or auto-redirect
    // For now, just log it
    console.log('Detected user language:', userLanguage);
  }

  return userLanguage;
}

// ========================================
// Dynamic Content Loading
// ========================================

/**
 * Load external content (e.g., blog posts, testimonials)
 */
async function loadContent(url, targetSelector) {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error('Content loading failed');

    const html = await response.text();
    const target = document.querySelector(targetSelector);

    if (target) {
      target.innerHTML = html;
    }
  } catch (error) {
    console.error('Error loading content:', error);
  }
}

// ========================================
// Analytics Initialization
// ========================================

/**
 * Initialize Google Analytics (if needed)
 */
function initAnalytics() {
  // Google Analytics would be loaded via <script> tag in HTML
  // This function is a placeholder for additional initialization

  if (typeof window.gtag === 'function') {
    // Set default parameters
    window.gtag('config', 'GA_MEASUREMENT_ID', {
      'page_title': document.title,
      'page_location': window.location.href
    });

    // Track page view
    window.gtag('event', 'page_view');
  }
}

// ========================================
// Utility Functions
// ========================================

/**
 * Debounce function for optimized event handling
 */
function debounce(func, delay) {
  let timeoutId;
  return function(...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => func.apply(this, args), delay);
  };
}

/**
 * Throttle function for optimized event handling
 */
function throttle(func, limit) {
  let inThrottle;
  return function(...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

/**
 * Add animation class to elements
 */
function animateOnScroll() {
  const elements = document.querySelectorAll('[data-animate]');

  elements.forEach(el => {
    el.classList.add('animate-fade-in');
  });
}

/**
 * Get device type
 */
function getDeviceType() {
  const userAgent = navigator.userAgent;
  if (/mobile|android|iphone|ipad|phone/i.test(userAgent)) {
    return 'mobile';
  } else if (/tablet|ipad/i.test(userAgent)) {
    return 'tablet';
  }
  return 'desktop';
}

// ========================================
// Initialize on DOM Ready
// ========================================

document.addEventListener('DOMContentLoaded', function() {
  // Initialize features
  detectLanguage();
  animateOnScroll();

  // Log device type for analytics
  const deviceType = getDeviceType();
  if (typeof window.gtag !== 'undefined') {
    window.gtag('event', 'device_type', {
      device: deviceType
    });
  }

  console.log('FamQuest website initialized');
  console.log('Device type:', deviceType);
});

// ========================================
// Handle Page Visibility (pause animations on hidden)
// ========================================

document.addEventListener('visibilitychange', function() {
  if (document.hidden) {
    // Page is hidden - pause animations if needed
    console.log('Page is hidden');
  } else {
    // Page is visible again
    console.log('Page is visible');
  }
});

// ========================================
// Unload Handler (track session end if needed)
// ========================================

window.addEventListener('beforeunload', function() {
  // Could send session data to analytics
  if (typeof window.gtag !== 'undefined') {
    const sessionDuration = Math.round((Date.now() - window.pageLoadTime) / 1000);
    window.gtag('event', 'session_end', {
      session_duration: sessionDuration
    });
  }
});

// Store page load time for session duration calculation
window.pageLoadTime = Date.now();

// ========================================
// Export for testing (if using modules)
// ========================================

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    showNotification,
    trackCTAClick,
    debounce,
    throttle,
    getDeviceType
  };
}
