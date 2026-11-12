/* ======================================================================================
   #124  Birthday list
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 3 · Run On request
   Purpose:   Active students with a birthday in the chosen month, by school, with name,
              grade and day of the month. Used by offices and principals for announcements.
   Output:    One row per student: grade, birthday month and day (no birth year)
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @month  (change them in the PARAMETERS block
              below)
   Check:     @month defaults to the current month. Students with no birth date on file are
              left out.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @month    int  = MONTH(GETDATE());   -- 1 = January ... 12 = December
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
       MONTH(i.birthdate) AS [Birthday Month], DAY(i.birthdate) AS [Birthday Day]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND MONTH(i.birthdate) = @month
ORDER BY a.schoolName, DAY(i.birthdate), a.grade, i.lastName, i.firstName;
