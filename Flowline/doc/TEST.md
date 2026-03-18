# Flowline AI – Test Cases

Test these in a **New Chat** each time (sidebar → New Chat).
After each test, check: did AI respond correctly? Did it save to the right day?

---

## 1. Basic Single-Day Plan
**Send:** `I need to write an email to Google, go to the gym, and do 2 hours of coding today`

**Expected:**
- AI builds a plan immediately — NO questions asked
- Gym gets ~45–60 min, coding gets 2 hours (respected), email gets ~20–30 min
- Plan fits within your wake/sleep window from profile
- Save button appears → press it → calendar shows today's blocks

---

## 2. Vague Message (One Question Rule)
**Send:** `plan my day`

**Expected:**
- AI asks ONE short question: what tasks do you have today?
- It does NOT ask multiple follow-ups like "what time do you wake up?" or "do you have meetings?"

**Then reply:** `I have a client call and need to review a contract`

**Expected:**
- AI builds the plan immediately after your reply — no more questions

---

## 3. Time Estimation (Prediction Test)
**Send:** `I want to write a proposal for a new client today`

**Expected:**
- AI estimates ~60–90 min for the proposal
- AI briefly mentions the estimate: "I'll give you 90 min for the proposal"
- Schedules it as one block, not split weirdly

---

## 4. Full Week Plan
**Send:** `Plan my full work week. Monday: deep coding session and team meeting. Tuesday: client presentation. Wednesday: free. Thursday: code review and planning. Friday: wrap up weekly tasks and gym`

**Expected:**
- AI creates blocks on Mon, Tue, Thu, Fri with the mentioned tasks
- Wednesday stays empty or minimal
- Save → Calendar shows 5 different days with correct blocks
- **Bug check:** Does NOT delete any existing events from this week

---

## 5. Adding to Existing Plan (No Delete Test)
First save a plan (use test 1). Then in a new message:

**Send:** `Add a dentist appointment at 3pm today`

**Expected:**
- AI adds the dentist block and keeps all existing blocks
- It does NOT say "I've replaced your day with a new plan"
- Save → Calendar shows old blocks + new dentist block

---

## 6. Profile Awareness Test
**Before this test:** make sure your profile has a name, wake time, and bio set.

**Send:** `What do you know about me?`

**Expected:**
- AI mentions your name
- AI knows your wake/sleep times
- AI mentions your work hours if set
- AI references your bio context if you wrote one

---

## 7. Language Detection
**Send (in another language):** `Planuji dnes: jóga ráno, práce na projektu 3 hodiny, večeře s přáteli`
*(Czech: "Planning today: morning yoga, 3 hours of project work, dinner with friends")*

**Expected:**
- AI responds in Czech
- Builds a plan with the 3 activities
- Saves correctly

---

## 8. replaceWeek Protection Test
First save a full week plan. Then:

**Send:** `Plan next week for me. Monday gym and coding, Tuesday client calls, rest of week free`

**Expected:**
- AI plans NEXT week (not this week)
- **This week's events stay untouched** in the calendar
- Next week gets the new blocks
- `replaceWeek` must be false

---

## 9. Short Task Recognition
**Send:** `Quick reply to 3 emails and review pull request`

**Expected:**
- Emails: ~15–20 min each or grouped as one 45 min block
- Pull request review: ~30–45 min
- AI doesn't over-inflate simple tasks to multi-hour blocks

---

## 10. Stress Test (Many Tasks)
**Send:** `Today I need to: morning run, shower, breakfast, deep work session on backend, lunch, 1:1 meeting with boss, write documentation, read emails, dinner, read a book before sleep`

**Expected:**
- All tasks scheduled in order, nothing overlapping
- Fits between your profile wake and sleep time
- Breaks between heavy tasks
- Save → Calendar shows a full packed day

---

## What to Check on Every Test
- [ ] Did AI ask too many questions? (should be max 1)
- [ ] Did AI use your name / profile info?
- [ ] Did the saved blocks show on the right days in Calendar?
- [ ] Is Sunday visible in Calendar?
- [ ] Did AI ever delete existing events it shouldn't have?
- [ ] Did the response feel fast and decisive?
