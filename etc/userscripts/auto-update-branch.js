// ==UserScript==
// @name         Auto Update Branch
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Automatically click "Update Branch" button when it appears
// @author       JimmyTranDev
// @match        https://github.com/*/*
// @match        https://gitlab.com/*/*
// @match        https://bitbucket.org/*/*
// @grant        none
// ==/UserScript==

(function() {
  'use strict';

  console.log('Auto Update Branch script loaded');

  function findAndClickUpdateButton() {
    // Look for buttons with "Update Branch" text (case insensitive)
    const buttons = document.querySelectorAll('button, input[type="button"], input[type="submit"], a');

    for (let button of buttons) {
      const buttonText = button.textContent || button.value || button.innerText || '';

      // Check if button contains "Update Branch" text
      if (buttonText.toLowerCase().includes('update branch')) {
        // Make sure the button is visible and clickable
        if (button.offsetParent !== null && !button.disabled) {
          console.log('Found "Update Branch" button, clicking it...');
          button.click();
          return true;
        }
      }
    }

    // Also look for buttons with specific selectors commonly used for update branch buttons
    const commonSelectors = [
      '[data-testid*="update-branch"]',
      '[aria-label*="update branch"]',
      '[aria-label*="Update branch"]',
      '.js-update-branch',
      '[data-action*="update-branch"]'
    ];

    for (let selector of commonSelectors) {
      const button = document.querySelector(selector);
      if (button && button.offsetParent !== null && !button.disabled) {
        console.log(`Found update branch button with selector ${selector}, clicking it...`);
        button.click();
        return true;
      }
    }

    return false;
  }

  // Run the function every 5 seconds
  setInterval(function() {
    const clicked = findAndClickUpdateButton();
    if (clicked) {
      console.log('Update Branch button clicked at', new Date().toISOString());
    }
  }, 5000);

  // Also run once immediately when the script loads
  setTimeout(findAndClickUpdateButton, 1000);

})();
