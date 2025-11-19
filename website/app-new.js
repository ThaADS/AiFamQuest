// FamQuest Marketing Website JavaScript
// Interactions, animations, and conversions

(function() {
  'use strict';

  // ============================================
  // Mobile Navigation Toggle
  // ============================================

  function initMobileNav() {
    const navToggle = document.querySelector('.nav-toggle');
    const navLinks = document.querySelector('.nav-links');

    if (navToggle && navLinks) {
      navToggle.addEventListener('click', () => {
        navLinks.classList.toggle('active');
        navToggle.classList.toggle('active');
        navToggle.setAttribute(
          'aria-expanded',
          navToggle.classList.contains('active')
        );
      });

      // Close menu when clicking nav links
      const links = navLinks.querySelectorAll('a');
      links.forEach(link => {
        link.addEventListener('click', () => {
          navLinks.classList.remove('active');
          navToggle.classList.remove('active');
          navToggle.setAttribute('aria-expanded', 'false');
        });
      });

      // Close menu on escape key
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && navLinks.classList.contains('active')) {
          navLinks.classList.remove('active');
          navToggle.classList.remove('active');
          navToggle.setAttribute('aria-expanded', 'false');
        }
      });
    }
  }

  // ============================================
  // Smooth Scroll
  // ============================================

  function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
          const offset = 80; // Nav height + padding
          const targetPosition = target.offsetTop - offset;
          window.scrollTo({
            top: targetPosition,
            behavior: 'smooth'
          });
        }
      });
    });
  }

  // ============================================
  // FAQ Accordion
  // ============================================

  function initFAQ() {
    const faqQuestions = document.querySelectorAll('.faq-question');

    faqQuestions.forEach(question => {
      question.addEventListener('click', () => {
        const faqItem = question.parentElement;
        const answer = faqItem.querySelector('.faq-answer');
        const icon = question.querySelector('.faq-icon');

        // Toggle active state
        const isActive = faqItem.classList.contains('active');

        // Close all FAQ items
        document.querySelectorAll('.faq-item').forEach(item => {
          item.classList.remove('active');
          item.querySelector('.faq-answer').style.maxHeight = null;
        });

        // Open clicked item if it wasn't active
        if (!isActive) {
          faqItem.classList.add('active');
          answer.style.maxHeight = answer.scrollHeight + 'px';
        }
      });
    });
  }

  // ============================================
  // Gamification Tabs
  // ============================================

  function initGamificationTabs() {
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    tabButtons.forEach(button => {
      button.addEventListener('click', () => {
        const targetTab = button.dataset.tab;

        // Remove active class from all buttons and contents
        tabButtons.forEach(btn => btn.classList.remove('active'));
        tabContents.forEach(content => content.classList.remove('active'));

        // Add active class to clicked button and corresponding content
        button.classList.add('active');
        document.querySelector(`[data-tab-content="${targetTab}"]`).classList.add('active');
      });
    });
  }

  // ============================================
  // Scroll Animations (Intersection Observer)
  // ============================================

  function initScrollAnimations() {
    const observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -100px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('animate-in');
          observer.unobserve(entry.target);
        }
      });
    }, observerOptions);

    // Observe all cards and sections
    const animateElements = document.querySelectorAll(
      '.problem-card, .feature-block, .testimonial-card, .pricing-card'
    );

    animateElements.forEach(el => {
      el.classList.add('animate-on-scroll');
      observer.observe(el);
    });
  }

  // ============================================
  // CTA Tracking (Analytics)
  // ============================================

  function initCTATracking() {
    const ctaButtons = document.querySelectorAll('[data-cta]');

    ctaButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        const ctaName = button.dataset.cta;

        // Track with Google Analytics if available
        if (typeof gtag !== 'undefined') {
          gtag('event', 'cta_click', {
            'event_category': 'engagement',
            'event_label': ctaName,
            'value': 1
          });
        }

        // Track with console for development
        console.log('CTA clicked:', ctaName);
      });
    });
  }

  // ============================================
  // Hero Animation
  // ============================================

  function initHeroAnimation() {
    const heroContent = document.querySelector('.hero-content');
    const heroImage = document.querySelector('.hero-image');

    if (heroContent && heroImage) {
      // Animate in on page load
      setTimeout(() => {
        heroContent.style.opacity = '1';
        heroContent.style.transform = 'translateY(0)';
      }, 100);

      setTimeout(() => {
        heroImage.style.opacity = '1';
        heroImage.style.transform = 'translateY(0)';
      }, 300);
    }
  }

  // ============================================
  // Sticky Nav Background
  // ============================================

  function initStickyNav() {
    const nav = document.querySelector('.nav');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
      const currentScroll = window.pageYOffset;

      // Add shadow when scrolled
      if (currentScroll > 10) {
        nav.classList.add('scrolled');
      } else {
        nav.classList.remove('scrolled');
      }

      lastScroll = currentScroll;
    });
  }

  // ============================================
  // Form Validation (if present)
  // ============================================

  function initFormValidation() {
    const forms = document.querySelectorAll('form[data-validate]');

    forms.forEach(form => {
      form.addEventListener('submit', (e) => {
        e.preventDefault();

        const email = form.querySelector('input[type="email"]');

        if (email && !isValidEmail(email.value)) {
          showError(email, 'Vul een geldig e-mailadres in');
          return;
        }

        // Submit form (replace with actual submission logic)
        console.log('Form submitted:', new FormData(form));
        form.reset();
        showSuccess(form, 'Bedankt! We nemen contact met je op.');
      });
    });
  }

  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  function showError(input, message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'form-error';
    errorDiv.textContent = message;

    input.classList.add('error');
    input.parentElement.appendChild(errorDiv);

    setTimeout(() => {
      errorDiv.remove();
      input.classList.remove('error');
    }, 3000);
  }

  function showSuccess(form, message) {
    const successDiv = document.createElement('div');
    successDiv.className = 'form-success';
    successDiv.textContent = message;

    form.appendChild(successDiv);

    setTimeout(() => {
      successDiv.remove();
    }, 5000);
  }

  // ============================================
  // Cookie Consent (GDPR/AVG)
  // ============================================

  function initCookieConsent() {
    const cookieConsent = localStorage.getItem('famquest-cookie-consent');

    if (!cookieConsent) {
      showCookieBanner();
    }
  }

  function showCookieBanner() {
    const banner = document.createElement('div');
    banner.className = 'cookie-banner';
    banner.innerHTML = `
      <div class="cookie-content">
        <p>We gebruiken cookies om je ervaring te verbeteren. Door verder te gaan, ga je akkoord met ons <a href="/privacy">privacybeleid</a>.</p>
        <div class="cookie-actions">
          <button class="btn btn-primary btn-accept-cookies">Accepteren</button>
          <button class="btn btn-secondary btn-reject-cookies">Weigeren</button>
        </div>
      </div>
    `;

    document.body.appendChild(banner);

    // Accept cookies
    banner.querySelector('.btn-accept-cookies').addEventListener('click', () => {
      localStorage.setItem('famquest-cookie-consent', 'accepted');
      banner.remove();
      enableAnalytics();
    });

    // Reject cookies
    banner.querySelector('.btn-reject-cookies').addEventListener('click', () => {
      localStorage.setItem('famquest-cookie-consent', 'rejected');
      banner.remove();
    });
  }

  function enableAnalytics() {
    // Enable Google Analytics or other tracking
    console.log('Analytics enabled');
  }

  // ============================================
  // Performance: Lazy Load Images
  // ============================================

  function initLazyLoad() {
    if ('loading' in HTMLImageElement.prototype) {
      // Native lazy loading supported
      const images = document.querySelectorAll('img[loading="lazy"]');
      images.forEach(img => {
        img.src = img.dataset.src || img.src;
      });
    } else {
      // Fallback for older browsers
      const script = document.createElement('script');
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/lazysizes/5.3.2/lazysizes.min.js';
      document.body.appendChild(script);
    }
  }

  // ============================================
  // Easter Egg: Konami Code
  // ============================================

  function initEasterEgg() {
    const konamiCode = ['ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight', 'KeyB', 'KeyA'];
    let konamiIndex = 0;

    document.addEventListener('keydown', (e) => {
      if (e.code === konamiCode[konamiIndex]) {
        konamiIndex++;

        if (konamiIndex === konamiCode.length) {
          activateEasterEgg();
          konamiIndex = 0;
        }
      } else {
        konamiIndex = 0;
      }
    });
  }

  function activateEasterEgg() {
    // Add confetti or special message
    const message = document.createElement('div');
    message.className = 'easter-egg-message';
    message.textContent = '🎉 Gefeliciteerd! Je hebt de Konami Code gevonden! Jij bent echt een regeltante-pro!';
    document.body.appendChild(message);

    setTimeout(() => {
      message.remove();
    }, 5000);
  }

  // ============================================
  // Initialize All
  // ============================================

  function init() {
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', init);
      return;
    }

    // Initialize modules
    initMobileNav();
    initSmoothScroll();
    initFAQ();
    initGamificationTabs();
    initScrollAnimations();
    initCTATracking();
    initHeroAnimation();
    initStickyNav();
    initFormValidation();
    initCookieConsent();
    initLazyLoad();
    initEasterEgg();

    console.log('FamQuest website initialized 🎯');
  }

  // Run initialization
  init();

})();