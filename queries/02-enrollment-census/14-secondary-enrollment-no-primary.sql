/* ======================================================================================
   #28  Secondary enrollment with no primary
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Enrollment & census
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Active secondary or partial enrollments for students with no active primary
              enrollment on the same date.
   Output:    One row per orphan enrollment: grade, service type, dates
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Service types other than P are treated as secondary or partial.
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
       e.grade AS [Grade], e.serviceType AS [Service Type],
       CONVERT(date, e.startDate) AS [Start Date], CONVERT(date, e.endDate) AS [End Date],
       CASE e.serviceType WHEN 'S' THEN 'Secondary' WHEN 'N' THEN 'Partial' ELSE e.serviceType END
         + ' enrollment with no active primary' AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND e.serviceType <> 'P'
  AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
  AND NOT EXISTS (SELECT 1 FROM Enrollment ep
                  WHERE ep.personID = e.personID AND ep.serviceType = 'P'
                    AND ep.startDate <= @asOf AND (ep.endDate IS NULL OR ep.endDate >= @asOf))
ORDER BY s.name, i.lastName;
