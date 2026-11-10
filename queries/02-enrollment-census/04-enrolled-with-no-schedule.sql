/* ======================================================================================
   #4  Enrolled with no schedule
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Active primary enrollments with no roster row in the active trial on @asOf.
   Output:    One row per unscheduled student: school, grade, start date, days since start
   Tables:    Calendar, School, Enrollment, Trial, Section, Roster, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Grades you don't schedule (some Pre-K) will show up; filter them if needed.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       e.grade AS [Grade],
       CONVERT(date, e.startDate) AS [Start Date],
       DATEDIFF(day, e.startDate, @asOf) AS [Days Since Start],
       'Active enrollment with no class on ' + CONVERT(varchar(10), @asOf, 23) AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND e.serviceType = 'P'
  AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
  AND NOT EXISTS (
      SELECT 1
      FROM Trial t
      JOIN Section se ON se.trialID = t.trialID
      JOIN Roster r   ON r.sectionID = se.sectionID AND r.trialID = t.trialID
      WHERE t.calendarID = e.calendarID AND t.active = 1
        AND r.personID = e.personID
        AND (r.startDate IS NULL OR r.startDate <= @asOf)
        AND (r.endDate IS NULL OR r.endDate >= @asOf))
ORDER BY s.name, e.grade, i.lastName;
