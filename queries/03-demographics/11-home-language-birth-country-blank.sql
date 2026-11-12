/* ======================================================================================
   #40  Home language / birth country blank
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      Validation · Priority 2 · Run BOY
   Purpose:   Active students with no home primary language or no birth country on their
              current identity. Both are needed for EL screening and federal reporting.
   Output:    One row per student per blank field: home language code, birth country code,
              issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Reads Identity.homePrimaryLanguage and Identity.birthCountry. If birth
              country is only entered for students born outside the US, nearly every
              student shows that issue; filter on the Issue column.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       i.homePrimaryLanguage AS [Home Language], i.birthCountry AS [Birth Country],
       x.issue AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(i.homePrimaryLanguage)), '') IS NULL THEN 'No home primary language' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(i.birthCountry)), '')        IS NULL THEN 'No birth country' END)
) x(issue)
WHERE a.rn = 1
  AND x.issue IS NOT NULL
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName, x.issue;
