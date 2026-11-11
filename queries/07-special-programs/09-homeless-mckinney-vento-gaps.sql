/* ======================================================================================
   #87  Homeless (McKinney-Vento) gaps
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Active homeless records for active students that are missing the primary
              nighttime residence or the unaccompanied youth value.
   Output:    One row per problem: school, grade, homeless record start and end, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Homeless, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     A record is active when it has started and has no end date or ends on or
              after @asOf. Only blank values are flagged, not wrong codes.
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
       CONVERT(date, h.startDate) AS [Homeless Start], CONVERT(date, h.endDate) AS [Homeless End],
       x.issue AS [Issue]
FROM act a
JOIN Homeless h   ON h.personID   = a.personID
                 AND h.startDate <= @asOf AND (h.endDate IS NULL OR h.endDate >= @asOf)
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(h.primaryNightTimeResidence)), '') IS NULL THEN 'No primary nighttime residence' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(h.unaccompaniedYouth)), '') IS NULL THEN 'No unaccompanied youth value' END)
) x(issue)
WHERE a.rn = 1
  AND x.issue IS NOT NULL
ORDER BY a.schoolName, x.issue, a.grade, i.lastName, i.firstName;
