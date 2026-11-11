# Health & compliance

Boosters and screenings due, health forms, condition rosters and emergency contacts.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 113 | [Grade-entry boosters due](02-grade-entry-boosters-due.sql) | Not run yet | Students headed into a grade that requires a booster who have no dose of that vaccine on file. |
| 114 | [School health exam forms missing](03-school-health-exam-forms-missing.sql) | Not run yet | Active students in the chosen grades with no health exam (physical) on file dated on or after @examSince. |
| 115 | [Health conditions roster for staff](04-health-conditions-roster-for-staff.sql) | Not run yet | For each section meeting on @asOf, the rostered students who have a current health condition flagged for staff. Shows the condition name and whether an action plan is on file, nothing else. |
| 116 | [Screenings due](05-screenings-due.sql) | Not run yet | Active students in the chosen grades with no screening of the chosen type recorded this school year. |
| 117 | [Emergency contact gaps](06-emergency-contact-gaps.sql) | Not run yet | Active students with fewer than two current emergency contacts that have a phone number. |

[← Back to the library](../../README.md)
