/* ======================================================================================
   #12  Active student with a graduation date
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Students active today who already have a diploma date or diploma type on any
              enrollment.
   Output:    One row per active enrollment: grade, diploma date and type, year it was
              recorded
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Adult-ed or post-grad programs may hold diploma data legitimately.
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
       CONVERT(date, d.diplomaDate) AS [Diploma Date], d.diplomaType AS [Diploma Type],
       d.endYear AS [Diploma On Enrollment Year],
       'Active student already has diploma data' AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (SELECT TOP 1 e2.diplomaDate, e2.diplomaType, c2.endYear
             FROM Enrollment e2
             JOIN Calendar c2 ON c2.calendarID = e2.calendarID
             WHERE e2.personID = e.personID
               AND (e2.diplomaDate IS NOT NULL OR NULLIF(LTRIM(RTRIM(e2.diplomaType)), '') IS NOT NULL)
             ORDER BY c2.endYear DESC) d
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND e.serviceType = 'P'
  AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
ORDER BY s.name, e.grade, i.lastName;
