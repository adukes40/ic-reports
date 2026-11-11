# Special programs

SPED, 504, EL, homeless, foster care and meal eligibility records that are missing, mismatched or due.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 79 | [IEP students with no case manager](01-iep-students-no-case-manager.sql) | Not run yet | Active students with a locked, current IEP and no current case manager on their team. Shows whether the plan itself still names one. |
| 80 | [SPED status vs. active plan mismatch](02-sped-status-vs-active-plan-mismatch.sql) | Not run yet | Active students whose special ed status record is active but who have no locked, current IEP, and students with a locked, current IEP but no active special ed status record. |
| 81 | [IEP / evaluation due dates](03-iep-evaluation-due-dates.sql) | Not run yet | Active students whose latest locked IEP ends, or whose re-evaluation falls due, within @days days or has already passed, with their case manager. |
| 82 | [Discipline days for students with IEPs](04-discipline-days-students-with-ieps.sql) | Not run yet | Per active student with a locked, current IEP: total days removed this year (out-of-school suspension and expulsion) from behavior resolutions, flagged at 8 or more and 10 or more days. |
| 83 | [Disability record with no exit](05-disability-record-no-exit.sql) | Not run yet | Students enrolled this year who have a primary disability on a locked IEP and whose special ed has ended (status record ended, or last IEP expired) but who have no special ed exit date. |
| 84 | [504 roster for teachers](06-504-roster-for-teachers.sql) | Not run yet | For each section meeting on @asOf, the rostered students who have an active 504, with teacher and period, so teachers know whose accommodations apply. Shows only that a 504 exists and its dates. |
| 85 | [EL status gaps](07-el-status-gaps.sql) | Not run yet | Active students whose EL record has no program status, current ELs with no first-US-school date, exited ELs with no exit date, and exit dates on records that are not marked exited. |
| 86 | [EL monitoring years](08-el-monitoring-years.sql) | Not run yet | Active students who exited EL within the last @years years, with the exit date and which year of monitoring they are in. |
| 87 | [Homeless (McKinney-Vento) gaps](09-homeless-mckinney-vento-gaps.sql) | Not run yet | Active homeless records for active students that are missing the primary nighttime residence or the unaccompanied youth value. |

[← Back to the library](../../README.md)
