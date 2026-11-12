# Tech, integrations & security

User accounts, rights audits, student email and roster-sync readiness.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 129 | [Active accounts for staff who left](01-active-accounts-staff-who-left.sql) | Not run yet | Enabled staff user accounts whose person has no current school assignment and no active enrollment, so their access can be ended. |
| 130 | [Stale accounts](02-stale-accounts.sql) | Not run yet | Enabled staff user accounts with no login in the last @days days, or that have never logged in. |
| 131 | [Tool and calendar rights audit](03-tool-calendar-rights-audit.sql) | Not run yet | Enabled accounts holding tool rights or calendar rights granted directly to the user instead of through a user group, and accounts whose calendar rights reach all schools or a school where the person has no current assignment. |
| 132 | [Product security / admin rights](04-product-security-admin-rights.sql) | Not run yet | Every enabled account with All Tools, a product security role, or rights to the tools that manage user accounts, groups and rights, and whether each came directly or through a group. |
| 133 | [Students missing district email](05-students-missing-district-email.sql) | Not run yet | Active students with no email on their contact record, an email outside the district's student domain, or an email that another person also has. |
| 134 | [Roster sync readiness](06-roster-sync-readiness.sql) | Not run yet | What a OneRoster, Google or ClassLink roster sync will trip over: sections with students but no primary teacher or no teacher email, and active students with no email, no usable grade, or no class. |
| 135 | [IC vs. Google / ClassLink counts](07-ic-vs-google-classlink-counts.sql) | Not run yet | The Infinite Campus side of a count comparison with Google or ClassLink: active students by school and grade, plus teachers with sections and active sections by school, and a district total. |
| 136 | [Ad hoc filters broken by deactivated fields](08-adhoc-filters-deactivated-fields.sql) | Not run yet | Saved ad hoc filters that Infinite Campus has marked as using a deactivated field, with who owns them and when they last ran. |
| 137 | [Sensitive-change audit](09-sensitive-change-audit.sql) | Not run yet | Who changed attendance, transcript grades and student identity records between @startDate and @endDate, and when. |
| 138 | [Data export inventory](10-data-export-inventory.sql) | Not run yet | Every Data Extract Utility job with where it sends its file, how often it runs, when it last ran and who owns it, for privacy reviews. |

[← Back to the library](../../README.md)
