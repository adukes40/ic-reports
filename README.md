<div align="center">

# 📊 IC Reports

**Ready-to-run SQL for Infinite Campus**<br>
Validation checks, lists, KPIs and vendor pulls for Delaware school districts.

[![Browse the library](https://img.shields.io/badge/Browse%20the%20library-000098?style=for-the-badge&logo=googlechrome&logoColor=white)](https://adukes40.github.io/ic-reports/)
[![Request a query](https://img.shields.io/badge/Request%20a%20query-fcbe14?style=for-the-badge&logoColor=000098)](https://forms.google.com/)

![Infinite Campus](https://img.shields.io/badge/Infinite%20Campus-SQL%20Server-000098?style=flat-square)
![Delaware](https://img.shields.io/badge/Delaware-DDOE%20reporting-000098?style=flat-square)
![Copy and paste](https://img.shields.io/badge/Data%20Extract-copy%20%26%20paste-fcbe14?style=flat-square)

</div>

---

## 🚀 Quick start

| Step | What to do |
|:---:|---|
| 1️⃣ | Open the **[query library](https://adukes40.github.io/ic-reports/)** and pick a category, or search for what you need. |
| 2️⃣ | Read what the query finds, what it returns, and anything to check before running it. |
| 3️⃣ | Click **Copy SQL** and paste it into Infinite Campus's data extract tool. |
| 4️⃣ | *Optional:* change a value in the `PARAMETERS` block, such as `@schoolID`, to run a single school. |

> [!TIP]
> Each file starts with a header written as a SQL comment, so you can paste the whole file as-is.

## 🗂️ Categories

| | Category | What's in it | Queries |
|:---:|---|---|:---:|
| 🏛️ | **[Delaware DOE](queries/01-delaware-ddoe/)** | State reporting checks: unit count, DSSF, discipline, SPED, immunizations | 14 |
| 🎒 | **[Enrollment & census](queries/02-enrollment-census/)** | Enrollment records that overlap, are missing, or have wrong dates or codes | 15 |
| 👥 | **[Demographics](queries/03-demographics/)** | Student and guardian identity, race and ethnicity, names, contacts and addresses | 6 |
| 🤝 | **[Vendors](queries/04-vendors/)** | Files sent to outside vendors, grouped by vendor | 0 |

## 🔍 Finding a query

The library's search box looks inside every query, so you can search for a table name like `RelatedPair`, a column, or a plain word like *guardian*. On GitHub, the search box at the top of the repository does the same.

## 💬 Request a query

Need something that isn't here? **[Request a query](https://forms.google.com/)** and describe what you want to see.
