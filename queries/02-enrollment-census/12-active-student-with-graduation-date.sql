/* ======================================================================================
   #26  Active student with a graduation date
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Enrollment & census
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Students active today who already have a diploma date or diploma type on their
              graduation record.
   Output:    One row per active enrollment: grade, diploma date and type
   Tables:    Calendar, School, Enrollment, Graduation, Person, Identity
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
       'Active student already has diploma data' AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (SELECT TOP 1 g.diplomaDate, g.diplomaType     -- diploma data is kept on Graduation
             FROM Graduation g
             WHERE g.personID = e.personID
               AND (g.diplomaDate IS NOT NULL OR NULLIF(LTRIM(RTRIM(g.diplomaType)), '') IS NOT NULL)
             ORDER BY g.diplomaDate DESC) d
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND e.serviceType = 'P'
  AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
ORDER BY s.name, e.grade, i.lastName;
