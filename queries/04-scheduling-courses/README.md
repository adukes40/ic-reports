# Scheduling & courses

Schedule gaps, double bookings, section setup, class sizes and course requests.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 42 | [MS/HS students with empty periods](01-secondary-students-empty-periods.sql) | Not run yet | Active students in grades 6-12 with a gap in their day: a period in their calendar's period schedule where they have no class on @asOf. |
| 43 | [Double-booked students](02-double-booked-students.sql) | Not run yet | Students rostered on @asOf into two or more sections that meet in the same period of the same term and period schedule (day). |
| 44 | [Sections with no primary teacher or room](03-sections-no-primary-teacher-or-room.sql) | Not run yet | Active-trial sections that have students on @asOf but no active primary teacher, or no room. These break rosters, state course reporting and ClassLink. |
| 45 | [Section roster dates outside enrollment](04-roster-dates-outside-enrollment.sql) | Not run yet | Roster rows in the active trial whose start date is before the student's enrollment start, or whose end date is after the enrollment end. |

[← Back to the library](../../README.md)
