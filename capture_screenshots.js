const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

async function capture() {
  const artifactDir = 'C:\\Users\\Sooraj\\.gemini\\antigravity\\brain\\a915c493-7c04-4be2-ab13-117d5df8f75b';
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  });

  const page = await context.newPage();

  console.log('Navigating to Flutter web app at http://localhost:8085 ...');
  
  // Wait for Flutter web app to be responsive
  let connected = false;
  for (let i = 0; i < 40; i++) {
    try {
      await page.goto('http://localhost:8085', { timeout: 4000 });
      connected = true;
      break;
    } catch (e) {
      console.log(`Waiting for web server... attempt ${i + 1}`);
      await new Promise((r) => setTimeout(r, 2000));
    }
  }

  if (!connected) {
    console.error('Could not connect to http://localhost:8085');
    await browser.close();
    process.exit(1);
  }

  // Wait for Flutter CanvasKit / Skia / DOM to render
  console.log('Waiting for Flutter app rendering...');
  await page.waitForTimeout(6000);

  // 1. Capture Login Screen
  console.log('Navigating to /login ...');
  await page.goto('http://localhost:8085/#/login', { timeout: 10000 });
  await page.waitForTimeout(4000);
  const loginPath = path.join(artifactDir, 'screenshot_login.png');
  await page.screenshot({ path: loginPath });
  console.log('Saved Login screenshot to:', loginPath);

  // 2. Capture OTP Screen
  console.log('Navigating to /otp ...');
  await page.goto('http://localhost:8085/#/otp', { timeout: 10000 });
  await page.waitForTimeout(4000);
  const otpPath = path.join(artifactDir, 'screenshot_otp.png');
  await page.screenshot({ path: otpPath });
  console.log('Saved OTP screenshot to:', otpPath);

  // 3. Capture Profile Screen
  console.log('Navigating to /profile ...');
  await page.goto('http://localhost:8085/#/profile', { timeout: 10000 });
  await page.waitForTimeout(4000);
  const profilePath = path.join(artifactDir, 'screenshot_profile.png');
  await page.screenshot({ path: profilePath });
  console.log('Saved Profile screenshot to:', profilePath);

  await browser.close();
  console.log('All screenshots captured successfully!');
}

capture().catch((err) => {
  console.error('Error capturing screenshots:', err);
  process.exit(1);
});
