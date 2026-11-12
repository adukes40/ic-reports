/* ======================================================================================
   #67  Course failures by section
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      KPI · Priority 2 · Run Term
   Purpose:   D and F counts and the D/F rate for every section's posted grades in the
              term, with the teacher, to spot outliers.
   Output:    One row per section and grading task: course, section, teacher, students
              graded, D count, F count, D/F count, D/F rate %
   Tables:    SchoolYear, Calendar, School, ScheduleStructure, TermSchedule, Term,
              GradingScore, GradingTask, Section, Trial, Course
   Params:    @endYear, @schoolID, @asOf, @term, @task, @dMarks, @fMarks  (change them in
              the PARAMETERS block below)
   Check:     @dMarks and @fMarks must list your marks exactly as they are posted. Only
              posted scores count. @task is matched against your GradingTask names; blank
              means every task. Small sections swing the rate: read it beside Students
              Graded.
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
DECLARE @dMarks   varchar(200) = 'D+,D,D-';   -- marks counted as a D, comma separated
DECLARE @fMarks   varchar(200) = 'F';         -- marks counted as an F, comma separated
-- ===========================================================================

WITH trm AS (   -- the term to report on in each calendar
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear, t.termID, t.name AS termName
    FROM Calendar c
    JOIN School s             ON s.schoolID       = c.schoolID
    JOIN ScheduleStructure ss ON ss.calendarID    = c.calendarID
    JOIN TermSchedule ts      ON ts.structureID   = ss.structureID
    JOIN Term t               ON t.termScheduleID = ts.termScheduleID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND (t.name = @term OR (@term IS NULL AND t.startDate <= @asOf AND t.endDate >= @asOf))
),
posted AS (   -- one row per posted score in the term, flagged D or F
    SELECT tm.schoolID, tm.schoolName, tm.endYear, tm.termName, gs.sectionID, gs.taskID,
           CASE WHEN CHARINDEX(',' + LTRIM(RTRIM(gs.score)) + ',', ',' + REPLACE(@dMarks, ' ', '') + ',') > 0 THEN 1 ELSE 0 END AS isD,
           CASE WHEN CHARINDEX(',' + LTRIM(RTRIM(gs.score)) + ',', ',' + REPLACE(@fMarks, ' ', '') + ',') > 0 THEN 1 ELSE 0 END AS isF
    FROM GradingScore gs
    JOIN trm tm ON tm.termID = gs.termID AND tm.calendarID = gs.calendarID
    WHERE NULLIF(LTRIM(RTRIM(gs.score)), '') IS NOT NULL
)
SELECT po.schoolID AS [School ID], po.schoolName AS [School], po.endYear AS [School Year],
       po.termName AS [Term], co.number AS [Course Number], co.name AS [Course],
       se.number AS [Section], se.teacherDisplay AS [Teacher], gt.name AS [Task],
       COUNT(*) AS [Students Graded],                     -- denominator
       SUM(po.isD) AS [D Count], SUM(po.isF) AS [F Count],
       SUM(po.isD) + SUM(po.isF) AS [D/F Count],          -- numerator
       CAST(100.0 * (SUM(po.isD) + SUM(po.isF)) / COUNT(*) AS decimal(5,1)) AS [D/F Rate %]
FROM posted po
JOIN GradingTask gt ON gt.taskID    = po.taskID
JOIN Section se     ON se.sectionID = po.sectionID
JOIN Trial tr       ON tr.trialID   = se.trialID AND tr.active = 1
JOIN Course co      ON co.courseID  = se.courseID
WHERE gt.name LIKE '%' + @task + '%'
GROUP BY po.schoolID, po.schoolName, po.endYear, po.termName, co.number, co.name,
         se.sectionID, se.number, se.teacherDisplay, gt.name
ORDER BY [D/F Rate %] DESC, po.schoolName, co.number, se.number;
