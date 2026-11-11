# Special programs

SPED, 504, EL, homeless, foster care and meal eligibility records that are missing, mismatched or due.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 79 | [IEP students with no case manager](01-iep-students-no-case-manager.sql) | Not run yet | Active students with a locked, current IEP and no current case manager on their team. Shows whether the plan itself still names one. |
| 80 | [SPED status vs. active plan mismatch](02-sped-status-vs-active-plan-mismatch.sql) | Not run yet | Active students whose special ed status record is active but who have no locked, current IEP, and students with a locked, current IEP but no active special ed status record. |
| 81 | [IEP / evaluation due dates](03-iep-evaluation-due-dates.sql) | Not run yet | Active students whose latest locked IEP ends, or whose re-evaluation falls due, within @days days or has already passed, with their case manager. |

[← Back to the library](../../README.md)
