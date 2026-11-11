/* ======================================================================================
   #33  Impossible dates
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Active students with no birthdate, a birthdate in the future or more than
              @maxAge years ago, or a first-US-school date before the birthdate.
   Output:    One row per student per problem: birthdate, first US school date, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @maxAge  (change them in the PARAMETERS block below)
   Check:     Dates come from the current identity. First US school date is
              Identity.dateEnteredUSSchool, which is blank for most students; blanks are
              not flagged.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @maxAge   int  = 25;     -- oldest believable student age in years
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
       CONVERT(date, i.birthdate) AS [Birthdate], CONVERT(date, i.dateEnteredUSSchool) AS [First US School Date],
       x.issue AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN i.birthdate IS NULL THEN 'No birthdate' END),
    (CASE WHEN i.birthdate > @asOf THEN 'Birthdate is in the future' END),
    (CASE WHEN i.birthdate < DATEADD(year, -@maxAge, @asOf)
          THEN CONCAT('Birthdate is more than ', @maxAge, ' years ago') END),
    (CASE WHEN i.dateEnteredUSSchool < i.birthdate THEN 'First US school date is before the birthdate' END)
) x(issue)
WHERE a.rn = 1
  AND x.issue IS NOT NULL
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
