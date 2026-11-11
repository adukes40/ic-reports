# Demographics

Student and guardian identity, race/ethnicity, names, contacts and addresses.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 30 | [Missing or invalid sex / gender](01-missing-invalid-gender.sql) | Needs review | Active students with a blank gender, or a code not in the Identity gender list. |
| 31 | [Race / ethnicity conflicts](02-race-ethnicity-conflicts.sql) | Confirmed good | Blank Hispanic answer, Hispanic = N with no race, a race not in the race list, or a blank federal rollup. |
| 32 | [Bad name characters](03-bad-name-characters.sql) | Confirmed good | Student and guardian first/last names with odd characters, one character long, a leading apostrophe, or a suffix in the name. |
| 34 | [Active students with no guardian](05-active-students-no-guardian.sql) | Confirmed good | Active students with no current relationship flagged guardian. |
| 35 | [Guardians with no phone or email](06-guardians-no-phone-email.sql) | Not run yet | Current guardians of active students with no phone (home, cell, work) or no email (primary, secondary) on their contact record. |
| 37 | [Missing or incomplete address](08-missing-incomplete-address.sql) | Not run yet | Primary household with no current address, no current address marked physical, or an address missing street, city, state or zip. |

[← Back to the library](../../README.md)
