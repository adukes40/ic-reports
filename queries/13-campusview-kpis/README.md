# CampusView KPIs

Attendance and referral KPIs, each as one standalone query.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 139 | [Attendance rate](01-attendance-rate.sql) | Not run yet | Minute-weighted attendance rate per school and grade for the year so far: (scheduled minutes - absent minutes) / scheduled minutes, summed over every student day. Daily rates are never averaged. |
| 140 | [Chronic absence by school + student list](02-chronic-absence-by-school.sql) | Not run yet | Per student per school, instructional days enrolled and full-day absences from Oct 1 to May 20, flagged chronic when absences are 10% or more of the student's own days. School and district totals ride along on every row. |
| 141 | [Attendance by school day](03-attendance-by-school-day.sql) | Not run yet | Per school per instructional day so far this year: membership, students absent all day and the minute-weighted attendance rate. Days with zero scheduled minutes are left out. |

[← Back to the library](../../README.md)
