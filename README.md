# IC Reports

Ready-to-run SQL for Infinite Campus: validation checks, lists, KPIs and vendor pulls for Delaware districts.
Every query is one `.sql` file you can copy and paste straight into IC's data extract tool.

**Browse, search and copy queries on the site: https://adukes40.github.io/ic-reports/**

## How to use a query

1. Pick a category below and open a query.
2. Read the header at the top of the file: what it finds, what it outputs, and anything to check first.
3. Click **Copy SQL** on the site (or the copy icon above the file here) and paste it into IC's data extract tool.
4. Optional: change a value in the `PARAMETERS` block, such as `@schoolID` to run one school.

The header is a SQL comment, so you can paste the whole file as-is.

## Categories

| Category | What's in it | Queries | Confirmed good |
|---|---|---|---|
| [Delaware DOE](queries/01-delaware-ddoe/) | State reporting checks: unit count, DSSF, discipline, SPED, immunizations. | 14 | 1 |
| [Enrollment & census](queries/02-enrollment-census/) | Enrollment records that are overlapping, missing, mis-dated or mis-coded. | 15 | 0 |
| [Demographics](queries/03-demographics/) | Student and guardian identity, race/ethnicity, names, contacts and addresses. | 6 | 3 |
| [Vendors](queries/04-vendors/) | Pulls we send to outside vendors, one folder per vendor. | 0 | 0 |

## Status

| Status | Meaning |
|---|---|
| 🟢 Confirmed good | Run against real data and checked |
| 🟡 Needs review | Runs, but the results need a closer look |
| ⚪ Not run yet | Written and checked for syntax, not yet run against real data |
| 🔴 Broken | Known problem; don't use until fixed |

## Request a query

Need something that isn't here? **[Request a query](https://forms.google.com/)**, describe what you want to see, and it will be added to the list.

## Finding a query

The site's search box looks inside every query, so you can search for a table name (`RelatedPair`), a column, or a word like "guardian". On GitHub, the search box at the top of the repository does the same.
