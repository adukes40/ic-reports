/* ======================================================================================
   #86  EL monitoring years
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      List · Priority 2 · Run Annual
   Purpose:   Active students who exited EL within the last @years years, with the exit
              date and which year of monitoring they are in.
   Output:    One row per student: school, grade, EL exit date, monitoring year,
              monitoring end date
   Tables:    SchoolYear, Enrollment, Calendar, School, Lep, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @years  (change them in the PARAMETERS block
              below)
   Check:     @years is the length of your monitoring window (4 by default; set it to 2
              if you monitor two years). The monitoring year is counted in full years
              from the exit date, not from the monitoring dates stored on the EL record.
              Any EL record with an exit date counts, whatever its status.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @years    int  = 4;      -- monitoring window in years after the exit date
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
),
exited AS (   -- EL exits inside the monitoring window, latest first per student
    SELECT l.personID, CONVERT(date, l.exitDate) AS exitDate,
           ROW_NUMBER() OVER (PARTITION BY l.personID ORDER BY l.exitDate DESC, l.lepID DESC) AS rn
    FROM Lep l
    WHERE l.exitDate <= @asOf
      AND l.exitDate > DATEADD(year, -@years, @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       x.exitDate AS [EL Exit Date],
       DATEDIFF(year, x.exitDate, @asOf)
         - CASE WHEN DATEADD(year, DATEDIFF(year, x.exitDate, @asOf), x.exitDate) > @asOf THEN 1 ELSE 0 END
         + 1 AS [Monitoring Year],
       DATEADD(year, @years, x.exitDate) AS [Monitoring Ends]
FROM act a
JOIN exited x     ON x.personID   = a.personID AND x.rn = 1
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
ORDER BY a.schoolName, [Monitoring Year], a.grade, i.lastName, i.firstName;
