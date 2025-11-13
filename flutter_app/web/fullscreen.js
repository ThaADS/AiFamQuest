/**
 * Fullscreen API for kiosk mode
 *
 * Provides cross-browser fullscreen functionality for Flutter web kiosk displays.
 * Supports all modern browsers with vendor prefixes.
 */

/**
 * Request fullscreen mode on the document element
 */
function requestFullscreenJS() {
  const elem = document.documentElement;

  if (elem.requestFullscreen) {
    elem.requestFullscreen();
  } else if (elem.webkitRequestFullscreen) {
    // Safari
    elem.webkitRequestFullscreen();
  } else if (elem.mozRequestFullScreen) {
    // Firefox
    elem.mozRequestFullScreen();
  } else if (elem.msRequestFullscreen) {
    // IE/Edge
    elem.msRequestFullscreen();
  }
}

/**
 * Exit fullscreen mode
 */
function exitFullscreenJS() {
  if (document.exitFullscreen) {
    document.exitFullscreen();
  } else if (document.webkitExitFullscreen) {
    // Safari
    document.webkitExitFullscreen();
  } else if (document.mozCancelFullScreen) {
    // Firefox
    document.mozCancelFullScreen();
  } else if (document.msExitFullscreen) {
    // IE/Edge
    document.msExitFullscreen();
  }
}

/**
 * Check if currently in fullscreen mode
 * @returns {boolean} True if in fullscreen, false otherwise
 */
function isFullscreenJS() {
  return !!(
    document.fullscreenElement ||
    document.webkitFullscreenElement ||
    document.mozFullScreenElement ||
    document.msFullscreenElement
  );
}

/**
 * Toggle fullscreen mode
 */
function toggleFullscreenJS() {
  if (isFullscreenJS()) {
    exitFullscreenJS();
  } else {
    requestFullscreenJS();
  }
}

// Expose functions to window for Dart JS interop
window.requestFullscreenJS = requestFullscreenJS;
window.exitFullscreenJS = exitFullscreenJS;
window.isFullscreenJS = isFullscreenJS;
window.toggleFullscreenJS = toggleFullscreenJS;

// Listen for fullscreen changes
document.addEventListener('fullscreenchange', () => {
  console.log('Fullscreen changed:', isFullscreenJS());
});

document.addEventListener('webkitfullscreenchange', () => {
  console.log('Webkit fullscreen changed:', isFullscreenJS());
});

document.addEventListener('mozfullscreenchange', () => {
  console.log('Mozilla fullscreen changed:', isFullscreenJS());
});

document.addEventListener('MSFullscreenChange', () => {
  console.log('MS fullscreen changed:', isFullscreenJS());
});
