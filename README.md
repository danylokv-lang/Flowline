# Flowline — AI Day Planner for Mac

> **Your day, designed by AI.** Flowline builds your entire daily schedule around your energy, real commitments, and goals — in one message.

![macOS](https://img.shields.io/badge/macOS-14.6%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5-blue?style=flat-square)
![License](https://img.shields.io/badge/license-proprietary-red?style=flat-square)

---

## What is Flowline?

Most people start the day with a vague to-do list and no real plan. Flowline fixes that. You describe your day in plain English — your meetings, energy level, what needs to get done — and the AI builds a realistic, time-blocked schedule in seconds.

It's not another task manager. It's a personal scheduling AI that knows your wake time, work hours, calendar events, and habits — and creates a plan that actually fits your life.

---

## Features

### 🤖 AI Planning Chat
Talk to the AI like a human. *"Plan my Tuesday — gym at 6pm, big meeting at 10"* — and get a full, structured day plan back. The AI uses your profile (wake time, work hours, bio) to personalise every plan.

### 📅 Smart Calendar View
Every AI-generated block shows up as a colour-coded timeline — Work, Health, Study, Personal. See your entire day at a glance. One click saves any plan directly to Apple Calendar or Google Calendar.

### ⏱ Focus Timer
Start a countdown for any block directly from the calendar. The timer lives in your **menu bar** so it's always visible without switching windows. Break reminders are built in. When the timer ends, the block auto-completes.

### 📥 Task Inbox
Got a random task mid-day? Drop it in the inbox in two seconds. Next time you ask the AI to plan your day, it pulls from your inbox and finds the right slot for everything automatically.

### 🔗 Calendar Sync
Flowline reads your **Apple Calendar** and **Google Calendar** automatically. The AI sees your existing meetings, classes, and appointments — and plans around them without you listing them out.

### 🔥 Streak Tracking
Build a daily planning habit. Your streak grows the longer you plan consistently — visualised with an animated flame that evolves from orange → blue → violet as your streak grows.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI 5, Canvas API, TimelineView |
| Data | SwiftData |
| AI | Claude (Anthropic) via secure proxy |
| Subscriptions | RevenueCat |
| Auth | Custom auth service |
| Calendar | EventKit (Apple + Google via system accounts) |
| Animations | Canvas particle system, TimelineView @ 30fps |

---

## Architecture

```
Flowline/
├── App/                    # Entry point, tab view, app delegate
├── DesignSystem/           # Shared theme, CosmosBackground particles
├── Features/
│   ├── Onboarding/         # AppIntroView (7-page tour) + OnboardingView (profile setup)
│   ├── PlaningChatView/    # AI chat + plan generation
│   ├── Calendar/           # Week view, time blocks, calendar sync
│   ├── Focus/              # Focus timer, menu bar integration
│   ├── TaskInbox/          # Inbox capture
│   ├── Auth/               # Login / signup
│   ├── Settings/           # Profile, calendar connections
│   └── Paywall/            # RevenueCat paywall
├── Models/                 # SwiftData models (DayPlan, FlowTask, UserProfile…)
└── Services/               # ClaudePlanningService, CalendarService, StreakManager…
```

---

## Requirements

- macOS **14.6** or later
- Xcode **15+**
- An Anthropic API key (or deploy the included Cloudflare Worker proxy)

---

## Getting Started

```bash
git clone https://github.com/danylokv-lang/Flowline.git
cd Flowline
open Flowline.xcodeproj
```

1. Open `Flowline/App/Config.swift`
2. Set `proxyURL` to your proxy endpoint, or `nil` to call Anthropic directly
3. Add your RevenueCat API key to `revenueCatAPIKey`
4. Build & run (`⌘R`)

---

## Privacy

Flowline takes privacy seriously:
- All user data (profile, plans, tasks) is stored **locally on-device** using SwiftData
- The AI prompt is sent to Anthropic via a secure proxy — no raw API keys ship in the app
- No analytics, no tracking, no third-party data brokers
- Full privacy manifest (`PrivacyInfo.xcprivacy`) included

---

## License

Flowline is proprietary software. All rights reserved.
© 2026 Danylo Kovalenko
