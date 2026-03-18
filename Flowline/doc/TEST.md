# Flowline AI Test Cases

Use these to test the AI in a fresh chat session each time (sidebar → New Chat).

---

## PROFILE SETUP — paste this into Profile → Bio

```
I'm a software engineering student. University lectures Mon–Wed until 14:00.
I work best in the mornings 08:00–12:00. Gym on Mon, Wed, Fri.
Learning backend development, do side projects in the evenings.
I read 30 min before bed. Don't schedule anything before 08:00.
```

**Wake:** 07:00
**Sleep:** 23:30
**Fixed hours:** 09:00 – 14:00

---

## WEEK PLAN PROMPT — send this to test full week planning

```
Plan my whole week. Monday and Tuesday mornings study system design, every evening work on my portfolio backend project, gym Mon/Wed/Fri. Saturday full deep work day on backend. Sunday is rest — just a walk and reading.
```

**Expected:**
- 7 days appear in calendar (Mon–Sun)
- Each day has blocks with correct dates
- No 2h+ empty gaps during the day
- Block titles have no duration like "(1h)"
- Gym blocks appear on Mon, Wed, Fri only

---

## SINGLE DAY PROMPT — test basic planning

```
Today I need to: go to the gym, write a cold email to Google, study algorithms for 2 hours, and review a pull request
```

**Expected:**
- Plan built immediately, no questions
- Gym ~45–60 min, email ~25 min, algorithms 2h (respected), PR review ~35 min
- No gaps bigger than 30 min left empty

---

## ADD TASK PROMPT — run AFTER saving a plan

```
Add English practice for 1 hour on Thursday evening
```

**Expected:**
- Only Thursday gets a new block
- All other saved days stay untouched

---

## SHORT REPLY TEST

```
Thanks, looks good
```

**Expected:** 1–5 words back. Not a paragraph.

---

## PREDICTION TEST

```
I want to send a cold email to Google today
```

**Expected:** AI schedules ~20–30 min, title "Cold email to Google", no questions about how long it takes.

---

## FUTURE DATE TEST

```
Plan my day for next Monday
```

**Expected:** AI treats it as upcoming, never says it already passed.

---

## PROFILE RECOGNITION TEST

```
Who am I and what do you know about my schedule?
```

**Expected:** AI mentions your name, wake/sleep, lectures, gym days, and bio.

---

## LANGUAGE TEST

```
Запланируй мою неделю. Хочу учить алгоритмы каждое утро, ходить в зал пн/ср/пт, вечером работать над проектом.
```

**Expected:** Full response and plan in Russian.

---

## CHECKLIST — after each test

- [ ] No questions asked when tasks are clear
- [ ] No duration in block titles (no "Gym (1h)")
- [ ] No 2h+ empty gaps in schedule
- [ ] Week plan = 7 days, not 5
- [ ] Adding task keeps existing blocks
- [ ] Future dates treated as upcoming
- [ ] Short messages get short replies
- [ ] Profile name + bio recognized
