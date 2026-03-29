// Color palette
const colors = {
    mainBg: '#0a0a0f',
    secondBg: '#111118',
    tertiaryBg: '#16161f',
    mainTxt: '#e8e8f0',
    secondTxt: '#6b6b80',
    dimTxt: '#3a3a4a',
    accent: '#3b82f6',
    accentHi: '#60a5fa',
    border: 'rgba(255, 255, 255, 0.06)',
    borderHi: 'rgba(255, 255, 255, 0.10)',
};

// iPhone dimensions
const iphoneDim = { width: 1170, height: 2532, safeTop: 120, safeBottom: 150 };

// macOS dimensions
const macosDim = { width: 1440, height: 900 };

// Screen data
const iosScreens = [
    { title: 'Welcome', subtitle: 'AI-powered planning' },
    { title: 'Plan Your Day', subtitle: 'Chat with AI assistant' },
    { title: 'Calendar', subtitle: 'Sync & integration' },
    { title: 'Analytics', subtitle: 'Track your progress' },
    { title: 'Focus Timer', subtitle: 'Deep work sessions' },
    { title: 'Pro Features', subtitle: 'Unlock all features' }
];

const macosScreens = [
    { title: 'Welcome', subtitle: 'AI-powered planning' },
    { title: 'Plan Your Day', subtitle: 'Chat with AI assistant' },
    { title: 'Calendar', subtitle: 'Sync & integration' },
    { title: 'Analytics', subtitle: 'Track your progress' },
    { title: 'Focus Timer', subtitle: 'Deep work sessions' },
    { title: 'Pro Features', subtitle: 'Unlock all features' }
];

// Helper: Draw rounded rectangle
function roundRect(ctx, x, y, w, h, r = 12) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
}

// Helper: Draw text with wrapping
function drawText(ctx, text, x, y, maxWidth, lineHeight, align = 'left') {
    const words = text.split(' ');
    let line = '';
    let currentY = y;

    words.forEach(word => {
        const testLine = line + word + ' ';
        const metrics = ctx.measureText(testLine);

        if (metrics.width > maxWidth && line) {
            ctx.fillText(line, x, currentY, maxWidth);
            line = word + ' ';
            currentY += lineHeight;
        } else {
            line = testLine;
        }
    });

    ctx.fillText(line, x, currentY, maxWidth);
    return currentY;
}

// Generate iPhone screenshot
function generateIOSScreenshot(index) {
    const canvas = document.createElement('canvas');
    canvas.width = iphoneDim.width;
    canvas.height = iphoneDim.height;
    const ctx = canvas.getContext('2d');

    // Background
    ctx.fillStyle = colors.mainBg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Safe area background
    ctx.fillStyle = colors.secondBg;
    ctx.fillRect(0, iphoneDim.safeTop, canvas.width, canvas.height - iphoneDim.safeTop - iphoneDim.safeBottom);

    // Status bar
    ctx.fillStyle = colors.mainBg;
    ctx.fillRect(0, 0, canvas.width, iphoneDim.safeTop);
    ctx.fillStyle = colors.secondTxt;
    ctx.font = 'bold 32px -apple-system';
    ctx.fillText('9:41', 60, 80);

    // Content based on screen index
    const padding = 40;
    let contentY = iphoneDim.safeTop + 60;

    switch (index) {
        case 0: // Welcome
            drawWelcomeScreenIOS(ctx, contentY);
            break;
        case 1: // Chat
            drawChatScreenIOS(ctx, contentY);
            break;
        case 2: // Calendar
            drawCalendarScreenIOS(ctx, contentY);
            break;
        case 3: // Analytics
            drawAnalyticsScreenIOS(ctx, contentY);
            break;
        case 4: // Timer
            drawTimerScreenIOS(ctx, contentY);
            break;
        case 5: // Pro
            drawProScreenIOS(ctx, contentY);
            break;
    }

    return canvas;
}

// Generate macOS screenshot
function generateMacOSScreenshot(index) {
    const canvas = document.createElement('canvas');
    canvas.width = macosDim.width;
    canvas.height = macosDim.height;
    const ctx = canvas.getContext('2d');

    // Background
    ctx.fillStyle = colors.mainBg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Top bar
    ctx.fillStyle = colors.secondBg;
    ctx.fillRect(0, 0, canvas.width, 60);

    // Title bar content
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 16px -apple-system';
    ctx.fillText('Flowline', 40, 40);

    let contentY = 100;

    switch (index) {
        case 0: // Welcome
            drawWelcomeScreenMacOS(ctx, contentY);
            break;
        case 1: // Chat
            drawChatScreenMacOS(ctx, contentY);
            break;
        case 2: // Calendar
            drawCalendarScreenMacOS(ctx, contentY);
            break;
        case 3: // Analytics
            drawAnalyticsScreenMacOS(ctx, contentY);
            break;
        case 4: // Timer
            drawTimerScreenMacOS(ctx, contentY);
            break;
        case 5: // Pro
            drawProScreenMacOS(ctx, contentY);
            break;
    }

    return canvas;
}

// iOS: Welcome Screen
function drawWelcomeScreenIOS(ctx, startY) {
    let y = startY;

    // Title
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 48px -apple-system';
    y = drawText(ctx, 'Flowline', 40, y + 40, 1090, 60, 'left');

    // Subtitle
    ctx.fillStyle = colors.secondTxt;
    ctx.font = '16px -apple-system';
    y = drawText(ctx, 'AI-powered daily planning', 40, y + 20, 1090, 28) + 40;

    // Feature cards
    const features = [
        { icon: '✨', title: 'Smart Planning', desc: 'AI breaks down your goals' },
        { icon: '📅', title: 'Calendar Sync', desc: 'Auto-schedule everything' },
        { icon: '⏱️', title: 'Focus Mode', desc: 'Deep work sessions' }
    ];

    features.forEach(f => {
        // Card background
        ctx.fillStyle = colors.tertiaryBg;
        roundRect(ctx, 40, y, 1090, 140, 16);
        ctx.fill();

        // Border
        ctx.strokeStyle = colors.borderHi;
        ctx.lineWidth = 1;
        roundRect(ctx, 40, y, 1090, 140, 16);
        ctx.stroke();

        // Icon
        ctx.fillStyle = colors.accent;
        ctx.font = '32px -apple-system';
        ctx.fillText(f.icon, 80, y + 60);

        // Title
        ctx.fillStyle = colors.mainTxt;
        ctx.font = 'bold 18px -apple-system';
        ctx.fillText(f.title, 150, y + 50);

        // Description
        ctx.fillStyle = colors.secondTxt;
        ctx.font = '14px -apple-system';
        ctx.fillText(f.desc, 150, y + 80);

        y += 160;
    });

    // Button
    y += 20;
    ctx.fillStyle = colors.accent;
    roundRect(ctx, 40, y, 1090, 56, 14);
    ctx.fill();

    ctx.fillStyle = '#fff';
    ctx.font = 'bold 16px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('Get Started', 585, y + 38);
    ctx.textAlign = 'left';
}

// iOS: Chat Screen
function drawChatScreenIOS(ctx, startY) {
    let y = startY;

    // Title
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 32px -apple-system';
    ctx.fillText('FLOWLINE', 40, y);
    y += 60;

    // Input area
    ctx.fillStyle = colors.tertiaryBg;
    roundRect(ctx, 40, y, 1090, 56, 12);
    ctx.fill();

    ctx.strokeStyle = colors.borderHi;
    ctx.lineWidth = 1;
    roundRect(ctx, 40, y, 1090, 56, 12);
    ctx.stroke();

    ctx.fillStyle = colors.dimTxt;
    ctx.font = '14px -apple-system';
    ctx.fillText("What's on your plate?", 60, y + 35);
    y += 80;

    // Messages
    const messages = [
        { isUser: false, text: "Tell me about your day and I'll build a perfect schedule." },
        { isUser: true, text: 'I have 3 meetings and need focus time for a project' },
        { isUser: false, text: "Perfect! I've created a time-blocked schedule for you." }
    ];

    messages.forEach(msg => {
        const bgColor = msg.isUser ? colors.accent : colors.tertiaryBg;
        const textColor = msg.isUser ? '#fff' : colors.mainTxt;
        const align = msg.isUser ? 'right' : 'left';
        const x = msg.isUser ? 440 : 40;
        const maxWidth = msg.isUser ? 650 : 1090;

        ctx.fillStyle = bgColor;
        ctx.fillRect(x, y, maxWidth, 48);

        ctx.fillStyle = textColor;
        ctx.font = '14px -apple-system';
        ctx.textAlign = align;
        ctx.fillText(msg.text.substring(0, 40), msg.isUser ? 1070 : x + 20, y + 30);
        ctx.textAlign = 'left';

        y += 64;
    });
}

// iOS: Calendar Screen
function drawCalendarScreenIOS(ctx, startY) {
    let y = startY;

    // Title
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 32px -apple-system';
    ctx.fillText('CALENDAR', 40, y);
    y += 70;

    // Calendar grid
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 14px -apple-system';
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    let x = 40;
    days.forEach(d => {
        ctx.fillText(d, x, y);
        x += 160;
    });
    y += 40;

    // Calendar dates
    const cellSize = 140;
    const spacing = 20;
    for (let i = 1; i <= 28; i++) {
        const col = (i - 1) % 7;
        const row = Math.floor((i - 1) / 7);
        const cellX = 40 + col * (cellSize + spacing);
        const cellY = y + row * (cellSize + spacing);

        // Highlight some dates
        if (i % 4 === 0) {
            ctx.fillStyle = colors.accent;
            roundRect(ctx, cellX, cellY, cellSize, cellSize, 8);
            ctx.fill();
            ctx.fillStyle = '#fff';
        } else {
            ctx.fillStyle = colors.tertiaryBg;
            roundRect(ctx, cellX, cellY, cellSize, cellSize, 8);
            ctx.fill();
            ctx.strokeStyle = colors.borderHi;
            ctx.lineWidth = 1;
            roundRect(ctx, cellX, cellY, cellSize, cellSize, 8);
            ctx.stroke();
            ctx.fillStyle = colors.mainTxt;
        }

        ctx.font = '16px -apple-system';
        ctx.textAlign = 'center';
        ctx.fillText(i.toString(), cellX + cellSize / 2, cellY + cellSize / 2 + 8);
        ctx.textAlign = 'left';
    }
}

// iOS: Analytics Screen
function drawAnalyticsScreenIOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 32px -apple-system';
    ctx.fillText('Your Stats', 40, y);
    y += 80;

    // Stat cards
    const stats = [
        { label: 'Days Streak', value: '12', unit: '🔥' },
        { label: 'Plans Made', value: '48', unit: '✓' },
        { label: 'Focus Hours', value: '156', unit: '⏱️' }
    ];

    stats.forEach(stat => {
        ctx.fillStyle = colors.tertiaryBg;
        roundRect(ctx, 40, y, 1090, 160, 16);
        ctx.fill();

        ctx.fillStyle = colors.accent;
        ctx.font = '40px -apple-system';
        ctx.fillText(stat.unit, 80, y + 80);

        ctx.fillStyle = colors.mainTxt;
        ctx.font = 'bold 32px -apple-system';
        ctx.fillText(stat.value, 160, y + 80);

        ctx.fillStyle = colors.secondTxt;
        ctx.font = '14px -apple-system';
        ctx.fillText(stat.label, 80, y + 130);

        y += 190;
    });
}

// iOS: Timer Screen
function drawTimerScreenIOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 32px -apple-system';
    ctx.fillText('Focus Timer', 40, y);
    y += 80;

    // Timer circle
    const centerX = 585;
    const centerY = y + 200;
    const radius = 180;

    ctx.fillStyle = colors.tertiaryBg;
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = colors.accent;
    ctx.lineWidth = 8;
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, 0, Math.PI * 1.5);
    ctx.stroke();

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 56px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('24:36', centerX, centerY + 20);
    ctx.textAlign = 'left';

    y += 480;

    // Buttons
    ctx.fillStyle = colors.accent;
    roundRect(ctx, 40, y, 1090, 56, 14);
    ctx.fill();

    ctx.fillStyle = '#fff';
    ctx.font = 'bold 16px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('Start Session', 585, y + 38);
    ctx.textAlign = 'left';
}

// iOS: Pro Screen
function drawProScreenIOS(ctx, startY) {
    let y = startY;

    // Title
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 32px -apple-system';
    ctx.fillText('Flowline Pro', 40, y);

    ctx.fillStyle = colors.secondTxt;
    ctx.font = '14px -apple-system';
    ctx.fillText('Unlimited everything', 40, y + 50);
    y += 100;

    // Features
    const features = ['Unlimited plans', 'Priority support', 'Advanced analytics', 'Custom themes', 'Export options'];
    features.forEach(f => {
        ctx.fillStyle = colors.accent;
        ctx.font = 'bold 18px -apple-system';
        ctx.fillText('✓', 40, y);

        ctx.fillStyle = colors.mainTxt;
        ctx.font = '16px -apple-system';
        ctx.fillText(f, 100, y);

        y += 80;
    });

    y += 40;

    // Price
    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 28px -apple-system';
    ctx.fillText('$4.99/month', 40, y);

    y += 80;

    // Button
    ctx.fillStyle = colors.accent;
    roundRect(ctx, 40, y, 1090, 56, 14);
    ctx.fill();

    ctx.fillStyle = '#fff';
    ctx.font = 'bold 16px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('Start Free Trial', 585, y + 38);
    ctx.textAlign = 'left';
}

// macOS: Welcome Screen
function drawWelcomeScreenMacOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 42px -apple-system';
    ctx.fillText('AI-Powered Planning', 100, y);
    y += 70;

    ctx.fillStyle = colors.secondTxt;
    ctx.font = '16px -apple-system';
    ctx.fillText('Break down your goals, create perfect schedules, stay focused.', 100, y);
    y += 60;

    // Feature row
    ctx.fillStyle = colors.accent;
    ctx.font = '24px -apple-system';
    ctx.fillText('✨', 100, y + 30);
    ctx.fillStyle = colors.mainTxt;
    ctx.font = '16px -apple-system';
    ctx.fillText('Smart AI Planning', 150, y + 30);
    y += 60;

    ctx.fillStyle = colors.accent;
    ctx.font = '24px -apple-system';
    ctx.fillText('📅', 100, y + 30);
    ctx.fillStyle = colors.mainTxt;
    ctx.font = '16px -apple-system';
    ctx.fillText('Calendar Integration', 150, y + 30);
    y += 60;

    ctx.fillStyle = colors.accent;
    ctx.font = '24px -apple-system';
    ctx.fillText('⏱️', 100, y + 30);
    ctx.fillStyle = colors.mainTxt;
    ctx.font = '16px -apple-system';
    ctx.fillText('Focus Mode', 150, y + 30);
}

// macOS: Chat Screen
function drawChatScreenMacOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 24px -apple-system';
    ctx.fillText('Chat with AI', 100, y);
    y += 50;

    // Messages
    ctx.fillStyle = colors.tertiaryBg;
    roundRect(ctx, 100, y, 600, 50, 8);
    ctx.fill();
    ctx.fillStyle = colors.mainTxt;
    ctx.font = '14px -apple-system';
    ctx.fillText("Tell me what's on your plate today...", 120, y + 32);
    y += 70;

    ctx.fillStyle = colors.accent;
    roundRect(ctx, 700, y, 600, 50, 8);
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = '14px -apple-system';
    ctx.fillText('3 meetings and focus time needed', 720, y + 32);
    y += 70;

    ctx.fillStyle = colors.tertiaryBg;
    roundRect(ctx, 100, y, 1200, 60, 8);
    ctx.fill();
    ctx.fillStyle = colors.mainTxt;
    ctx.font = '14px -apple-system';
    ctx.fillText("Perfect! I've created a time-blocked schedule for you.", 120, y + 38);
}

// macOS: Calendar Screen
function drawCalendarScreenMacOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 24px -apple-system';
    ctx.fillText('Calendar Integration', 100, y);
    y += 50;

    // Mini calendar
    const cellW = 140;
    const cellH = 60;
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    let x = 100;
    days.forEach(d => {
        ctx.fillStyle = colors.secondTxt;
        ctx.font = '12px -apple-system';
        ctx.fillText(d, x, y);
        x += cellW;
    });
    y += 40;

    for (let i = 1; i <= 14; i++) {
        const col = (i - 1) % 7;
        const row = Math.floor((i - 1) / 7);
        const cellX = 100 + col * cellW;
        const cellY = y + row * cellH;

        if (i % 4 === 0) {
            ctx.fillStyle = colors.accent;
            roundRect(ctx, cellX, cellY, cellW - 10, cellH - 10, 6);
            ctx.fill();
            ctx.fillStyle = '#fff';
        } else {
            ctx.fillStyle = colors.tertiaryBg;
            roundRect(ctx, cellX, cellY, cellW - 10, cellH - 10, 6);
            ctx.fill();
            ctx.fillStyle = colors.mainTxt;
        }

        ctx.font = '14px -apple-system';
        ctx.textAlign = 'center';
        ctx.fillText(i.toString(), cellX + (cellW - 10) / 2, cellY + (cellH - 10) / 2 + 5);
        ctx.textAlign = 'left';
    }
}

// macOS: Analytics Screen
function drawAnalyticsScreenMacOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 24px -apple-system';
    ctx.fillText('Your Analytics', 100, y);
    y += 50;

    // Stats in a row
    const stats = [
        { label: '12', unit: '🔥 Days' },
        { label: '48', unit: '✓ Plans' },
        { label: '156', unit: '⏱️ Hours' }
    ];

    let statX = 100;
    stats.forEach(s => {
        ctx.fillStyle = colors.tertiaryBg;
        roundRect(ctx, statX, y, 350, 120, 12);
        ctx.fill();

        ctx.fillStyle = colors.accent;
        ctx.font = 'bold 36px -apple-system';
        ctx.fillText(s.label, statX + 40, y + 60);

        ctx.fillStyle = colors.secondTxt;
        ctx.font = '14px -apple-system';
        ctx.fillText(s.unit, statX + 40, y + 95);

        statX += 370;
    });
}

// macOS: Timer Screen
function drawTimerScreenMacOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 24px -apple-system';
    ctx.fillText('Focus Timer', 100, y);
    y += 50;

    // Timer display
    ctx.fillStyle = colors.tertiaryBg;
    roundRect(ctx, 300, y, 840, 200, 16);
    ctx.fill();

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 80px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('24:36', 720, y + 140);
    ctx.textAlign = 'left';

    y += 240;

    // Button
    ctx.fillStyle = colors.accent;
    roundRect(ctx, 400, y, 640, 50, 10);
    ctx.fill();

    ctx.fillStyle = '#fff';
    ctx.font = 'bold 16px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('Start Focus Session', 720, y + 35);
    ctx.textAlign = 'left';
}

// macOS: Pro Screen
function drawProScreenMacOS(ctx, startY) {
    let y = startY;

    ctx.fillStyle = colors.mainTxt;
    ctx.font = 'bold 28px -apple-system';
    ctx.fillText('Flowline Pro', 100, y);
    y += 50;

    ctx.fillStyle = colors.secondTxt;
    ctx.font = '16px -apple-system';
    ctx.fillText('$4.99/month • Unlimited everything', 100, y);
    y += 60;

    // Features
    ctx.fillStyle = colors.accent;
    ctx.font = '16px -apple-system';
    ctx.fillText('✓ Unlimited plans', 100, y);
    y += 40;
    ctx.fillText('✓ Priority support', 100, y);
    y += 40;
    ctx.fillText('✓ Advanced analytics', 100, y);
    y += 40;
    ctx.fillText('✓ Custom themes', 100, y);

    y += 60;

    ctx.fillStyle = colors.accent;
    roundRect(ctx, 100, y, 400, 50, 10);
    ctx.fill();

    ctx.fillStyle = '#fff';
    ctx.font = 'bold 16px -apple-system';
    ctx.textAlign = 'center';
    ctx.fillText('Start Free Trial', 300, y + 35);
    ctx.textAlign = 'left';
}

// Initialize galleries
function initGalleries() {
    const iosGallery = document.getElementById('ios-gallery');
    const macosGallery = document.getElementById('macos-gallery');

    iosScreens.forEach((screen, i) => {
        const canvas = generateIOSScreenshot(i);
        const wrapper = document.createElement('div');
        wrapper.className = 'screenshot-wrapper';
        wrapper.innerHTML = `
            <canvas></canvas>
            <div class="screenshot-label">
                <strong>${screen.title}</strong>
                <p>${screen.subtitle}</p>
                <div class="dimension-info">1170 × 2532px</div>
            </div>
        `;
        wrapper.querySelector('canvas').replaceWith(canvas);
        iosGallery.appendChild(wrapper);
    });

    macosScreens.forEach((screen, i) => {
        const canvas = generateMacOSScreenshot(i);
        const wrapper = document.createElement('div');
        wrapper.className = 'screenshot-wrapper';
        wrapper.innerHTML = `
            <canvas></canvas>
            <div class="screenshot-label">
                <strong>${screen.title}</strong>
                <p>${screen.subtitle}</p>
                <div class="dimension-info">1440 × 900px</div>
            </div>
        `;
        wrapper.querySelector('canvas').replaceWith(canvas);
        macosGallery.appendChild(wrapper);
    });
}

// Download functions (placeholder - would need JSZip library)
function downloadAllIOS() {
    alert('Download: Please right-click individual screenshots and select "Save Image As" or use the PNG download option.');
}

function downloadAllIOSPNG() {
    iosScreens.forEach((screen, i) => {
        const canvas = generateIOSScreenshot(i);
        const link = document.createElement('a');
        link.href = canvas.toDataURL('image/png');
        link.download = `iOS_${i + 1}_${screen.title.replace(' ', '_')}.png`;
        link.click();
    });
}

function downloadAllMacOS() {
    alert('Download: Please right-click individual screenshots and select "Save Image As" or use the PNG download option.');
}

function downloadAllMacOSPNG() {
    macosScreens.forEach((screen, i) => {
        const canvas = generateMacOSScreenshot(i);
        const link = document.createElement('a');
        link.href = canvas.toDataURL('image/png');
        link.download = `macOS_${i + 1}_${screen.title.replace(' ', '_')}.png`;
        link.click();
    });
}

// Initialize on load
window.addEventListener('DOMContentLoaded', initGalleries);
