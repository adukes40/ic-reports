/* ======================================================================================
   #25  State-excluded enrollments
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      List · Priority 2 · Run BOY, Sept
   Purpose:   Current-year enrollments with state exclude set, so each can be confirmed.
   Output:    One row per excluded enrollment: grade, service type, dates, comments, last
              modified
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
       e.startComments AS [Start Comments], e.endComments AS [End Comments],
       CONVERT(date, e.modifiedDate) AS [Last Modified]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE c.endYear = @endYear
  AND e.stateExclude = 1
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY s.name, e.serviceType, i.lastName;
