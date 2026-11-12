<div align="center">

# IC Reports

**Ready-to-run SQL for Infinite Campus**<br>
Validation checks, lists, KPIs and vendor pulls for Delaware school districts.

[![Browse the library](https://img.shields.io/badge/Browse%20the%20library-000098?style=for-the-badge&logo=googlechrome&logoColor=white)](https://adukes40.github.io/ic-reports/)
[![Request a query](https://img.shields.io/badge/Request%20a%20query-fcbe14?style=for-the-badge&logoColor=000098)](https://github.com/adukes40/ic-reports/issues/new?template=query-request.yml)

![Infinite Campus](https://img.shields.io/badge/Infinite%20Campus-SQL%20Server-000098?style=flat-square)
![Delaware](https://img.shields.io/badge/Delaware-DDOE%20reporting-000098?style=flat-square)
![Copy and paste](https://img.shields.io/badge/Data%20Extract-copy%20%26%20paste-fcbe14?style=flat-square)

</div>

---

## Quick start

| Step | What to do |
|:---:|---|
| 1 | Open the **[query library](https://adukes40.github.io/ic-reports/)** and pick a category, or search for what you need. |
| 2 | Read what the query finds, what it returns, and anything to check before running it. |
| 3 | Click **Copy SQL** and paste it into Infinite Campus's data extract tool. |
| 4 | *Optional:* change a value in the `PARAMETERS` block, such as `@schoolID`, to run a single school. |

> [!TIP]
> Each file starts with a header written as a SQL comment, so you can paste the whole file as-is.

## Categories

| Category | What's in it | Queries |
|---|---|:---:|
| **[Delaware DOE](queries/01-delaware-ddoe/)** | State reporting checks: unit count, DSSF, discipline, SPED, immunizations | 14 |
| **[Enrollment & census](queries/02-enrollment-census/)** | Enrollment records that overlap, are missing, or have wrong dates or codes | 15 |
| **[Demographics](queries/03-demographics/)** | Student and guardian identity, race and ethnicity, names, contacts and addresses | 12 |
| **[Scheduling & courses](queries/04-scheduling-courses/)** | Schedule gaps, double bookings, section setup, class sizes and course requests | 11 |
| **[Attendance](queries/05-attendance/)** | Attendance that was not taken, chronic absence, daily rates and absence patterns | 12 |
| **[Grades, transcripts & graduation](queries/06-grades-transcripts/)** | Missing posted grades, failures, credit checks, transcripts and graduation tracking | 14 |
| **[Special programs](queries/07-special-programs/)** | SPED, 504, EL, homeless, foster care and meal eligibility records that are missing, mismatched or due | 13 |
| **[Behavior & discipline](queries/08-behavior-discipline/)** | Behavior events, referrals and discipline, by student and by school | 9 |
| **[Staff](queries/09-staff/)** | Staff credentials, demographics, assignments and rosters | 4 |
| **[Health & compliance](queries/10-health/)** | Boosters and screenings due, health forms, condition rosters and emergency contacts | 5 |
| **[Operational lists](queries/11-operational-lists/)** | The lists offices, counselors and principals ask for every week | 11 |
| **[Tech, integrations & security](queries/12-tech-integrations/)** | User accounts, rights audits, student email and roster-sync readiness | 10 |
| **[CampusView KPIs](queries/13-campusview-kpis/)** | Attendance and referral KPIs, each as one standalone query | 10 |
| **[Vendors](queries/14-vendors/)** | Files sent to outside vendors, grouped by vendor | 0 |

## Finding a query

The library's search box looks inside every query, so you can search for a table name like `RelatedPair`, a column, or a plain word like *guardian*. On GitHub, the search box at the top of the repository does the same.

## Delaware rules

The state regulations and guidance the queries follow, with links to each rule, are listed on the **[Delaware sources](DELAWARE-SOURCES.md)** page.

## Request a query

Need something that isn't here? **[Request a query](https://github.com/adukes40/ic-reports/issues/new?template=query-request.yml)** on GitHub and describe what you want to see. You'll need a free GitHub account to submit it.
