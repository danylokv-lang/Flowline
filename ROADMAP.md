# Flowline — Build Roadmap

## How to Think About This Build

Build the smallest version that proves the core value — then layer on top. The core value is: **brain-dump tasks → get a usable day schedule → stay focused.**

Everything else (blocking, sync, stats, templates) comes after that loop works and feels good.

---

## Phase 0 — Foundation (Week 1–2)

Before writing any feature code, get the technical foundation solid. This saves you from refactoring nightmares later.

### Xcode Project Setup
- [ ] Set up SwiftUI project targeting iOS 17+ and macOS 14+ (use multiplatform target)
- [ ] Configure folder structure: `Features/`, `Models/`, `Services/`, `DesignSystem/`
- [ ] Set up SwiftData (or Core Data) for local persistence
- [ ] Add basic light/dark theme support via a `ThemeManager`

### Design System
- [ ] Define your color palette: background, surface, text primary/secondary, accent, category colors (Study, Work, Health, Personal)
- [ ] Define typography scale (title, heading, body, caption)
- [ ] Build reusable components: `PrimaryButton`, `TaskCard`, `SectionHeader`
- [ ] Test colors in both light and dark mode before building any screens

### Data Models
Define your core models early — they underpin everything:

```swift
Task
  - id: UUID
  - title: String
  - category: Category (Study, Work, Health, Personal)
  - estimatedMinutes: Int?
  - deadline: Date?
  - priority: Priority (low, medium, high)
  - isCompleted: Bool

ScheduledBlock
  - id: UUID
  - task: Task
  - startTime: Date
  - endTime: Date
  - isProtected: Bool
  - completionStatus: BlockStatus? (completed, partial, skipped)

DayPlan
  - date: Date
  - blocks: [ScheduledBlock]
  - createdAt: Date
```

**Deliverable:** App launches, shows a blank screen with your design system applied, data models compile.

---

## Phase 1 — Task Inbox (Week 2–3)

This is your entry point. Get task input feeling fast and smooth.

### What to Build
- Task inbox screen: scrollable list of today's tasks
- Add task flow: text input, optional category picker, optional duration/priority
- Swipe to delete, tap to edit
- Empty state: friendly illustration + "Add your first task"
- Persist tasks with SwiftData

### Key UX Details
- The input field should be front and center — this is a fast-capture tool
- Don't make category/duration required. The AI will handle estimates.
- Categories should be color-coded from day one (Study = blue, Work = purple, Health = green, Personal = orange — adjust to match your palette)

**Deliverable:** You can add, edit, delete, and view tasks. Data survives app relaunch.

---

## Phase 2 — AI Day Planning (Week 3–5)

This is the core magic. Everything else depends on this working well.

### Claude API Integration
- Add the Anthropic SDK (or call the API directly via URLSession)
- Build a `PlanningService` that takes a task list + user constraints and returns a structured schedule
- Use structured output / JSON mode so the response is always parseable

### Prompt Design
Your prompt should include:
- The task list with metadata (title, duration estimate, category, deadline, priority)
- User's wake time and sleep time
- Current time of day
- Any fixed commitments already on the calendar
- Instruction to output an array of `{ taskId, startTime, endTime }` objects

Start simple. Refine the prompt based on actual outputs.

### Replan Logic
- "Replan" button: sends current time + completed/skipped blocks + remaining tasks
- AI regenerates only the unfinished portion of the day
- UI smoothly updates (animate blocks sliding into new positions)

### Plan My Day Button
- Show a loading state with a subtle animation while AI generates
- On success: transition to Timeline view
- On failure: show inline error, keep task list intact

**Deliverable:** Tap "Plan my day," get a real AI-generated schedule. Tap "Replan" mid-day and the schedule updates.

---

## Phase 3 — Visual Timeline (Week 5–7)

The timeline is your app's face. Make it beautiful.

### Layout
- Vertical scrollable timeline (like a calendar day view)
- Current time indicator (red/accent line)
- Hour markers on the left
- Task blocks fill the timeline proportionally to their duration

### Block Design
- Rounded rectangle with category color (soft, not saturated)
- Task title, time range, duration
- "Protected" icon (lock) if focus blocking is on
- Completion state: checked/faded when done

### Micro-animations
- Plan creation: blocks animate in from the right or fade in staggered
- Block completion: satisfying checkmark animation + block fades/shrinks
- Replan: existing blocks smoothly reposition (use `withAnimation(.spring)`)

### Interaction
- Tap a block: expand to see full task details + action buttons
- Long press: quick complete or skip
- Scroll naturally through the full day

**Deliverable:** A beautiful timeline that clearly shows your day and feels good to interact with.

---

## Phase 4 — Focus Blocking (Week 7–9)

This is your biggest technical challenge. Tackle Mac and iPhone separately.

### iPhone — Screen Time API
- Use `FamilyControls` and `ManagedSettings` frameworks
- Request authorization: `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
- When a block starts: apply `ManagedSettingsStore` restrictions to selected app tokens
- When a block ends: remove restrictions
- User selects their "distraction apps" once during onboarding using `FamilyActivityPicker`

**Note:** Screen Time API requires an entitlement from Apple. Apply early — it can take a few days to get approved.

### Mac — Focus / Shell-Based Blocking
- For Mac, use a simpler approach first: modify `/etc/hosts` to block domains (requires helper tool with elevated privileges)
- Optionally integrate with macOS Focus modes via `EventKit` or Shell scripts
- Use a Launch Agent (privileged helper via `SMJobBless`) to apply/remove blocks without requiring a password each time

### Block Activation Flow
1. Block start time triggers a local notification + background timer
2. App activates blocking for selected distraction list
3. Block end time: deactivate blocking, trigger check-in prompt
4. All automatic — user just needs to have set it up once

**Deliverable:** Protected blocks actually prevent access to distraction apps on device during the block.

---

## Phase 5 — Micro Check-ins & Adaptation (Week 9–10)

Close the feedback loop so the AI gets smarter over time.

### Check-in UI
- Triggered after each block ends (local notification or in-app prompt)
- Simple full-screen card: "How did that go?"
- Three big tappable options: ✅ Done / ⚡ Partly / ✗ Skipped
- Optional: free-text note (one line max, optional)

### Storing Feedback
- Save `BlockStatus` to the block record in SwiftData
- Track completion rate per category, time-of-day, and task type

### AI Adaptation
- When replanning, include recent check-in history in the prompt
- Example context: "User consistently skips study blocks after 8pm" → AI schedules them earlier
- Subtle, not dramatic — the plan just gets quietly better over time

**Deliverable:** After each block, a check-in appears. History is stored. The next AI plan reflects recent patterns.

---

## Phase 6 — Polish & Pro Features (Week 10–12)

Now make it feel like a real product.

### Onboarding
- 3-4 screens: What is Flowline, set your wake/sleep times, pick your distraction apps, choose your first day template
- Skip-friendly: don't force too much setup

### Day Templates
- Preset constraint sets: School Day, Exam Day, Deep Work, Weekend
- User can create custom templates
- Selected before tapping "Plan my day"

### Stats & Insights
- Weekly view: focus hours per day (bar chart)
- Completion rate over time (line chart)
- Most-skipped task category
- "Best focus time of day" based on check-in data

### Extra Themes
- 3–4 curated color themes beyond the default
- Option to customize category colors
- Wallpaper/accent color integration on iPhone

### Subscription Paywall
- Use RevenueCat for subscription management (easiest for iOS + macOS)
- Free tier: 1 AI plan/day, one device, no templates
- Pro: unlimited, cross-device, templates, stats, themes
- Paywall triggers naturally: second AI plan attempt, cross-device setup, template selection

**Deliverable:** App is ready for TestFlight. Monetization is implemented. Onboarding is smooth.

---

## Phase 7 — Launch Prep (Week 12–13)

- App Store screenshots (iPhone 15 Pro + Mac)
- App Store description and keywords
- Privacy policy (required — you use AI and Screen Time)
- Submit for App Store Review
- Set up a simple landing page (even just a single page with screenshots)
- TestFlight beta with 5–10 real users before wide release

---

## Tech Stack Summary

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI | Native, fast, best for animations |
| Data | SwiftData | Simple, native, works across iOS + Mac |
| AI | Claude API (Anthropic) | Best for structured scheduling prompts |
| Subscriptions | RevenueCat | Handles iOS + Mac receipts, easy |
| iPhone Blocking | FamilyControls / ManagedSettings | Official Apple API |
| Mac Blocking | Privileged Helper + /etc/hosts | Most reliable approach |
| Notifications | UNUserNotificationCenter | Block start/end triggers |

---

## What to Validate First

Before writing a line of code, validate the riskiest assumptions:

1. **Can the Claude API reliably produce a well-structured schedule from a task list?** → Test this with raw API calls before building any UI around it.
2. **Can you get the Screen Time entitlement from Apple?** → Apply as early as possible.
3. **Does the blocking actually work without being too easy to bypass?** → Test on a real device with real distracting apps.

If any of these fail, your architecture might need to change. Better to know early.

---

## Order of Priority (if time is limited)

1. Task Inbox (Phase 1) — without this, nothing else exists
2. AI Planning (Phase 2) — this is the core value proposition
3. Timeline UI (Phase 3) — without this, the plan is invisible
4. Check-ins (Phase 5) — low effort, high value, builds trust
5. Blocking (Phase 4) — technically hard, but is a major differentiator
6. Polish + Pro (Phase 6) — only once the core loop is solid

---

## One Rule

**Ship a working core loop before adding anything else.**

A beautiful timeline with real AI planning and no blocking is already a better product than most apps in this space. Get that working first, get real users on it, then add blocking and stats on top of proven demand.
