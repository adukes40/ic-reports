/* ======================================================================================
   #15  Very short enrollments
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      List · Priority 3 · Run Ongoing
   Purpose:   Ended enrollments this year that lasted fewer than @minDays instructional
              days.
   Output:    One row per short enrollment: dates, start and end status, instructional days
   Tables:    Calendar, School, Day, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @minDays (5)  (change them in the PARAMETERS block below)
   Check:     None.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @minDays  int = 5;
-- ===========================================================================

WITH enr AS (
    SELECT e.enrollmentID, e.personID, e.calendarID, e.structureID, e.grade, e.serviceType,
           e.startDate, e.endDate, e.startStatus, e.endStatus,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.endDate IS NOT NULL
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       en.schoolID AS [School ID], en.schoolName AS [School], en.endYear AS [School Year], en.grade AS [Grade], en.serviceType AS [Service Type],
       CONVERT(date, en.startDate) AS [Start Date], en.startStatus AS [Start Status],
       CONVERT(date, en.endDate)   AS [End Date],   en.endStatus AS [End Status],
       ISNULL(d.instrDays, 0) AS [Instructional Days],
       'Enrollment lasted fewer than ' + CAST(@minDays AS varchar(5)) + ' instructional days' AS [Issue]
FROM enr en
OUTER APPLY (SELECT COUNT(*) AS instrDays
             FROM Day dy
             WHERE dy.calendarID = en.calendarID AND dy.structureID = en.structureID
               AND dy.instruction = 1
               AND dy.date >= en.startDate AND dy.date <= en.endDate) d
JOIN Person p ON p.personID = en.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE ISNULL(d.instrDays, 0) < @minDays
ORDER BY en.schoolName, [Instructional Days], i.lastName;
