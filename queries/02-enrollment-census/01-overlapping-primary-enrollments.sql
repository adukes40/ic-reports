/* ======================================================================================
   #1  Overlapping primary enrollments
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Students with two primary enrollments whose dates overlap, shown side by side.
   Output:    One row per overlapping pair: both schools, grades, enrollment IDs and dates
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID (matches either side)  (change them in the PARAMETERS
              block below)
   Check:     Only looks within the current year's calendars.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools (matches either enrollment)
-- ===========================================================================

WITH enr AS (
    SELECT e.enrollmentID, e.personID, e.grade, e.startDate, e.endDate,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE e.serviceType = 'P'
      AND c.endYear = @endYear
      AND c.exclude = 0 AND s.exclude = 0
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       a.enrollmentID AS [Enrollment ID A], CONVERT(date, a.startDate) AS [Start Date A], CONVERT(date, a.endDate) AS [End Date A],
       b.schoolName   AS [School B],     b.grade AS [Grade B],
       b.enrollmentID AS [Enrollment ID B], CONVERT(date, b.startDate) AS [Start Date B], CONVERT(date, b.endDate) AS [End Date B],
       'Two primary enrollments overlap' AS [Issue]
FROM enr a
JOIN enr b ON b.personID = a.personID
          AND b.enrollmentID > a.enrollmentID
          AND a.startDate <= ISNULL(b.endDate, '9999-12-31')
          AND b.startDate <= ISNULL(a.endDate, '9999-12-31')
JOIN Person p ON p.personID = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE (@schoolID IS NULL OR a.schoolID = @schoolID OR b.schoolID = @schoolID)
ORDER BY a.schoolName, i.lastName, i.firstName;
