Sable Markdown Writer 0.11.0 adds a writing goal with a deadline, for challenges like 50,000 words in November.

- **A goal with a deadline, only if you want one.** It's off by default. In Settings → General, just above your writing record, turn on **Track a goal with a deadline**, then pick **November: 50,000 words** or **Custom…** and choose a word count, a start date, and an end date. Settings then shows your words so far, where an even pace would have you today, what today needs for the goal to finish on time, and how many days are left. A chart plots your running total against a dashed pace line, alongside the 30-day record below it.
- **A calm way to read it.** If you're running under an even pace, Sable says so in plain numbers, such as "1,900 a day finishes on time," and if you're ahead it says you're on pace. There are no streaks, badges, or notifications. Like the writing record, the goal counts only words you add; deleting words never takes anything away.
- **Today's share in the footer, if you want it.** Turn on **Show today's share in the footer** and a small "1,204 / 1,667 today" sits beside the session goal while the goal is running. It's off by default.
- **Turn it off any time.** With the switch off, no goal shows in Settings or in the footer, and a goal you set earlier is kept for next time.
- **One goal at a time, and the record stays.** **Clear Goal** removes the goal and keeps your writing record, and clearing the record keeps your goal. Both stay on this Mac only.
- **Dates work the way you'd expect.** A goal is a run of calendar days. The end date counts in full, words you write on the start date all count even if you wrote them before setting the goal, and a clock change or a trip to another time zone doesn't shift the days.
- **Under the hood:** `check-writing-history.swift` now also covers the pace math, including a goal that starts mid-day, the end date itself, clock changes, leap years, goals that cross New Year, and damaged stored goals.

_Release notes written by Claude Code._
