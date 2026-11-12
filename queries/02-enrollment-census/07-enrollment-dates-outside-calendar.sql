/* ======================================================================================
   #21  Enrollment dates outside calendar
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 2 · Run BOY, EOY
   Purpose:   Enrollments that start before the calendar starts or end after it ends.
   Output:    One row per problem: enrollment and calendar dates, issue
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     None.
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
       CONVERT(date, e.startDate) AS [Start Date], CONVERT(date, e.endDate) AS [End Date],
       CONVERT(date, c.startDate) AS [Calendar Start], CONVERT(date, c.endDate) AS [Calendar End],
       x.issue AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN e.startDate < c.startDate THEN 'Starts before the calendar starts' END),
    (CASE WHEN e.endDate   > c.endDate   THEN 'Ends after the calendar ends' END)
) x(issue)
WHERE x.issue IS NOT NULL
  AND c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY s.name, x.issue, i.lastName;
