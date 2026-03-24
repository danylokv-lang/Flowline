# Phase 1-3 Testing Checklist

## Phase 1: Critical Blockers

### 1.1 Truncated Responses Fix
- [ ] **iOS**: Open Plan chat
- [ ] Send: "Plan my whole day. I have: morning workout 6-7am, team standup 9-10am, lunch 12-1pm, deep work block 2-5pm, gym 5-6:30pm, dinner 6:30-7:30pm, then wind down"
- [ ] **Verify**: All blocks display completely (no "Breakfast 0" cutoff)
- [ ] **Expected**: Full schedule with all times visible

### 1.2 Save Button Visibility Fix
- [ ] **iOS**: Generate any plan in chat
- [ ] **Verify**: Save button appears (even if AI doesn't end with "Save this to calendar?")
- [ ] **Expected**: Button shows checkmark + "Save Plan" text
- [ ] **Verify**: Button is clickable and opens calendar picker

### 1.3 macOS Counter Text
- [ ] **macOS**: Open chat tab
- [ ] **Verify**: At bottom of input area, see "0/3 plans saved this week"
- [ ] **Expected**: Text visible even before creating first plan
- [ ] **After creating a plan**: Counter should show "1/3 plans saved this week"

---

## Phase 2: Speed Improvements

### 2.1 System Prompt Optimization
- [ ] **iOS**: Send "Plan my day. I code in the morning, have standup at 10am, then gym at 5pm"
- [ ] **Measure**: Response time should be 3-5 seconds
- [ ] **Verify**: Standup appears at 10am as fixed block (not moved)
- [ ] **Verify**: Gym appears at 5pm (not rescheduled)
- [ ] **Expected**: Recurring commitments treated as immovable

### 2.2 Auto-Show Calendar Picker
- [ ] **iOS**: Generate a plan in chat (after Phase 1.1 check)
- [ ] **Wait**: 0.5-1 second after plan appears
- [ ] **Verify**: Calendar picker sheet auto-appears (don't need to tap button)
- [ ] **Verify**: Can dismiss it by tapping outside or back
- [ ] **Verify**: Can select calendar and tap "Save"

### 2.3 Instant Visual Feedback
- [ ] **iOS**: Tap send on a message
- [ ] **Verify**: "Thinking..." shimmer appears immediately (no blank delay)
- [ ] **Expected**: Visual feedback before any network request completes

---

## Phase 3: Improved Plan Realism

### 3.1 Recurring Commitments
- [ ] **iOS**: In profile, add recurring commitment: "Daily standup: Monday-Friday 9:00-9:30am"
- [ ] **Plan a day**: Send "Plan my day"
- [ ] **Verify**: Standup appears exactly at 9:00-9:30am
- [ ] **Verify**: Not moved, not renamed, not skipped
- [ ] **Plan another day**: Repeat for Tuesday - standup still at exact same time
- [ ] **Expected**: Recurring blocks are truly immovable

### 3.2 Plan Validation
- [ ] **iOS**: Send "Plan my day: deep coding 8am-12:30pm, then deep coding 1-5pm (no break)"
- [ ] **Tap**: Save Plan button
- [ ] **Wait**: 1-2 seconds for validation
- [ ] **Verify**: "Plan Review" sheet appears with warnings:
  - "⚠️ 'Deep coding' is 4h 30m — consider adding a break"
  - Or similar warning about consecutive hours
- [ ] **Verify**: Two buttons: "Edit Plan" and "Save Anyway"
- [ ] **Tap "Edit Plan"**: Dialog closes, you can refine in chat
- [ ] **Test "Save Anyway"**: Send same plan again, tap Save, tap "Save Anyway" - plan saves
- [ ] **Expected**: User warned about unrealistic plans

### 3.3 Plan Refinement Suggestions
- [ ] **iOS**: Generate a normal plan in chat
- [ ] **Verify**: Below the plan, see "Adjust this plan:" with buttons:
  - "+ Break"
  - "📱 Evening"
  - "⚡ Morning"
  - "🎯 Shorter"
- [ ] **Tap**: "+ Break" button
- [ ] **Verify**: Message sent: "Add a 20-30 min break"
- [ ] **Verify**: AI responds with refined plan that includes breaks
- [ ] **Tap**: "📱 Evening" on a different plan
- [ ] **Verify**: Non-urgent tasks moved to evening
- [ ] **Expected**: Quick refinements without full regeneration

---

## Edge Cases to Test

- [ ] **No plan in message**: Refinement suggestions don't appear
- [ ] **Error message in chat**: No refinement suggestions shown
- [ ] **Multiple plans in session**: Each shows its own refinement buttons
- [ ] **At plan limit**: Calendar picker doesn't auto-show (shows banner instead)
- [ ] **iPhone + macOS parity**: Counter visible on both devices

---

## Build & Run Steps

1. Build iOS app in Xcode
2. Run on iOS Simulator or real iPhone
3. Log in with test account
4. Follow checklist items in order
5. Note any failures with exact steps to reproduce

---

## Known Limitations (Expected)

- Validation warnings are suggestions only - user can override
- Refinement suggestions are template prompts (AI will adapt)
- Auto-picker can be dismissed (not forced save)
- Platform-specific UI might differ slightly (iOS vs macOS)

