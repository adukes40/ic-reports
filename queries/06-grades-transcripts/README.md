# Grades, transcripts & graduation

Missing posted grades, failures, credit checks, transcripts and graduation tracking.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 65 | [Grades not posted](01-grades-not-posted.sql) | Not run yet | Sections where at least one rostered student has no posted score for a grading task the course is set to grade in the term. |
| 66 | [D/F list](02-d-f-list.sql) | Not run yet | Active students with a D or F in the term, by course, section and teacher. Uses the posted grade, or the in-progress grade when nothing is posted yet. |
| 67 | [Course failures by section](03-course-failures-by-section.sql) | Not run yet | D and F counts and the D/F rate for every section's posted grades in the term, with the teacher, to spot outliers. |
| 68 | [Middle school course warning](04-middle-school-course-warning.sql) | Not run yet | Active grade 6-8 students failing an English or math course in the term, or with a term GPA under the minimum (2.0). |
| 69 | [High school course warning](05-high-school-course-warning.sql) | Not run yet | Active grade 9-12 students with a failing grade in any course in the term. |

[← Back to the library](../../README.md)
