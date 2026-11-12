# Demographics

Student and guardian identity, race and ethnicity, names, contacts and addresses.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 30 | [Missing or invalid sex / gender](01-missing-invalid-gender.sql) | Needs review | Active students with a blank gender, or a code not in the Identity gender list. |
| 31 | [Race / ethnicity conflicts](02-race-ethnicity-conflicts.sql) | Confirmed good | Blank Hispanic answer, Hispanic = N with no race, a race not in the race list, or a blank federal rollup. |
| 32 | [Bad name characters](03-bad-name-characters.sql) | Confirmed good | Student and guardian first/last names with odd characters, one character long, a leading apostrophe, or a suffix in the name. |
| 33 | [Impossible dates](04-impossible-dates.sql) | Not run yet | Active students with no birthdate, a birthdate in the future or more than @maxAge years ago, or a first-US-school date before the birthdate. |
| 34 | [Active students with no guardian](05-active-students-no-guardian.sql) | Confirmed good | Active students with no current relationship flagged guardian. |
| 35 | [Guardians with no phone or email](06-guardians-no-phone-email.sql) | Confirmed good | Current guardians of active students with no phone (home, cell, work) or no email (primary, secondary) on their contact record. |
| 36 | [Duplicate contacts](07-duplicate-contacts.sql) | Not run yet | Pairs of guardian records with the same first and last name and a shared phone number, linked to the same student or to students in the same household. Usually one parent entered twice. |
| 37 | [Missing or incomplete address](08-missing-incomplete-address.sql) | Confirmed good | Primary household with no current address, no current address marked physical, or an address missing street, city, state or zip. |
| 38 | [Students in no household / two primaries](09-no-household-or-two-primaries.sql) | Not run yet | Active students with no current household membership, more than one household marked primary, or households but none marked primary. |
| 39 | [Address changes since a date](10-address-changes-since-date.sql) | Not run yet | Active students whose household got a new address on or after @sinceDate, with the old and new address, school and grade. |
| 40 | [Home language / birth country blank](11-home-language-birth-country-blank.sql) | Not run yet | Active students with no home primary language or no birth country on their current identity. Both are needed for EL screening and federal reporting. |
| 41 | [Legal vs preferred name differences](12-legal-vs-preferred-name.sql) | Not run yet | Active students whose preferred name (the Nickname field) differs from their first name, with both values, so account and roster syncs use the name the district intends. |

[← Back to the library](../../README.md)
