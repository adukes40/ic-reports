/* ======================================================================================
   #119  Early-warning ABC roster
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 1 · Run On request
   Purpose:   Active students flagged on attendance (10%+ of days absent), behavior (2+
              referrals) or course performance (1+ F; English or math F in grades 6-8)
              this year. Used by principals and MTSS teams.
   Output:    One row per flagged student: days enrolled, days absent, percent absent,
              referrals, failing grades, a Y for each flag, flag count
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity,
              v_AttDaySummary_Exact, BehaviorEvent, BehaviorRole, GradingScore,
              GradingTask, Term, Section, Course
   Params:    @endYear, @schoolID, @asOf, @task, @term, @absentPct (10),
              @minReferrals (2), @minFails (1), @countedRoles, @failMarks, @msGrades,
              @elaMathAreas  (change them in the PARAMETERS block below)
   Check:     @task must match your grading task name (GradingTask.name) and @term your
              term name (Term.name). Failing score is 'F'; add your own failing marks to
              @failMarks. Referral roles are 'Offender' and 'Participant'. Grades 6-8 are
              '06', '07', '08'; English and math are SCED subject areas 01 and 02.
              Absences are full days for any reason, at every school this year.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int  = NULL;   -- NULL = all schools
DECLARE @asOf         date = CONVERT(date, GETDATE());
DECLARE @task         varchar(50)  = '%Quarter%';   -- grading task name; % is a wildcard
DECLARE @term         varchar(10)  = NULL;          -- term name, e.g. 'Q1'; NULL = every term this year
DECLARE @absentPct    decimal(5,2) = 10.0;          -- attendance flag at this percent absent or more
DECLARE @minReferrals int          = 2;             -- behavior flag at this many referrals or more
DECLARE @minFails     int          = 1;             -- course flag at this many failing grades or more
DECLARE @countedRoles varchar(200) = 'Offender,Participant';   -- behavior role names counted as a referral, comma-separated
DECLARE @failMarks    varchar(200) = 'F';           -- failing marks, comma-separated
DECLARE @msGrades     varchar(200) = '06,07,08';    -- grade names where only English and math failures count, comma-separated
DECLARE @elaMathAreas varchar(200) = '01,02';       -- SCED subject area codes for English and math, comma-separated
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
att AS (   -- scheduled days and full-day absences per student this year
    SELECT a.personID, SUM(a.scheduledDays) AS scheduledDays, SUM(a.daysAbsent) AS daysAbsent
    FROM v_AttDaySummary_Exact a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
    GROUP BY a.personID
),
ref AS (   -- behavior incidents per student this year
    SELECT br.personID, COUNT(DISTINCT be.incidentID) AS referrals
    FROM BehaviorEvent be
    JOIN BehaviorRole br ON br.eventID = be.eventID
    JOIN Calendar c      ON c.calendarID = be.calendarID
    JOIN School   s      ON s.schoolID   = c.schoolID
    WHERE br.role IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@countedRoles, ','))   -- roles to count
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
    GROUP BY br.personID
),
fail AS (   -- failing grades per student for @task in @term
    SELECT gs.personID, COUNT(*) AS failCount,
           SUM(CASE WHEN CHARINDEX(',' + RTRIM(co.scedSubjectArea) + ',', ',' + REPLACE(@elaMathAreas, ' ', '') + ',') > 0
                    THEN 1 ELSE 0 END) AS coreFailCount
    FROM GradingScore gs
    JOIN GradingTask gt ON gt.taskID    = gs.taskID
    JOIN Term tm        ON tm.termID    = gs.termID
    JOIN Section se     ON se.sectionID = gs.sectionID
    JOIN Course co      ON co.courseID  = se.courseID
    JOIN Calendar c     ON c.calendarID = gs.calendarID
    JOIN School   s     ON s.schoolID   = c.schoolID
    WHERE gs.score IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@failMarks, ','))   -- failing marks
      AND gt.name LIKE @task
      AND (@term IS NULL OR tm.name = @term)
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
    GROUP BY gs.personID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       att.scheduledDays AS [Days Enrolled], att.daysAbsent AS [Days Absent], m.pctAbsent AS [Percent Absent],
       m.referrals AS [Referrals],
       m.failCount AS [Failing Grades], m.coreFailCount AS [English/Math Failing Grades],
       CASE f.attFlag   WHEN 1 THEN 'Y' ELSE '' END AS [Attendance Flag],
       CASE f.behFlag   WHEN 1 THEN 'Y' ELSE '' END AS [Behavior Flag],
       CASE f.gradeFlag WHEN 1 THEN 'Y' ELSE '' END AS [Course Flag],
       f.attFlag + f.behFlag + f.gradeFlag AS [Flag Count]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN att  ON att.personID  = a.personID
LEFT JOIN ref  ON ref.personID  = a.personID
LEFT JOIN fail ON fail.personID = a.personID
CROSS APPLY (SELECT CAST(100.0 * att.daysAbsent / NULLIF(att.scheduledDays, 0) AS decimal(5,1)) AS pctAbsent,
                    ISNULL(ref.referrals, 0)      AS referrals,
                    ISNULL(fail.failCount, 0)     AS failCount,
                    ISNULL(fail.coreFailCount, 0) AS coreFailCount) m
CROSS APPLY (SELECT CASE WHEN m.pctAbsent >= @absentPct    THEN 1 ELSE 0 END AS attFlag,
                    CASE WHEN m.referrals >= @minReferrals THEN 1 ELSE 0 END AS behFlag,
                    CASE WHEN a.grade IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@msGrades, ','))
                              AND m.coreFailCount >= @minFails THEN 1
                         WHEN a.grade NOT IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@msGrades, ','))
                              AND m.failCount >= @minFails THEN 1
                         ELSE 0 END AS gradeFlag) f
WHERE a.rn = 1
  AND f.attFlag + f.behFlag + f.gradeFlag >= 1
ORDER BY a.schoolName, f.attFlag + f.behFlag + f.gradeFlag DESC, a.grade, i.lastName, i.firstName;
