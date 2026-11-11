/* ======================================================================================
   #51  Course requests not entered
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      List · Priority 2 · Run Spring
   Purpose:   Students with a next-year enrollment who have no course requests, or fewer
              than @minRequests, in their next-year calendar.
   Output:    One row per student and next-year calendar: next-year school and grade,
              requests entered, alternates entered
   Tables:    SchoolYear, Enrollment, Calendar, School, Request, Person, Identity
   Params:    @endYear, @schoolID, @minRequests, @minGrade  (change them in the
              PARAMETERS block below)
   Check:     Next year is @endYear + 1. School, School Year and Grade are the next-year
              ones. Alternates (Request.type = 'A') are counted separately and do not
              count toward @minRequests; confirm 'A' is your alternate code. Set
              @minRequests to the number of requests a full schedule needs and @minGrade
              to the lowest grade that enters requests.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear     int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);   -- current year; the report looks at the year after
DECLARE @schoolID    int = NULL;   -- NULL = all schools (next-year school)
DECLARE @minRequests int = 6;      -- list students with fewer requests than this
DECLARE @minGrade    int = 6;      -- lowest next-year grade that enters course requests
-- ===========================================================================

WITH nxt AS (   -- one row per student and next-year calendar with an open primary enrollment
    SELECT e.personID, e.calendarID, c.schoolID, s.name AS schoolName, c.endYear, MAX(e.grade) AS grade
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear + 1
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.endDate IS NULL
      AND TRY_CAST(e.grade AS int) >= @minGrade
    GROUP BY e.personID, e.calendarID, c.schoolID, s.name, c.endYear
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       n.schoolID AS [School ID], n.schoolName AS [School], n.endYear AS [School Year], n.grade AS [Grade],
       rq.requests AS [Requests], rq.alternates AS [Alternate Requests]
FROM nxt n
JOIN Person p     ON p.personID   = n.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (SELECT COUNT(CASE WHEN q.type IS NULL OR q.type <> 'A' THEN 1 END) AS requests,
                    COUNT(CASE WHEN q.type = 'A' THEN 1 END) AS alternates
             FROM Request q
             WHERE q.personID = n.personID AND q.calendarID = n.calendarID) rq
WHERE rq.requests < @minRequests
ORDER BY n.schoolName, n.grade, i.lastName, i.firstName;
