# Enrollment & census

Enrollment records that overlap, are missing, or have wrong dates or codes.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 15 | [Overlapping primary enrollments](01-overlapping-primary-enrollments.sql) | Confirmed good | Students with two primary enrollments whose dates overlap, shown side by side. |
| 16 | [Prior-year enrollment not ended](02-prior-year-enrollment-not-ended.sql) | Confirmed good | Enrollments in calendars before @endYear that still have no end date. |
| 17 | [Grade level not in calendar](03-grade-level-not-in-calendar.sql) | Confirmed good | Current-year enrollments whose grade isn't set up in that calendar and schedule structure. |
| 18 | [Enrolled with no schedule](04-enrolled-with-no-schedule.sql) | Confirmed good | Active primary enrollments with no roster row in the active trial on @asOf. |
| 19 | [Duplicate people / duplicate IDs](05-duplicate-people-ids.sql) | Confirmed good | Same first name, last name and birthdate, plus any studentNumber or stateID shared by two or more people. |
| 20 | [End date / end status mismatch](06-end-date-end-status-mismatch.sql) | Confirmed good | End date with no end status, end status with no end date, or a graduation end status below grade 12. |
| 21 | [Enrollment dates outside calendar](07-enrollment-dates-outside-calendar.sql) | Confirmed good | Enrollments that start before the calendar starts or end after it ends. |
| 22 | [Withdrawn but still rostered](08-withdrawn-but-still-rostered.sql) | Confirmed good | Active-trial roster rows left open, or ending after the student's last enrollment end in that calendar. |
| 23 | [No-shows](09-no-shows.sql) | Needs review | Active primary enrollments with no day present since the start date. |
| 24 | [Age out of range for grade](10-age-out-of-range-for-grade.sql) | Confirmed good | Age on Sept 1 outside the usual range for the grade, any student over 21, or a missing birthdate. |
| 25 | [State-excluded enrollments](11-state-excluded-enrollments.sql) | Confirmed good | Current-year enrollments with state exclude set, so each can be confirmed. |
| 26 | [Active student with a graduation date](12-active-student-with-graduation-date.sql) | Confirmed good | Students active today who already have a diploma date or diploma type on their graduation record. |
| 27 | [Next-year placement missing](13-next-year-placement-missing.sql) | Confirmed good | Active students below grade 12 with no next-year placement, or a next grade the next calendar doesn't offer. |
| 28 | [Secondary enrollment with no primary](14-secondary-enrollment-no-primary.sql) | Confirmed good | Active secondary or partial enrollments for students with no active primary enrollment on the same date. |
| 29 | [Very short enrollments](15-very-short-enrollments.sql) | Confirmed good | Ended enrollments this year that lasted fewer than @minDays instructional days. |

[← Back to the library](../../README.md)
