/* ======================================================================================
   #13  Next-year placement missing
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run Spring, EOY
   Purpose:   Active students below grade 12 with no next-year placement, or a next grade
              the next calendar doesn't offer.
   Output:    One row per problem: grade, next school, next grade, issue
   Tables:    Calendar, School, Enrollment, GradeLevel, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @terminalGrade ('12')  (change them in the
              PARAMETERS block below)
   Check:     Counts either a next calendar on the enrollment or an existing next-year
              primary enrollment as placed.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int = NULL;   -- NULL = all schools
DECLARE @asOf          date = CONVERT(date, GETDATE());
DECLARE @terminalGrade varchar(5) = '12';
-- ===========================================================================

WITH act AS (
    SELECT e.enrollmentID, e.personID, e.grade, e.nextCalendar, e.nextGrade, e.nextStructureID,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P'
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND ISNULL(e.grade, '') <> @terminalGrade
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       ns.name AS [Next School], a.nextGrade AS [Next Grade],
       x.issue AS [Issue]
FROM act a
JOIN Person p ON p.personID = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN Calendar nc ON nc.calendarID = a.nextCalendar
LEFT JOIN School   ns ON ns.schoolID   = nc.schoolID
CROSS APPLY (VALUES
    (CASE WHEN (a.nextCalendar IS NULL OR a.nextCalendar = 0)
           AND NOT EXISTS (SELECT 1 FROM Enrollment e2
                           JOIN Calendar c2 ON c2.calendarID = e2.calendarID
                           WHERE e2.personID = a.personID AND c2.endYear = @endYear + 1
                             AND e2.serviceType = 'P')
          THEN 'No next-year placement' END),
    (CASE WHEN nc.calendarID IS NOT NULL
           AND NULLIF(LTRIM(RTRIM(a.nextGrade)), '') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM GradeLevel g
                           WHERE g.calendarID = nc.calendarID
                             AND (a.nextStructureID IS NULL OR g.structureID = a.nextStructureID)
                             AND g.name = a.nextGrade)
          THEN 'Next grade not offered in next-year calendar' END)
) x(issue)
WHERE x.issue IS NOT NULL
ORDER BY a.schoolName, a.grade, i.lastName;
