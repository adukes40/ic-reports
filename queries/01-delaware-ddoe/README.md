# Delaware DOE

State reporting checks: unit count, DSSF, discipline, SPED, immunizations.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 1 | [Unit count readiness](01-unit-count-readiness.sql) | 🟢 Confirmed good | Two unit-count problems in the last 10 instructional days of September: enrolled but never present, and attendance on a day with no primary enrollment. |
| 2 | [Unit count transfers](02-unit-count-transfers.sql) | 🟡 Needs review | Primary enrollments that started or ended inside the count window, with where the student came from or went. |
| 3 | [Funding / accountability / CRDC school blanks](03-funding-accountability-crdc-blanks.sql) | 🟡 Needs review | Current primary enrollments missing Funding School, Accountability School or CRDC School of Accountability, or still using retired DAFB code 100893. |
| 4 | [Students missing state ID / Ed-Fi ID](04-missing-state-id-edfi-id.sql) | 🟡 Needs review | Active students with no state ID or Ed-Fi ID, and active staff with no staff state ID. |
| 5 | [Courses missing SCED or CIP codes](05-courses-missing-sced-cip.sql) | 🔴 Broken | Active courses with students rostered today but no SCED code, and CTE courses with no CIP code. |
| 6 | [On Track in 9th Grade](06-on-track-9th-grade.sql) | ⚪ Not run yet | Credits earned this year by first-time 9th graders across ELA, math, science, social studies and world languages, with an on-track flag and school rate. |
| 7 | [On-Track Attendance (DSSF chronic absence)](07-on-track-attendance-dssf.sql) | ⚪ Not run yet | Scheduled days, full-day absences for any reason and percent absent per student per school, with a 10% flag and school rate. |
| 8 | [Truancy ladder](08-truancy-ladder.sql) | ⚪ Not run yet | Students over the truancy line in unexcused full-day absences, with the date they reached each step and the highest step. |
| 9 | [DOE-reportable discipline check](09-doe-reportable-discipline-check.sql) | 🔴 Broken | On state-coded behavior events: offenders with no resolution, suspensions missing start, end or length, and offenders missing gender, race or grade. |
| 10 | [Behavior responses not synced](10-behavior-responses-not-synced.sql) | ⚪ Not run yet | Offender roles with no resolution more than @days days after the event; these show up as gaps in State Edition. |
| 11 | [Teen dating violence / sexual assault incidents](11-teen-dating-violence-incidents.sql) | ⚪ Not run yet | This year's events whose type maps to teen dating violence or sexual assault, with role counts only, for the Reg 601 TDV report. |
| 12 | [SPED Indicator 13 / IEP compliance](12-sped-indicator-13-iep-compliance.sql) | ⚪ Not run yet | Currently enrolled students whose latest locked IEP is past its end date, or who are transition age with no post-high-school goals. |
| 13 | [Gifted date check](13-gifted-date-check.sql) | ⚪ Not run yet | Gifted records whose identified date is after the start date, and students with more than one open Gifted record. |
| 14 | [Immunization compliance](14-immunization-compliance.sql) | ⚪ Not run yet | Active students IC marks non-compliant, with vaccines short, exemptions on file and next dose due. |

[← Back to the library](../../README.md)
