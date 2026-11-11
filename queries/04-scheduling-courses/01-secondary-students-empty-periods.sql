/* ======================================================================================
   #42  MS/HS students with empty periods
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      Validation · Priority 1 · Run BOY, semester
   Purpose:   Active students in grades 6-12 with a gap in their day: a period in their
              calendar's period schedule where they have no class on @asOf.
   Output:    One row per student-period: grade, period schedule, period
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, PeriodSchedule,
              Period, Trial, Roster, SectionPlacement, Term
   Params:    @endYear, @schoolID, @asOf, @graceDays, @minGrade, @maxGrade  (change them in
              the PARAMETERS block below)
   Check:     Set @asOf to a day inside a term. Grades @minGrade to @maxGrade (6-12 unless
              you change them) are picked by reading Enrollment.grade as a number. Only
              instructional periods that hold at least one section are checked, so an
              unused period is not reported. Students with an approved release period or a
              lunch period with no section will show. Schools with several period
              schedules (A/B days) get a row per schedule.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @asOf      date = CONVERT(date, GETDATE());
DECLARE @graceDays int  = 2;      -- skip students who enrolled fewer than this many days before @asOf
DECLARE @minGrade  int  = 6;      -- lowest grade number to check
DECLARE @maxGrade  int  = 12;     -- highest grade number to check
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student in grades @minGrade to @maxGrade on @asOf
    SELECT e.personID, e.calendarID, e.structureID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= DATEADD(day, -@graceDays, @asOf) AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND TRY_CAST(e.grade AS int) BETWEEN @minGrade AND @maxGrade
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       ps.name AS [Period Schedule], pd.name AS [Period],
       'No class in this period on ' + CONVERT(varchar(10), @asOf, 23) AS [Issue]
FROM act a
JOIN PeriodSchedule ps ON ps.structureID = a.structureID
JOIN Period pd         ON pd.periodScheduleID = ps.periodScheduleID AND pd.nonInstructional = 0
JOIN Person p          ON p.personID   = a.personID
JOIN [Identity] i      ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND EXISTS (
      SELECT 1
      FROM Trial t
      JOIN SectionPlacement sp ON sp.trialID = t.trialID
      WHERE t.calendarID = a.calendarID AND t.active = 1
        AND sp.periodID = pd.periodID)
  AND NOT EXISTS (
      SELECT 1
      FROM Trial t
      JOIN Roster r            ON r.trialID = t.trialID
      JOIN SectionPlacement sp ON sp.sectionID = r.sectionID
      JOIN Term tm             ON tm.termID = sp.termID
      WHERE t.calendarID = a.calendarID AND t.active = 1
        AND r.personID = a.personID
        AND sp.periodID = pd.periodID
        AND (r.startDate IS NULL OR r.startDate <= @asOf)
        AND (r.endDate IS NULL OR r.endDate >= @asOf)
        AND (tm.startDate IS NULL OR tm.startDate <= @asOf)
        AND (tm.endDate IS NULL OR tm.endDate >= @asOf))
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName, ps.seq, pd.seq;
