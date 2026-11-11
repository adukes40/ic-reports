# CampusView KPIs

Attendance and referral KPIs, each as one standalone query.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 139 | [Attendance rate](01-attendance-rate.sql) | Not run yet | Minute-weighted attendance rate per school and grade for the year so far: (scheduled minutes - absent minutes) / scheduled minutes, summed over every student day. Daily rates are never averaged. |
| 140 | [Chronic absence by school + student list](02-chronic-absence-by-school.sql) | Not run yet | Per student per school, instructional days enrolled and full-day absences from Oct 1 to May 20, flagged chronic when absences are 10% or more of the student's own days. School and district totals ride along on every row. |
| 141 | [Attendance by school day](03-attendance-by-school-day.sql) | Not run yet | Per school per instructional day so far this year: membership, students absent all day and the minute-weighted attendance rate. Days with zero scheduled minutes are left out. |
| 142 | [Referrals by type, location, status](04-referrals-by-type-location-status.sql) | Not run yet | Counts this year's offender referrals by event type, incident location and incident status. Incidents with no status get their own bucket and count as open. |
| 143 | [Open referrals with age buckets](05-open-referrals-age-buckets.sql) | Not run yet | Lists this year's behavior incidents that are not marked complete, with the days open since the incident date and an age bucket. |
| 144 | [Referrals not processed](06-referrals-not-processed.sql) | Not run yet | Lists this year's offender referrals that have no resolution and whose incident is not marked complete, oldest first. |
| 145 | [Resolution mix](07-resolution-mix.sql) | Not run yet | Counts this year's behavior resolutions by resolution type per school, with each type's share of the school's resolutions. |
| 146 | [Time to action / time to resolve](08-time-to-action.sql) | Not run yet | Per school, the mean and median days from the incident date to the date each resolution was assigned. Resolutions dated before their incident are counted separately and left out of the averages. |
| 147 | [Violence-flagged referrals](09-violence-flagged-referrals.sql) | Not run yet | Lists this year's behavior events flagged as violent, or whose event type carries one of the state event codes you list, with each offender's grade. |
| 148 | [Top referral students](10-top-referral-students.sql) | Not run yet | The students with the most offender referrals this year, with the date of their latest referral. |

[← Back to the library](../../README.md)
