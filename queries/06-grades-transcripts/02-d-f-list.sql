/* ======================================================================================
   #66  D/F list
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 1 · Run Progress periods
   Purpose:   Active students with a D or F in the term, by course, section and teacher.
              Uses the posted grade, or the in-progress grade when nothing is posted yet.
   Output:    One row per student, section and grading task: course, section, teacher,
              task, mark, percent, whether the mark is posted or in progress
   Tables:    SchoolYear, Enrollment, Calendar, School, ScheduleStructure, TermSchedule,
              Term, GradingScore, GradingTask, Section, Trial, Course, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @term, @task, @marks  (change them in the
              PARAMETERS block below)
   Check:     @marks must list your D and F marks exactly as they are posted (default
              D+, D, D-, F); a school that posts only numbers needs its own list. @task
              is matched against your GradingTask names; blank means every task.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int          = NULL;   -- NULL = all schools
DECLARE @asOf     date         = CONVERT(date, GETDATE());
DECLARE @term     varchar(10)  = NULL;   -- term name, e.g. 'Q1'; NULL = the term in session on @asOf
DECLARE @task     varchar(100) = '';     -- part of the grading task name, e.g. 'Quarter'; '' = every task
DECLARE @marks    varchar(200) = 'D+,D,D-,F';   -- marks to list, comma separated
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, e.calendarID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
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
trm AS (   -- the term to report on in each calendar
    SELECT ss.calendarID, t.termID, t.name AS termName
    FROM ScheduleStructure ss
    JOIN TermSchedule ts ON ts.structureID   = ss.structureID
    JOIN Term t          ON t.termScheduleID = ts.termScheduleID
    WHERE t.name = @term OR (@term IS NULL AND t.startDate <= @asOf AND t.endDate >= @asOf)
),
marks AS (   -- posted mark, else in-progress mark, per student, section and task in the term
    SELECT gs.personID, gs.calendarID, gs.sectionID, gs.taskID, tm.termName,
           COALESCE(NULLIF(LTRIM(RTRIM(gs.score)), ''), NULLIF(LTRIM(RTRIM(gs.progressScore)), '')) AS mark,
           CASE WHEN NULLIF(LTRIM(RTRIM(gs.score)), '') IS NOT NULL THEN gs.[percent] ELSE gs.progressPercent END AS pct,
           CASE WHEN NULLIF(LTRIM(RTRIM(gs.score)), '') IS NOT NULL THEN 'Posted' ELSE 'In progress' END AS source
    FROM GradingScore gs
    JOIN trm tm ON tm.termID = gs.termID AND tm.calendarID = gs.calendarID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       m.termName AS [Term], co.number AS [Course Number], co.name AS [Course],
       se.number AS [Section], se.teacherDisplay AS [Teacher], gt.name AS [Task],
       m.mark AS [Mark], CAST(m.pct AS decimal(6,2)) AS [Percent], m.source AS [Grade Source]
FROM marks m
JOIN act a          ON a.personID = m.personID AND a.calendarID = m.calendarID AND a.rn = 1
JOIN GradingTask gt ON gt.taskID    = m.taskID
JOIN Section se     ON se.sectionID = m.sectionID
JOIN Trial tr       ON tr.trialID   = se.trialID AND tr.active = 1
JOIN Course co      ON co.courseID  = se.courseID
JOIN Person p       ON p.personID   = a.personID
JOIN [Identity] i   ON i.identityID = p.currentIdentityID
WHERE gt.name LIKE '%' + @task + '%'
  AND CHARINDEX(',' + m.mark + ',', ',' + REPLACE(@marks, ' ', '') + ',') > 0
ORDER BY a.schoolName, i.lastName, i.firstName, co.number, gt.name;
