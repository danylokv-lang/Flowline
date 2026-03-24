# Flowline Growth Roadmap

## Goal
Make users stay, pay, and recommend.
First impression → daily habit → can't live without it → upgrade.

---

## Phase A — Widget (Retention #1)

**Why first**: Every home screen glance = app in user's brain all day.

### A.1 Home Screen Widget
- Small: current block title + time remaining
- Medium: today's next 3 blocks
- Large: full today schedule at a glance
- Updates every 15 min via WidgetKit + AppIntent
- Uses shared SwiftData container (same data as main app)

### A.2 Lock Screen Widget
- Single line: "Deep Work · 1h 20m left"
- Shows when no block active: "Tap to plan your day"

### A.3 Standby Mode (iPhone 15+)
- Full-screen clock + current block shown while charging

---

## Phase B — Push Notifications (Activation)

**Why second**: Silent app = forgotten app. Notifications = daily touchpoint.

### B.1 Block Reminders
- "Your Deep Work block starts in 10 min"
- Configurable: 5 / 10 / 15 min before

### B.2 Planning Nudge
- If no plan exists by 9am → "You haven't planned today yet. 30 seconds?"
- If no plan exists for tomorrow by 9pm → "Plan tomorrow before you sleep?"

### B.3 Streak Alerts
- "6-day streak 🔥 Don't break the chain — plan today"
- If user missed yesterday and had a streak → "Start a new streak today"

### B.4 Weekly Summary (Sunday evening)
- "This week: 5 days planned · 68% completion · 3-day streak"
- Tappable → opens weekly stats

---

## Phase C — Onboarding (Delete Prevention)

**Why third**: 80% of deletes happen in first 3 days. Fix this = fix retention.

### C.1 Guided First Plan
- Step 1: "What time do you wake up / sleep?"
- Step 2: "What's your main thing? (Work / Study / Mixed)"
- Step 3: "Any fixed commitments? (classes, meetings, gym)"
- → AI generates first plan immediately, personalized
- → Show week view right after save — "this is your life, organized"

### C.2 Value-First Paywall
- Current: limit shown at signup → feels punishing
- New: paywall shown AFTER first successful save → "You just planned your first day. Go Pro to plan every day."
- Show: "Users on Pro plan 3x more likely to hit their weekly goals"

### C.3 Day 1 Checklist
- Small in-app checklist: "Set wake time ✓ · Create first plan · Save to calendar · Try Focus timer"
- Completes in 5 min, gives user a win immediately

---

## Phase D — Calendar Two-Way Sync (Indispensable)

**Why fourth**: Once Flowline IS your calendar, switching cost is huge.

### D.1 Read Apple/Google Events Into AI
- Pull native calendar events into planning context (already partially done)
- AI sees "You have a 2pm meeting" and plans around it automatically

### D.2 Push Flowline Blocks to Native Calendar
- "Add to Calendar" exports blocks as real Apple Calendar events
- User sees Flowline plan in every calendar app (Mac Calendar, Google, etc.)
- One-tap sync for entire day or single block

### D.3 Conflict Detection
- Before saving → check for clashes with existing calendar events
- "You have a dentist appointment at 3pm — I moved your gym to 5pm"

---

## Phase E — End-of-Day Flow (Daily Ritual)

**Why fifth**: Ritual = retention. Dopamine loop = habit.

### E.1 Evening Check-In (8pm notification)
- "How did your day go?"
- Quick rating per block: ✓ Done / ~ Partly / ✗ Missed
- Takes 30 seconds

### E.2 Completion Summary
- "You completed 7/9 blocks today · 78% 🔥"
- Streak update with animation
- One motivational line based on performance

### E.3 Tomorrow CTA
- Immediately after: "Plan tomorrow now? (30 seconds)"
- Pre-fills with recurring commitments already locked in
- Creates loop: complete → reflect → plan → complete

---

## Phase F — AI Memory (Magic Feel)

**Why last**: Good to have, not must-have. But makes the app feel alive.

### F.1 Preferences Memory
- "You always put gym at 5pm — keeping that as default"
- "You prefer 90-min deep work blocks — done"

### F.2 Pattern Recognition
- After 2 weeks: "Your most productive day is Tuesday — I load it with deep work"
- "You rarely complete evening study — moved it to morning"

### F.3 Weekly Learning
- Review completion data → adjust future plan suggestions
- "Last week you skipped gym 3x — should I reduce gym days?"

---

## What NOT to Build (Avoid Scope Creep)
- ❌ Social features / sharing plans
- ❌ Team / collaborative planning
- ❌ Marketplace / templates store
- ❌ Custom themes / colors
- ❌ Web app version

These sound cool, distract from core retention loop.
Focus: open app → plan → follow plan → feel good → repeat.

---

## Monetization Notes
- Free: 3 saves/week, 3 AI/day, no widget, no notifications
- Pro: unlimited everything + widget + notifications + calendar sync
- Show value BEFORE paywall, not at signup
- Yearly plan = 2 months free → push this over monthly
- Target: if user uses app 3+ days in first week → 40%+ convert to Pro

---

## Core Loop We're Building
```
Wake up → Widget shows today's plan
         ↓
Follow blocks during day
         ↓
Focus timer for deep work
         ↓
Evening check-in: rate your day
         ↓
AI: "Nice work. Plan tomorrow?"
         ↓
Streak grows → never want to break it
         ↓
Hit free limit → upgrade to Pro (already hooked)
```

This loop = users that stay for years, not days.
