# Scheduling & courses

Schedule gaps, double bookings, section setup, class sizes and course requests.

Open a query, click **Copy content** (top right of the file), and paste it into IC's data extract tool.

| # | Query | Status | What it finds |
|---|---|---|---|
| 42 | [MS/HS students with empty periods](01-secondary-students-empty-periods.sql) | Not run yet | Active students in grades 6-12 with a gap in their day: a period in their calendar's period schedule where they have no class on @asOf. |
| 43 | [Double-booked students](02-double-booked-students.sql) | Not run yet | Students rostered on @asOf into two or more sections that meet in the same period of the same term and period schedule (day). |
| 44 | [Sections with no primary teacher or room](03-sections-no-primary-teacher-or-room.sql) | Not run yet | Active-trial sections that have students on @asOf but no active primary teacher, or no room. These break rosters, state course reporting and ClassLink. |
| 45 | [Section roster dates outside enrollment](04-roster-dates-outside-enrollment.sql) | Not run yet | Roster rows in the active trial whose start date is before the student's enrollment start, or whose end date is after the enrollment end. |
| 46 | [Class size / section balance](05-class-size-section-balance.sql) | Not run yet | Students rostered in each section on @asOf against the section's max, to spot overloaded and near-empty sections of the same course. |
| 47 | [Empty sections](06-empty-sections.sql) | Not run yet | Active-trial sections with no students rostered on @asOf. They still sync to Google and ClassLink, so delete them or roster them. |
| 48 | [Courses missing grading tasks](07-courses-missing-grading-tasks.sql) | Not run yet | Active courses this year that have sections in the active trial but no grading task or standard assigned, which stops grades from posting. |
| 49 | [Course setup not pushed](08-course-setup-not-pushed.sql) | Not run yet | Active courses linked to a course master whose grading tasks or credit settings differ from the master's, meaning a course-master change was not pushed (or the course was edited by hand). |
| 50 | [Teacher load](09-teacher-load.sql) | Not run yet | For each primary teacher on @asOf: how many sections they teach, how many different courses (preps) and how many different students. |
| 51 | [Course requests not entered](10-course-requests-not-entered.sql) | Not run yet | Students with a next-year enrollment who have no course requests, or fewer than @minRequests, in their next-year calendar. |
| 52 | [Requests vs. seats](11-requests-vs-seats.sql) | Not run yet | For each course in the next-year calendars: how many students requested it, how many sections are planned and how many seats those sections hold. |
| 139 | [Homeroom class sizes](12-homeroom-class-sizes.sql) | Needs review | How many students sit in each homeroom on @asOf, by school and grade, with the homeroom teacher and room. |

[← Back to the library](../../README.md)
