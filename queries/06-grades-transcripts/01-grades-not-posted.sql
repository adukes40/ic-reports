/* ======================================================================================
   #65  Grades not posted
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      Validation · Priority 1 · Run End of term
   Purpose:   Sections where at least one rostered student has no posted score for a
              grading task the course is set to grade in the term.
   Output:    One row per section and grading task: course, section, teacher, students
              rostered, students with no posted score
   Tables:    SchoolYear, Calendar, School, ScheduleStructure, TermSchedule, Term, Trial,
              Section, SectionPlacement, Course, GradingTaskCredit, GradingTask, Roster,
              GradingScore
   Params:    @endYear, @schoolID, @asOf, @term, @task  (change them in the PARAMETERS
              block below)
   Check:     @task is matched against your GradingTask names; left blank it checks every
              task ticked for the term on the course (GradingTaskCredit.termMask, one bit
              per term in order), so tasks you never post will show until you narrow it.
              After the term has ended set @term, or @asOf to a date inside the term.
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
-- ===========================================================================

WITH trm AS (   -- the term to check in each calendar, and the date used to read the roster
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear,
           t.termID, t.name AS termName, t.seq,
           CASE WHEN t.endDate < @asOf THEN CONVERT(date, t.endDate) ELSE @asOf END AS rosterDate
    FROM Calendar c
    JOIN School s             ON s.schoolID        = c.schoolID
    JOIN ScheduleStructure ss ON ss.calendarID     = c.calendarID
    JOIN TermSchedule ts      ON ts.structureID    = ss.structureID
    JOIN Term t               ON t.termScheduleID  = ts.termScheduleID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND (t.name = @term OR (@term IS NULL AND t.startDate <= @asOf AND t.endDate >= @asOf))
),
due AS (   -- every rostered student and grading task that should have a posted score
    SELECT tm.schoolID, tm.schoolName, tm.endYear, tm.termName,
           se.sectionID, co.number AS courseNumber, co.name AS courseName,
           se.number AS sectionNumber, se.teacherDisplay,
           gt.taskID, gt.name AS taskName, r.personID,
           CASE WHEN EXISTS (SELECT 1 FROM GradingScore gs
                             WHERE gs.personID = r.personID AND gs.sectionID = se.sectionID
                               AND gs.termID = tm.termID AND gs.taskID = gt.taskID
                               AND (NULLIF(LTRIM(RTRIM(gs.score)), '') IS NOT NULL OR gs.[percent] IS NOT NULL))
                THEN 0 ELSE 1 END AS missing
    FROM trm tm
    JOIN Trial tr   ON tr.calendarID = tm.calendarID AND tr.active = 1
    JOIN Section se ON se.trialID    = tr.trialID
    JOIN Course co  ON co.courseID   = se.courseID
    JOIN GradingTaskCredit gtc ON gtc.courseID = co.courseID
                              AND (gtc.termMask & POWER(2, tm.seq - 1)) > 0
    JOIN GradingTask gt ON gt.taskID = gtc.taskID
    JOIN Roster r   ON r.sectionID = se.sectionID AND r.trialID = tr.trialID
    WHERE gt.name LIKE '%' + @task + '%'
      AND EXISTS (SELECT 1 FROM SectionPlacement sp
                  WHERE sp.sectionID = se.sectionID AND sp.termID = tm.termID)
      AND (r.startDate IS NULL OR r.startDate <= tm.rosterDate)
      AND (r.endDate   IS NULL OR r.endDate   >= tm.rosterDate)
)
SELECT d.schoolID AS [School ID], d.schoolName AS [School], d.endYear AS [School Year],
       d.termName AS [Term], d.courseNumber AS [Course Number], d.courseName AS [Course],
       d.sectionNumber AS [Section], d.teacherDisplay AS [Teacher], d.taskName AS [Task],
       COUNT(DISTINCT d.personID) AS [Students Rostered],
       COUNT(DISTINCT CASE WHEN d.missing = 1 THEN d.personID END) AS [Students Missing A Score],
       CASE WHEN COUNT(DISTINCT CASE WHEN d.missing = 1 THEN d.personID END) = COUNT(DISTINCT d.personID)
            THEN 'No scores posted for this task'
            ELSE 'Some students have no posted score' END AS [Issue]
FROM due d
GROUP BY d.schoolID, d.schoolName, d.endYear, d.termName, d.sectionID, d.courseNumber, d.courseName,
         d.sectionNumber, d.teacherDisplay, d.taskID, d.taskName
HAVING SUM(d.missing) > 0
ORDER BY d.schoolName, d.teacherDisplay, d.courseNumber, d.sectionNumber, d.taskName;
