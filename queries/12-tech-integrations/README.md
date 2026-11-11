# Tech, integrations & security

User accounts, rights audits, student email and roster-sync readiness.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 129 | [Active accounts for staff who left](01-active-accounts-staff-who-left.sql) | Not run yet | Enabled staff user accounts whose person has no current school assignment and no active enrollment, so their access can be ended. |
| 130 | [Stale accounts](02-stale-accounts.sql) | Not run yet | Enabled staff user accounts with no login in the last @days days, or that have never logged in. |
| 131 | [Tool and calendar rights audit](03-tool-calendar-rights-audit.sql) | Not run yet | Enabled accounts holding tool rights or calendar rights granted directly to the user instead of through a user group, and accounts whose calendar rights reach all schools or a school where the person has no current assignment. |
| 132 | [Product security / admin rights](04-product-security-admin-rights.sql) | Not run yet | Every enabled account with All Tools, a product security role, or rights to the tools that manage user accounts, groups and rights, and whether each came directly or through a group. |

[← Back to the library](../../README.md)
