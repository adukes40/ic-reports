/* ======================================================================================
   #52  Requests vs. seats
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      KPI · Priority 2 · Run Spring
   Purpose:   For each course in the next-year calendars: how many students requested it,
              how many sections are planned and how many seats those sections hold.
   Output:    One row per course: requests, alternate requests, sections planned, total
              seats, seats minus requests
   Tables:    SchoolYear, Course, Calendar, School, Request, Trial, Section
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Next year is @endYear + 1. Sections are counted in the next-year calendar's
              active trial; a section with no max students adds 0 seats. Alternates
              (Request.type = 'A') are shown separately and left out of Seats Minus
              Requests; confirm 'A' is your alternate code. Courses with no requests and
              no sections are left out.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);   -- current year; the report looks at the year after
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       co.number AS [Course Number], co.name AS [Course Name],
       rq.requests AS [Requests], rq.alternates AS [Alternate Requests],
       sc.sections AS [Sections Planned], sc.seats AS [Total Seats],
       sc.seats - rq.requests AS [Seats Minus Requests]
FROM Course co
JOIN Calendar c ON c.calendarID = co.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
CROSS APPLY (SELECT COUNT(CASE WHEN q.type IS NULL OR q.type <> 'A' THEN 1 END) AS requests,
                    COUNT(CASE WHEN q.type = 'A' THEN 1 END) AS alternates
             FROM Request q
             WHERE q.courseID = co.courseID) rq
CROSS APPLY (SELECT COUNT(*) AS sections,
                    ISNULL(SUM(CAST(se.maxStudents AS int)), 0) AS seats
             FROM Trial t
             JOIN Section se ON se.trialID = t.trialID
             WHERE t.calendarID = co.calendarID AND t.active = 1
               AND se.courseID = co.courseID) sc
WHERE c.endYear = @endYear + 1
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND co.active = 1
  AND (rq.requests > 0 OR rq.alternates > 0 OR sc.sections > 0)
ORDER BY s.name, co.number;
