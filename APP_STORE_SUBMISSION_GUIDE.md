# Flowline — Complete App Store Connect Submission Guide

---

## 1. PREPARE YOUR ASSETS

### Screenshots (Already Generated)
- **iOS**: 1290×2796px (6 screenshots)
- **macOS**: 1440×900px (5 screenshots)
- Files location: `/screenshots/generator.html` → Download all PNGs

### App Icon
- **Size**: 1024×1024px
- **Format**: PNG or JPEG, RGB color space (no transparency)
- **Create**: Design in Figma/Sketch or use: `Flowline/Assets.xcassets/AppIcon.appiconset/`

### Preview Video (Optional but Recommended)
- **Duration**: 15-30 seconds
- **Format**: .mp4 or .mov, H.264 codec, max 500MB
- **Content**: Show planning flow → AI chat → calendar sync → focus timer

---

## 2. APP STORE CONNECT SETUP

### 2.1 Create Your App
1. Go to **[App Store Connect](https://appstoreconnect.apple.com)**
2. Click **"My Apps"** → **"+"** → **"New App"**
3. Select:
   - **Platform**: iOS / macOS (separate listings)
   - **Name**: `Flowline`
   - **Bundle ID**: `com.yourcompany.flowline` (must match in Xcode)
   - **SKU**: `flowline-2025` (internal tracking only)
   - **User Access**: Select access level

---

## 3. APP INFORMATION (All Platforms)

### 3.1 App Name
```
Flowline
```

### 3.2 Subtitle (iOS & macOS)
```
AI-Powered Daily Planning
```

### 3.3 Privacy Policy URL
**Required** — Create a privacy policy document:

#### Privacy Policy Template:
```markdown
# Privacy Policy for Flowline

**Last Updated**: March 2025

## 1. Data We Collect

### User Account Data
- Email address
- Name
- Profile preferences
- Password (hashed, never stored in plain text)

### Calendar Data
- Calendar events (synced only with user permission)
- Event titles, times, and descriptions
- Calendar selection (iCloud, Google Calendar, etc.)

### App Usage Data
- Plans created
- Focus sessions completed
- Streak counts
- App interaction analytics

### Device Data
- Device type and OS version
- App version
- Language preference
- Time zone
- Crash reports (via TestFlight/Sentry)

### Authentication
- We use RevenueCat for in-app purchases
- We use Firebase for authentication and data sync
- All passwords are hashed with bcrypt

## 2. How We Use Data

- **Planning & Scheduling**: To generate AI-powered plans
- **Calendar Integration**: To sync plans to your calendar
- **Analytics**: To improve app performance
- **Customer Support**: To help resolve issues
- **Legal Compliance**: To comply with laws and regulations

## 3. Data Storage & Security

- Data encrypted in transit (HTTPS/TLS)
- Data encrypted at rest (Firebase Security Rules)
- No third-party data selling
- Users can export/delete data anytime

## 4. Third-Party Services

- **RevenueCat**: In-app purchase processing
- **Firebase**: Authentication & database
- **Apple CloudKit**: iCloud sync (optional)

## 5. Children's Privacy

Flowline is not intended for users under 13. We comply with COPPA and GDPR.

## 6. Contact

privacy@flowline.app

---
```

**Host on your domain**: `https://yoursite.com/privacy-policy`

### 3.4 Terms & Conditions (EULA — Required for Subscriptions)

> ⚠️ **Guideline 3.1.2(c) fix**: Apple requires a **functional link to Terms of Use inside the App Description text** for apps with auto-renewable subscriptions. The separate "App Store Connect → URL" field is not sufficient — the link must appear in the visible description. Both descriptions above already include this. Do NOT remove those links.
>
> If you want to use a **custom EULA** instead of Apple's standard one, also go to **App Store Connect → [Your App] → App Information → License Agreement** and paste your full custom EULA text there. You can do both.
```markdown
# Terms of Service for Flowline

**Last Updated**: March 2025

## 1. Acceptance
By downloading and using Flowline, you agree to these Terms.

## 2. License
You receive a limited, non-exclusive license to use Flowline for personal use.

## 3. User Responsibilities
- Maintain account security
- Provide accurate information
- Comply with all laws
- Don't reverse-engineer or distribute

## 4. Intellectual Property
All Flowline content, features, and functionality are owned by [Your Company].

## 5. Limitation of Liability
Flowline is provided "as-is." We're not liable for indirect or consequential damages.

## 6. Subscription Terms
- Free tier: Limited plans
- Pro tier: $4.99/month or $29.99/year or $59.99 lifetime
- Cancel anytime in Settings > Subscriptions
- Billing occurs at renewal unless canceled

## 7. Termination
We reserve the right to terminate accounts that violate these terms.

## 8. Changes to Terms
We may update these terms anytime. Continued use means acceptance.

## 9. Dispute Resolution
Disputes governed by [Your Country] law.

## 10. Contact
support@flowline.app

---
```

**Host on your domain**: `https://yoursite.com/terms`

### 3.5 Support URL
```
https://support.flowline.app
```
(Create a simple support page or link to a help center)

### 3.6 Marketing URL (Optional)
```
https://flowline.app
```

---

## 4. DESCRIPTION (Key Text for App Store)

### iOS Description (Keep under 4000 characters)
```
Flowline is your AI-powered daily planning assistant. Stop wasting time
figuring out your schedule — just tell Flowline what's on your plate,
and it builds the perfect time-blocked day for you in seconds.

PLAN SMARTER
Describe your day in plain language. Flowline's AI creates a detailed,
time-blocked schedule that balances meetings, deep work, breaks, and
personal time. No templates. No manual sorting. Just your day, optimized.

SYNC TO ANY CALENDAR
One tap exports your full plan directly to Apple Calendar, Google Calendar,
or any calendar app on your device. Everything stays in sync across
iPhone and Mac.

FOCUS DEEPER
Built-in Pomodoro timer keeps you locked into deep work. Track focus
sessions, see how long you actually worked, and build the habit of
staying in flow.

BUILD STREAKS
Daily stats track your completion rate, focus hours, and planning streaks.
See what works. Keep building momentum. Celebrate your best weeks.

WORKS ACROSS ALL YOUR DEVICES
Start planning on iPhone, continue on Mac. Your plans, streaks, and stats
sync in real-time across all your devices.

---

WHY FLOWLINE?

Most planners are just digital to-do lists. Flowline is different — it
actively thinks about your day. It understands context, respects your
energy levels, and builds schedules you can actually follow.

People who use Flowline report:
- Spending less time planning, more time doing
- Clearer priorities every single morning
- More consistent deep work sessions
- A stronger sense of control over their day

---

PRICING

Free: 3 plan saves/week · Full access to all features
Flowline Pro Monthly: $4.99/month
Flowline Pro Yearly: $34.99/year

• Payment charged to your Apple ID at confirmation of purchase
• Subscription renews automatically unless cancelled at least 24 hours before the end of the current period
• Your account will be charged for renewal within 24 hours prior to the end of the current period
• Manage or cancel subscriptions in your Apple ID Account Settings after purchase
• Any unused portion of a free trial will be forfeited when you purchase a subscription

---

PRIVACY

Your data is yours. We never sell it, never share it with advertisers.
All data is encrypted in transit and at rest.

Questions or feedback? support@flowline.app
Privacy Policy: https://flowline.ink/privacy.html
Terms of Use: https://flowline.ink/terms.html
```

### macOS Description
```
Flowline brings intelligent daily planning to your Mac.

Stop organizing your day manually. Tell Flowline what's on your plate,
and it builds the perfect time-blocked schedule in seconds.

✦ AI PLANNING MEETS CALENDAR
Describe your day once. Flowline creates a detailed schedule and syncs
it straight to your calendar.

✦ FOCUS TIMER BUILT IN
Pomodoro sessions integrated directly into your plan. Stay focused.
Track deep work sessions.

✦ SYNC ACROSS DEVICES
Plan on Mac, continue on iPhone. Everything syncs in real-time.

✦ SEE YOUR PROGRESS
Daily stats, streak tracking, and focus hours—all at a glance.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRICING

Free: 10 AI messages/day, full access to all features
Flowline Pro Monthly: $4.99/month
Flowline Pro Yearly: $39.99/year
Subscriptions auto-renew unless cancelled 24 hours before renewal.
Cancel anytime in Settings > Subscriptions.

Privacy first. We never sell your data.

Privacy Policy: https://flowline.ink/privacy.html
Terms of Use: https://flowline.ink/terms.html
```

---

## 5. KEYWORDS & SEARCH OPTIMIZATION

### iOS Keywords (comma-separated, 100 characters max)
```
planner, productivity, schedule, calendar, AI, focus, time management,
daily planner, organizer, task management, Pomodoro, goals
```

### macOS Keywords
```
Mac planner, productivity, schedule, calendar sync, AI assistant,
time blocking, focus timer, daily organization
```

---

## 6. RATING & CONTENT RATING QUESTIONNAIRE

### Age Rating
- **Alcohol/Tobacco**: No
- **Gambling**: No
- **Frequent/Intense Violence**: No
- **Mature Content**: No
- **Horror**: No
- **Medical/Health**: No
- **Profanity**: No
- **Sexual Content**: No
- **Unrestricted Web Access**: No (calendar access is gated)

**Recommended Age**: 4+ (iOS) / All Ages (macOS)

### IDFA / Data Tracking
App Store Privacy Labels require transparency:

```
Flowline collects the following:

IDENTIFIER
- User ID (for account management)

DEVICE ID
- Device identifier (analytics)

PURCHASES
- In-app purchase history (RevenueCat)

LOCATION
- Time zone (for scheduling context)

USER ID
- Account email
- User preferences

ANALYTICS
- App crashes
- Feature usage
- Session duration

SENSITIVE INFO
- Calendar data (with permission)

LINKED TO USER
- All above data linked to your account

NOT LINKED TO USER
- Crash reports (anonymized)
- General usage analytics (aggregated)
```

---

## 7. SCREENSHOTS SETUP (STEP-BY-STEP)

### iOS Screenshots Order
1. **Screenshot 1**: "Plan your entire day in seconds"
   - Shows hero with schedule cards and chat
   - Headline overlay: `PLAN YOUR DAY IN SECONDS`

2. **Screenshot 2**: "Your personal AI planning assistant"
   - Shows AI chat interface
   - Headline: `JUST DESCRIBE YOUR DAY`

3. **Screenshot 3**: "Syncs with your calendar instantly"
   - Shows calendar view
   - Headline: `ONE TAP TO SYNC`

4. **Screenshot 4**: "Deep work mode. Zero distractions."
   - Shows focus timer
   - Headline: `STAY FOCUSED`

5. **Screenshot 5**: "Track your momentum"
   - Shows stats and streaks
   - Headline: `WATCH YOUR PROGRESS`

6. **Screenshot 6**: "Unlock everything"
   - Shows paywall
   - Headline: `TRY FREE. UPGRADE ANYTIME`

### macOS Screenshots Order
1. **Screenshot 1**: "AI-powered planning now on Mac"
   - Shows hero chat interface

2. **Screenshot 2**: "Calendar sync beautifully designed"
   - Shows weekly calendar view

3. **Screenshot 3**: "Built-in Pomodoro timer"
   - Shows focus timer with task list

4. **Screenshot 4**: "Your productivity visualized"
   - Shows stats and bar charts

5. **Screenshot 5**: "Unlock everything"
   - Shows pricing tiers

---

## 8. FILL IN APP STORE CONNECT

### 8.1 Navigate to Your App
1. **App Store Connect** → **My Apps** → **Flowline**
2. Click **"iOS App" or "macOS App"** tab

### 8.2 App Information
Go to **App Information**:
- **Bundle ID**: `com.yourcompany.flowline` ✓
- **SKU**: `flowline-2025` ✓
- **Primary Language**: English
- **Category**: Productivity
- **Subcategory**: Time Management / Productivity
- **Content Ratings**: Set via questionnaire (see above)

### 8.3 Pricing & Availability
1. Click **"Pricing and Availability"**
2. **Available in**: Select all countries (or choose specific regions)
3. **Release Date**: Choose or set to "Automatic when approved"
4. **Free App**: No (you have in-app purchases)

### 8.4 In-App Purchases Setup
Go to **In-App Purchases**:

```
Product ID: com.flowline.pro.monthly
Display Name: Flowline Pro Monthly
Pricing Tier: Tier 4 ($4.99/month)
Billing Period: Monthly, Auto-renewable
Intro Offer: 7-day free trial
  - Price: Free
  - Duration: 7 days
  - Billing Period: Per subscription cycle

Product ID: com.flowline.pro.annual
Display Name: Flowline Pro Annual
Pricing Tier: Tier 25 ($29.99/year)
Billing Period: Yearly, Auto-renewable
Intro Offer: 7-day free trial (same as above)

Product ID: com.flowline.pro.lifetime
Display Name: Flowline Pro Lifetime
Pricing Tier: Tier 50 ($59.99, one-time)
Billing Period: One-time purchase
(No intro offer for non-renewable)
```

### 8.5 Prepare for Submission
1. **Version Number**: Set to `1.0.0` (in Xcode)
2. **Build Number**: Set to `1` (in Xcode)
3. **What's New in This Version**:
```
Introducing Flowline — Your AI Daily Planning Assistant

• Create AI-powered schedules in seconds
• Sync plans to Apple Calendar or any calendar
• Built-in Pomodoro focus timer
• Track streaks, focus hours, and progress
• Works across iPhone, iPad, and Mac

Start free. No credit card required.
```

### 8.6 Screenshots & Preview
1. Go to **Localization** → **English**
2. Upload your screenshots in order (see section 7)
3. **Preview Video** (optional): Upload 15-30 sec demo video
4. Add **Screenshot Descriptions**:
   - Screenshot 1: "Plan your entire day in seconds with AI"
   - Screenshot 2: "Describe your day. AI builds your schedule"
   - Screenshot 3: "Sync to any calendar with one tap"
   - Screenshot 4: "Stay focused with built-in Pomodoro timer"
   - Screenshot 5: "Track progress with daily stats and streaks"
   - Screenshot 6: "Start free, upgrade anytime"

### 8.7 App Privacy
Go to **Privacy**:
- Upload your **Privacy Policy** URL
- Add **Data Privacy** labels (see section 6)

### 8.8 Ratings & Restrictions
1. **Ratings**: Complete Age Rating Questionnaire (see section 6)
2. **Kids Category**: No (unless you want COPPA compliance)
3. **TV OS**: No (unless building tvOS version)

---

## 9. BUILD & SIGN YOUR APP

### 9.1 In Xcode
1. Select **Flowline** target
2. **Signing & Capabilities**:
   - **Team**: Select your Apple Developer Team
   - **Bundle Identifier**: `com.yourcompany.flowline`
   - **Minimum OS**: iOS 14+ / macOS 12+

3. **Capabilities** needed:
   - ✓ Calendar (for calendar access)
   - ✓ HealthKit (optional, for activity rings)
   - ✓ Push Notifications (for plan reminders)

### 9.2 Build for Submission
```bash
cd /Users/danylo/Code/iOS/Flowline

# For iOS
xcodebuild -scheme Flowline \
  -configuration Release \
  -derivedDataPath build \
  -archivePath build/Flowline.xcarchive \
  archive

# For macOS
xcodebuild -scheme Flowline \
  -configuration Release \
  -derivedDataPath build \
  -archivePath build/Flowline-Mac.xcarchive \
  archive
```

### 9.3 Validate Build
1. **Xcode** → **Window** → **Organizer**
2. Select your archive
3. Click **"Validate App"**
4. Sign with your Apple Developer account
5. Fix any errors (missing icons, code signing issues, etc.)

---

## 10. SUBMIT FOR REVIEW

### 10.1 Final Checklist
- [ ] App icon (1024×1024) added
- [ ] All 6+ screenshots uploaded and ordered
- [ ] Description is under 4000 characters
- [ ] Privacy policy URL is live
- [ ] Terms & Conditions URL is live
- [ ] Support URL is working
- [ ] Pricing & availability configured
- [ ] In-app purchases configured correctly
- [ ] Age rating questionnaire completed
- [ ] Version number matches (1.0.0)
- [ ] Build tested on real device (not just simulator)
- [ ] No obvious bugs or crashes
- [ ] Notifications are optional (don't force on launch)
- [ ] Calendar access uses proper permission dialogs

### 10.2 Submit
1. **Xcode Organizer** → Select archive
2. Click **"Distribute App"**
3. Select **"App Store Connect"**
4. Choose **"Automatic signing"**
5. Review & Submit
6. Go back to **App Store Connect** → Your app → **Version** → **Submit for Review**
7. Answer additional questions:
   - **Advertising ID**: Yes (if you use analytics)
   - **Third-party SDKs**: Yes (RevenueCat, Firebase)
   - **Content Rights**: Yes, you own/have rights to all content
   - **Export Compliance**: No (unless using encryption beyond standard TLS)
   - **Alcohol/Tobacco**: No
   - **Gambling**: No

### 10.3 After Submission
- Apple will review your app (24-48 hours typical)
- You'll receive emails during review
- Common rejection reasons:
  - Missing or unclear privacy policy
  - Misleading screenshots
  - Crashes on device
  - Requiring payment for core features
  - Broken links

If rejected, fix issues and resubmit.

---

## 11. POST-LAUNCH CHECKLIST

- [ ] Monitor crash reports in Xcode Organizer
- [ ] Respond to user reviews
- [ ] Track top crashes and fix in v1.0.1
- [ ] Set up analytics dashboard (Firebase)
- [ ] Monitor RevenueCat conversion rates
- [ ] Create support@flowline.app email
- [ ] Set up TestFlight for beta testing
- [ ] Plan v1.1 features based on feedback

---

## 12. HELPFUL LINKS

- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **TestFlight**: https://developer.apple.com/testflight/
- **RevenueCat Dashboard**: https://app.revenuecat.com
- **Firebase Console**: https://console.firebase.google.com

---

## 13. COMMON MISTAKES TO AVOID

❌ **Don't**:
- Force permissions on launch (ask only when needed)
- Use generic screenshots (show real features!)
- Leave placeholder text in descriptions
- Use outdated app icons
- Submit without testing on real device
- Forget privacy policy
- Make free tier too limited (users need to try app)
- Use misleading language in ads

✅ **Do**:
- Test on iOS 14+ and macOS 12+ devices
- Get feedback from beta testers
- Monitor analytics post-launch
- Respond to reviews quickly
- Plan v2 features before v1 launch
- Keep documentation updated

---

**Questions?** Email support@flowline.app or check App Store Connect Help.

Good luck with your submission! 🚀
