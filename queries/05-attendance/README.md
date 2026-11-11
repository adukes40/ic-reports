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
| 59 | [OSS days vs. attendance mismatch](07-oss-days-vs-attendance-mismatch.sql) | Not run yet | Out-of-school suspension days with no OSS attendance code on that date, and OSS attendance codes on dates no suspension covers. |
| 60 | [Consecutive absences](08-consecutive-absences.sql) | Not run yet | Active students absent all day for @n or more instructional days in a row, ending on the latest instructional day up to @asOf. |
| 61 | [Period skipping](09-period-skipping.sql) | Not run yet | Students who were at school for the day but marked absent from one or more periods, counted by period over the date range. |
| 62 | [Tardies](10-tardies.sql) | Not run yet | Tardy counts per student and period over the date range, for students with @minTardies or more tardies in total. |
| 63 | [Perfect attendance](11-perfect-attendance.sql) | Not run yet | Students enrolled for every instructional day in the date range with no absence and no tardy of any kind. |
| 64 | [Attendance by subgroup](12-attendance-by-subgroup.sql) | Not run yet | Attendance rate by school and grade, for all students and broken out by race/ethnicity, gender, special ed and EL. |

[← Back to the library](../../README.md)
