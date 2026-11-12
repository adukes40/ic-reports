/* ======================================================================================
   #16  Prior-year enrollment not ended
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Enrollments in calendars before @endYear that still have no end date.
   Output:    One row per open enrollment: school, year, grade, service type, start date,
              calendar end date
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Includes every past year; filter c.endYear if the list is long.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       e.grade AS [Grade], e.serviceType AS [Service Type],
       c.name AS [Calendar Name],
       CONVERT(date, e.startDate) AS [Start Date],
       CONVERT(date, c.endDate)   AS [Calendar End Date],
       'Prior-year enrollment has no end date' AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE c.endYear < @endYear
  AND e.endDate IS NULL
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY c.endYear DESC, s.name, i.lastName, i.firstName;
