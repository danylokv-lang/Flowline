# Flowline — AI Context File

> This file is maintained for AI assistants. It describes the current state of the project, what we're building, what's been done, and what's next. Update this file after every significant session or change.

---

## What is Flowline?

An AI-powered day planner for macOS and iOS. Users describe their day in plain English and Claude generates a realistic, time-blocked schedule in seconds — aware of their calendar, energy, work hours, and recurring commitments.

It is **not** a task manager. It's a personal scheduling AI that plans your whole day for you.

---

## Platform Status

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Live on App Store (basic version) | Needs polish before re-submission |
| iOS | In active development | Primary focus right now |

Both will be submitted for App Store review together after polish is complete.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI 5 |
| Local data | SwiftData |
| AI | Claude (Anthropic) via Cloudflare Worker proxy |
| Backend | Cloudflare Workers + D1 (SQLite) + KV |
| Auth | Custom JWT auth via Cloudflare Worker |
| Subscriptions | RevenueCat (Free / Pro / Trial) |
| Calendar | EventKit (Apple Calendar + Google via system accounts) |
| Notifications | UserNotifications |

---

## Project Structure

```
Flowline/
├── App/                    # Entry point (FlowlineApp.swift), MainTabView
├── DesignSystem/           # FlowlineTheme, CosmosBackground particles, GrowingTextEditor
├── Features/
│   ├── Onboarding/         # AppIntroView (7-page tour) + OnboardingView (profile setup)
│   ├── Auth/               # AuthView — login / signup
│   ├── PlaningChatView/    # Main AI chat + plan generation
│   ├── Calendar/           # CalendarView — week view with time-blocked schedule
│   ├── Focus/              # FocusTimerView + MenuBarFlowlineView (macOS menu bar)
│   ├── TaskInbox/          # TaskInboxView — quick task capture
│   ├── Settings/           # SettingsView — profile, calendar, account
│   ├── Stats/              # StatsView — streaks, plan history
│   └── PaywallView         # RevenueCat paywall
├── Models/                 # SwiftData models
│   ├── UserProfile         # Wake time, work hours, bio, recurring commitments
│   ├── FlowTask            # Individual task (name, priority, category, deadline)
│   ├── DayPlan             # Daily plan container (date, blocks, status)
│   ├── ScheduleBlock       # Time-blocked slot (start, end, category, completion)
│   ├── ChatMessage         # Conversation history with sync metadata
│   └── CapturedTask        # Quick-capture inbox task
├── Services/
│   ├── ClaudePlanningService   # Claude AI + 100-line system prompt
│   ├── AuthService             # JWT login/register, Keychain storage
│   ├── SubscriptionManager     # RevenueCat integration
│   ├── SyncService             # Sync profile + plans to Cloudflare D1
│   ├── CalendarService         # EventKit read for Apple + Google Calendar
│   ├── FocusTimerManager       # Timer, breaks, notifications
│   ├── StreakManager           # Consecutive planning days tracking
│   ├── PlanSavingService       # Parse AI plan → SwiftData
│   └── NotificationManager     # Local notifications
└── backend/
    ├── worker.js               # Cloudflare Worker — auth, sync, AI proxy
    ├── claude-proxy.js         # Standalone Claude API proxy
    ├── schema.sql              # D1 schema (users, profiles, plans, chats)
    └── wrangler.toml           # Cloudflare config
```

---

## Subscription Model

| Tier | Price | Limits |
|------|-------|--------|
| Free | $0 | 3 day-plan saves per week |
| Pro | $4.99/mo or $34.99/yr | Unlimited saves + all future features |
| Trial | Free | 3-day Pro trial, starts on first save |

RevenueCat entitlement ID: `"Flowline Pro"`

---

## Backend (Cloudflare)

- **Worker routes:** `/auth/register`, `/auth/login`, `/auth/forgot-password`, `/auth/reset-password`, `/user/profile`, `/user/subscription`, `/ai`, `/calendar`, `/chats/sync`
- **Rate limiting (KV):** Free = 3 AI calls/day, Pro = 10 calls/day
- **Secrets:** `APP_SECRET`, `JWT_SECRET`, `CLAUDE_API_KEY`, `RESEND_API_KEY`
- **Auth:** Custom JWT (HS256), 90-day expiry, PBKDF2 password hashing

---

## Current Development Focus

**Primary:** Polish iOS version for App Store submission
**Secondary:** Polish macOS version

Areas of focus:
- UX improvements across all screens
- iOS-specific layout and interaction quality
- Bug fixes
- Consistency between macOS and iOS experiences

---

## Known Issues / Notes

- Some code was lost due to a bad git push (exact scope TBD — check with Danylo before rewriting anything from scratch)
- macOS already has a live version — avoid breaking it while polishing iOS

---

## Changelog

### 2026-03-24
- Updated README.md to include iOS platform info
- Created this AI_CONTEXT.md file
- Confirmed project state: macOS live, iOS in development, polish phase

---

## Developer

**Danylo Kovalenko**
© 2026 — All rights reserved
