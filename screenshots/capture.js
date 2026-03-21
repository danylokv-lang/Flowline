const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();

  const slides = ['s1', 's2', 's3', 's4', 's5'];
  const names = [
    '01_ai_planning_chat',
    '02_calendar_view',
    '03_calendar_integration',
    '04_save_to_calendar',
    '05_menubar'
  ];

  for (let i = 0; i < slides.length; i++) {
    // Create a fresh page at 2560x1600 for each screenshot
    const page = await browser.newPage();
    await page.setViewportSize({ width: 2560, height: 1600 });

    await page.goto('http://localhost:9876/screenshots.html', { waitUntil: 'networkidle' });

    // Remove the scale transform from this specific slide wrapper so it renders at full size
    await page.evaluate((id) => {
      // Hide all slide wrappers
      document.querySelectorAll('.slide-wrapper').forEach(el => {
        el.style.display = 'none';
      });
      // Show and reset the target slide
      const wrapper = document.getElementById(id);
      wrapper.style.display = 'block';
      wrapper.style.transform = 'none';
      wrapper.style.transformOrigin = 'unset';
      wrapper.style.marginBottom = '0';
      wrapper.style.borderRadius = '0';
      wrapper.style.boxShadow = 'none';
      // Make body flush
      document.body.style.padding = '0';
      document.body.style.gap = '0';
      document.body.style.background = '#080810';
    }, slides[i]);

    // Screenshot the slide element directly
    const el = page.locator(`#${slides[i]} .slide`);
    await el.screenshot({
      path: path.join(__dirname, `${names[i]}.png`),
    });

    console.log(`✓ Saved ${names[i]}.png`);
    await page.close();
  }

  await browser.close();
  console.log('\n✅ All 5 App Store screenshots saved at 2560×1600!');
  console.log(`📁 Location: ${__dirname}`);
})();
