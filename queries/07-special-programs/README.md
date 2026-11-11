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

[← Back to the library](../../README.md)
