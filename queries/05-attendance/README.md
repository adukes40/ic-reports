# Attendance

Attendance that was not taken, chronic absence, daily rates and absence patterns.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 53 | [Attendance not taken](01-attendance-not-taken.sql) | Not run yet | Sections that met on the chosen day and have students on the roster, but no teacher attendance was saved for them. |
| 54 | [Chronic absence list + rate](02-chronic-absence-list-rate.sql) | Not run yet | Instructional days enrolled, full-day absences and percent absent per student per school this year, flagging 10% or more, with the school's chronic absence rate beside it. |
| 55 | [Average daily attendance / membership](03-average-daily-attendance-membership.sql) | Not run yet | Students enrolled (membership), students present and the attendance rate for each school on each instructional day in the date range. |
| 56 | [Unknown-excuse absences](04-unknown-excuse-absences.sql) | Not run yet | Absences this year that are still coded with an Unknown excuse more than @days days after the absence date. |
| 57 | [Attendance changed after the fact](05-attendance-changed-after-the-fact.sql) | Not run yet | Attendance records added, changed or deleted more than @days days after the attendance date, with who did it, when, and the old and new code. |
| 58 | [Attendance on non-school days](06-attendance-on-non-school-days.sql) | Not run yet | Attendance recorded on dates that are outside the calendar, have no Day record, or are marked non-instructional or not for attendance. |

[← Back to the library](../../README.md)
