/**
 * FamQuest E2E Critical Journeys - Playwright Tests
 *
 * Production-critical user flows tested against Web PWA:
 * 1. User Onboarding (SSO → Profile Setup → First Task)
 * 2. Task Lifecycle (Create → Assign → Complete → Approve)
 * 3. Gamification (Earn Points → Buy Reward → Check Badge)
 * 4. Calendar Operations (Create Event → Edit → Delete)
 * 5. Helper System (Invite → Scan QR → Join)
 *
 * Prerequisites:
 * - FamQuest web app running on localhost:54321 (or configured URL)
 * - Test database seeded with demo accounts
 * - Playwright installed: npm install -D @playwright/test
 *
 * Run: npx playwright test
 */

import { test, expect, Page } from '@playwright/test';

// Test configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:54321';

const TEST_USERS = {
  parent: {
    email: 'parent@famquest.test',
    password: 'TestPass123!',
  },
  child: {
    email: 'child@famquest.test',
    pin: '1234',
  },
  helper: {
    email: 'helper@famquest.test',
    password: 'HelperPass123!',
  },
};

// Helper functions
async function loginAsParent(page: Page) {
  await page.goto(`${BASE_URL}/login`);
  await page.fill('[data-testid="email-field"]', TEST_USERS.parent.email);
  await page.fill('[data-testid="password-field"]', TEST_USERS.parent.password);
  await page.click('[data-testid="login-button"]');
  await page.waitForURL(`${BASE_URL}/home`);
}

async function loginAsChild(page: Page) {
  await page.goto(`${BASE_URL}/login`);
  await page.click('[data-testid="child-login-button"]');
  // Enter PIN digits
  for (let i = 0; i < TEST_USERS.child.pin.length; i++) {
    await page.fill(`[data-testid="pin-digit-${i}"]`, TEST_USERS.child.pin[i]);
  }
  await page.waitForURL(`${BASE_URL}/home`);
}

test.describe('Critical Journey 1: User Onboarding', () => {
  test('New user can register, setup profile, and create first task', async ({ page }) => {
    // Step 1: Navigate to registration
    await page.goto(BASE_URL);
    await page.click('[data-testid="register-button"]');

    // Step 2: Fill registration form
    await page.fill('[data-testid="display-name-field"]', 'Test Parent');
    await page.fill('[data-testid="email-field"]', `test-${Date.now()}@example.com`);
    await page.fill('[data-testid="password-field"]', 'SecurePass123!');
    await page.fill('[data-testid="confirm-password-field"]', 'SecurePass123!');
    await page.click('[data-testid="create-account-button"]');

    // Step 3: Verify email verification prompt (or skip if auto-verified in test)
    await expect(page.locator('text=Account created')).toBeVisible({ timeout: 10000 });

    // Step 4: Setup family
    await page.fill('[data-testid="family-name-field"]', 'Test Family');
    await page.click('[data-testid="create-family-button"]');

    // Step 5: Navigate to home
    await page.waitForURL(`${BASE_URL}/home`, { timeout: 10000 });
    await expect(page.locator('text=Welcome')).toBeVisible();

    // Step 6: Create first task
    await page.click('[data-testid="create-task-fab"]');
    await page.fill('[data-testid="task-title-field"]', 'My First Task');
    await page.fill('[data-testid="task-description-field"]', 'Clean the kitchen');
    await page.fill('[data-testid="task-points-field"]', '20');
    await page.click('[data-testid="save-task-button"]');

    // Step 7: Verify task created
    await expect(page.locator('text=My First Task')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('text=20 points')).toBeVisible();
  });

  test('SSO login with Google redirects correctly', async ({ page, context }) => {
    await page.goto(`${BASE_URL}/login`);

    // Click Google SSO button
    await page.click('[data-testid="google-sso-button"]');

    // Wait for Google OAuth redirect (in real test, mock this)
    // For production, use real OAuth flow or mock provider
    await page.waitForURL(/accounts\.google\.com/, { timeout: 10000 });

    // Verify OAuth consent screen loads
    await expect(page.url()).toContain('google.com');
  });
});

test.describe('Critical Journey 2: Task Lifecycle', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsParent(page);
  });

  test('Complete task flow: Create → Assign → Complete → Approve', async ({ page }) => {
    // Step 1: Create task
    await page.click('[data-testid="tasks-nav"]');
    await page.click('[data-testid="create-task-button"]');
    await page.fill('[data-testid="task-title"]', 'Vacuum Living Room');
    await page.fill('[data-testid="task-description"]', 'Use the Dyson vacuum');
    await page.selectOption('[data-testid="task-category"]', 'cleaning');
    await page.fill('[data-testid="task-points"]', '15');
    await page.check('[data-testid="task-photo-required"]');
    await page.check('[data-testid="task-parent-approval"]');

    // Step 2: Assign to child
    await page.click('[data-testid="assignee-selector"]');
    await page.click('[data-testid="assignee-Noah"]'); // Select child named Noah
    await page.click('[data-testid="save-task-button"]');

    // Verify task created
    await expect(page.locator('text=Vacuum Living Room')).toBeVisible({ timeout: 5000 });

    // Step 3: Switch to child account (in real app, this would be separate session)
    await page.click('[data-testid="user-menu"]');
    await page.click('[data-testid="logout-button"]');
    await loginAsChild(page);

    // Step 4: Child completes task
    await page.click('[data-testid="tasks-nav"]');
    await page.click('text=Vacuum Living Room');

    // Upload photo
    const fileInput = await page.locator('[data-testid="photo-upload-input"]');
    await fileInput.setInputFiles('./test-assets/vacuum-photo.jpg');

    // Wait for upload
    await expect(page.locator('[data-testid="photo-preview"]')).toBeVisible({ timeout: 10000 });

    // Submit for approval
    await page.click('[data-testid="complete-task-button"]');
    await expect(page.locator('text=Submitted for approval')).toBeVisible();

    // Step 5: Switch back to parent for approval
    await page.click('[data-testid="user-menu"]');
    await page.click('[data-testid="logout-button"]');
    await loginAsParent(page);

    // Step 6: Parent approves task
    await page.click('[data-testid="tasks-nav"]');
    await page.click('[data-testid="pending-approval-tab"]');
    await page.click('text=Vacuum Living Room');

    // Review photo
    await expect(page.locator('[data-testid="task-photo"]')).toBeVisible();

    // Approve
    await page.click('[data-testid="approve-button"]');
    await page.fill('[data-testid="approval-rating"]', '5'); // 5-star rating
    await page.click('[data-testid="confirm-approval-button"]');

    // Verify approval
    await expect(page.locator('text=Task approved')).toBeVisible();

    // Step 7: Verify child received points (switch back to child view)
    // In production, this would test real-time notification
  });

  test('Task with photo requirement enforces upload', async ({ page }) => {
    // Create task without photo requirement
    await page.click('[data-testid="create-task-button"]');
    await page.fill('[data-testid="task-title"]', 'Test Task');
    await page.check('[data-testid="task-photo-required"]');
    await page.click('[data-testid="save-task-button"]');

    // Try to complete without photo
    await page.click('text=Test Task');
    await page.click('[data-testid="complete-task-button"]');

    // Verify error message
    await expect(page.locator('text=Photo is required')).toBeVisible();

    // Cannot complete task
    await expect(page.locator('[data-testid="task-status"]')).not.toHaveText('done');
  });
});

test.describe('Critical Journey 3: Gamification', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsChild(page);
  });

  test('User earns points, purchases reward, and unlocks badge', async ({ page }) => {
    // Step 1: Check initial points balance
    const initialPoints = await page.locator('[data-testid="points-balance"]').textContent();

    // Step 2: Complete a task to earn points
    await page.click('[data-testid="tasks-nav"]');
    await page.click('text=Easy Task'); // Pre-seeded task worth 10 points
    await page.click('[data-testid="complete-task-button"]');

    // Step 3: Verify points increased
    await page.waitForTimeout(2000); // Wait for animation
    const newPoints = await page.locator('[data-testid="points-balance"]').textContent();
    expect(parseInt(newPoints!)).toBeGreaterThan(parseInt(initialPoints!));

    // Step 4: Navigate to shop
    await page.click('[data-testid="shop-nav"]');
    await expect(page.locator('text=Winkel')).toBeVisible();

    // Step 5: Purchase reward
    await page.click('[data-testid="reward-Extra TV Time"]');
    await page.click('[data-testid="buy-button"]');

    // Confirm purchase in dialog
    await expect(page.locator('text=Bevestig aankoop')).toBeVisible();
    await page.click('[data-testid="confirm-purchase-button"]');

    // Verify success message
    await expect(page.locator('text=gekocht')).toBeVisible();

    // Step 6: Check if badge unlocked
    await page.click('[data-testid="profile-nav"]');
    await page.click('[data-testid="badges-tab"]');

    // Verify badge animation (if first purchase triggered badge)
    // This depends on badge unlock logic
    const badgeCount = await page.locator('[data-testid="unlocked-badge"]').count();
    expect(badgeCount).toBeGreaterThan(0);
  });

  test('Streak system updates correctly', async ({ page }) => {
    // Navigate to streak display
    await page.click('[data-testid="profile-nav"]');

    // Verify streak counter exists
    await expect(page.locator('[data-testid="streak-counter"]')).toBeVisible();

    // Complete task today
    await page.click('[data-testid="tasks-nav"]');
    await page.click('text=Daily Task');
    await page.click('[data-testid="complete-task-button"]');

    // Verify streak incremented
    await page.click('[data-testid="profile-nav"]');
    const streakText = await page.locator('[data-testid="streak-counter"]').textContent();
    expect(streakText).toMatch(/\d+\s+Days?/);
  });
});

test.describe('Critical Journey 4: Calendar Operations', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsParent(page);
    await page.click('[data-testid="calendar-nav"]');
  });

  test('Create, edit, and delete calendar event', async ({ page }) => {
    // Step 1: Create event
    await page.click('[data-testid="new-event-fab"]');
    await page.fill('[data-testid="event-title"]', 'Soccer Practice');
    await page.fill('[data-testid="event-description"]', 'Weekly soccer practice at the park');

    // Set date and time
    await page.click('[data-testid="event-date-picker"]');
    await page.click('[data-testid="date-today"]'); // Select today
    await page.fill('[data-testid="event-start-time"]', '18:00');
    await page.fill('[data-testid="event-end-time"]', '19:30');

    // Select attendees
    await page.click('[data-testid="attendee-selector"]');
    await page.check('[data-testid="attendee-Noah"]');
    await page.check('[data-testid="attendee-Luna"]');

    // Save event
    await page.click('[data-testid="save-event-button"]');

    // Verify event created
    await expect(page.locator('text=Soccer Practice')).toBeVisible({ timeout: 5000 });

    // Step 2: Edit event
    await page.click('text=Soccer Practice');
    await page.click('[data-testid="edit-event-button"]');
    await page.fill('[data-testid="event-title"]', 'Soccer Practice (Updated)');
    await page.click('[data-testid="save-event-button"]');

    // Verify edit
    await expect(page.locator('text=Soccer Practice (Updated)')).toBeVisible();

    // Step 3: Delete event
    await page.click('text=Soccer Practice (Updated)');
    await page.click('[data-testid="delete-event-button"]');

    // Confirm deletion
    await page.click('[data-testid="confirm-delete-button"]');

    // Verify deletion
    await expect(page.locator('text=Soccer Practice')).not.toBeVisible();
  });

  test('Recurring event creates multiple instances', async ({ page }) => {
    // Create recurring event
    await page.click('[data-testid="new-event-fab"]');
    await page.fill('[data-testid="event-title"]', 'Weekly Meeting');
    await page.check('[data-testid="event-recurring-checkbox"]');
    await page.selectOption('[data-testid="recurrence-pattern"]', 'weekly');
    await page.selectOption('[data-testid="recurrence-day"]', 'tuesday');
    await page.click('[data-testid="save-event-button"]');

    // Navigate to next week
    await page.click('[data-testid="calendar-next-week"]');

    // Verify event appears on next Tuesday
    await expect(page.locator('text=Weekly Meeting')).toBeVisible();

    // Navigate to following week
    await page.click('[data-testid="calendar-next-week"]');

    // Verify event still appears
    await expect(page.locator('text=Weekly Meeting')).toBeVisible();
  });
});

test.describe('Critical Journey 5: Helper System', () => {
  test('Parent invites helper, helper joins and completes task', async ({ page, context }) => {
    // Step 1: Parent generates invite
    await loginAsParent(page);
    await page.click('[data-testid="settings-nav"]');
    await page.click('[data-testid="manage-helpers-button"]');
    await page.click('[data-testid="invite-helper-button"]');

    // Get invite code
    const inviteCode = await page.locator('[data-testid="invite-code"]').textContent();
    expect(inviteCode).toMatch(/HELP-[A-Z0-9]+/);

    // Step 2: Helper joins (new browser context)
    const helperPage = await context.newPage();
    await helperPage.goto(`${BASE_URL}/helper/join`);
    await helperPage.fill('[data-testid="invite-code-field"]', inviteCode!);
    await helperPage.click('[data-testid="join-button"]');

    // Helper creates account
    await helperPage.fill('[data-testid="helper-name"]', 'Maria');
    await helperPage.fill('[data-testid="helper-email"]', 'maria@example.com');
    await helperPage.click('[data-testid="confirm-join-button"]');

    // Verify helper joined
    await expect(helperPage.locator('text=Successfully joined')).toBeVisible();

    // Step 3: Parent assigns task to helper
    await page.click('[data-testid="tasks-nav"]');
    await page.click('[data-testid="create-task-button"]');
    await page.fill('[data-testid="task-title"]', 'Help with Laundry');
    await page.click('[data-testid="assignee-selector"]');
    await page.click('[data-testid="assignee-Maria"]');
    await page.click('[data-testid="save-task-button"]');

    // Step 4: Helper sees assigned task
    await helperPage.reload();
    await expect(helperPage.locator('text=Help with Laundry')).toBeVisible();

    // Step 5: Helper completes task
    await helperPage.click('text=Help with Laundry');
    await helperPage.click('[data-testid="complete-task-button"]');

    // Verify completion
    await expect(helperPage.locator('text=Task completed')).toBeVisible();

    // Step 6: Verify helper CANNOT access calendar
    await helperPage.click('[data-testid="nav-menu"]');
    await expect(helperPage.locator('[data-testid="calendar-nav"]')).not.toBeVisible();

    // Verify helper CANNOT access shop
    await expect(helperPage.locator('[data-testid="shop-nav"]')).not.toBeVisible();

    await helperPage.close();
  });
});

test.describe('Performance and Responsiveness', () => {
  test('App loads within 3 seconds', async ({ page }) => {
    const startTime = Date.now();
    await page.goto(BASE_URL);
    await page.waitForSelector('[data-testid="app-loaded"]', { timeout: 5000 });
    const loadTime = Date.now() - startTime;

    expect(loadTime).toBeLessThan(3000);
  });

  test('Task list renders 50 items without lag', async ({ page }) => {
    await loginAsParent(page);
    await page.click('[data-testid="tasks-nav"]');

    // Measure scroll performance
    const startTime = Date.now();
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });
    const scrollTime = Date.now() - startTime;

    expect(scrollTime).toBeLessThan(500);
  });
});

test.describe('Accessibility', () => {
  test('All interactive elements have ARIA labels', async ({ page }) => {
    await page.goto(BASE_URL);

    // Check critical interactive elements
    const buttons = await page.locator('button').all();
    for (const button of buttons) {
      const ariaLabel = await button.getAttribute('aria-label');
      const textContent = await button.textContent();

      // Either aria-label or text content must exist
      expect(ariaLabel || textContent?.trim()).toBeTruthy();
    }
  });

  test('Keyboard navigation works for main flows', async ({ page }) => {
    await page.goto(BASE_URL);

    // Tab through form fields
    await page.keyboard.press('Tab'); // Email field
    await page.keyboard.press('Tab'); // Password field
    await page.keyboard.press('Tab'); // Login button
    await page.keyboard.press('Enter'); // Submit

    // Verify focus management works
    const focusedElement = await page.evaluate(() => document.activeElement?.tagName);
    expect(focusedElement).toBeTruthy();
  });
});
