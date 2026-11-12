/* ======================================================================================
   #49  Course setup not pushed
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      Validation · Priority 3 · Run BOY
   Purpose:   Active courses linked to a course master whose grading tasks or credit
              settings differ from the master's, meaning a course-master change was not
              pushed (or the course was edited by hand).
   Output:    One row per course and grading task or standard that differs: course,
              course master number, task, standard, course and master credit, what
              differs
   Tables:    SchoolYear, Course, Calendar, School, CourseMaster, GradingTaskCredit,
              GradingTaskCreditMaster, GradingTask, CurriculumStandard
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Course and master rows are matched on grading task and standard. Compared
              settings: credit, GPA weight, terms (term mask), score group and post-only.
              Grade calculation options and categories are not compared; IC's built-in
              Grading Changes Not Pushed report covers those.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH crs AS (   -- active courses this year that are linked to a course master
    SELECT co.courseID, co.courseMasterID, co.number, co.name, cm.number AS masterNumber,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM Course co
    JOIN Calendar c      ON c.calendarID = co.calendarID
    JOIN School   s      ON s.schoolID   = c.schoolID
    JOIN CourseMaster cm ON cm.courseMasterID = co.courseMasterID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND co.active = 1
),
diff AS (   -- one row per course and task/standard that is missing on one side or set differently
    SELECT k.courseID, m.taskID, m.standardID, CAST(NULL AS decimal(18,4)) AS courseCredit, m.credit AS masterCredit,
           CAST('On the course master but not on the course' AS varchar(200)) AS issue
    FROM crs k
    JOIN GradingTaskCreditMaster m ON m.courseMasterID = k.courseMasterID
    WHERE NOT EXISTS (SELECT 1 FROM GradingTaskCredit g
                      WHERE g.courseID = k.courseID AND g.taskID = m.taskID
                        AND (g.standardID = m.standardID OR (g.standardID IS NULL AND m.standardID IS NULL)))
    UNION ALL
    SELECT k.courseID, g.taskID, g.standardID, g.credit, NULL,
           'On the course but not on the course master'
    FROM crs k
    JOIN GradingTaskCredit g ON g.courseID = k.courseID
    WHERE NOT EXISTS (SELECT 1 FROM GradingTaskCreditMaster m
                      WHERE m.courseMasterID = k.courseMasterID AND m.taskID = g.taskID
                        AND (m.standardID = g.standardID OR (m.standardID IS NULL AND g.standardID IS NULL)))
    UNION ALL
    SELECT k.courseID, g.taskID, g.standardID, g.credit, m.credit,
           'Differs from the course master: ' + CONCAT_WS(', ',
               CASE WHEN ISNULL(g.credit, 0)       <> ISNULL(m.credit, 0)       THEN 'credit' END,
               CASE WHEN ISNULL(g.termGPA, 0)      <> ISNULL(m.termGPA, 0)      THEN 'GPA weight' END,
               CASE WHEN ISNULL(g.termMask, 0)     <> ISNULL(m.termMask, 0)     THEN 'terms' END,
               CASE WHEN ISNULL(g.scoreGroupID, 0) <> ISNULL(m.scoreGroupID, 0) THEN 'score group' END,
               CASE WHEN ISNULL(g.postOnly, 0)     <> ISNULL(m.postOnly, 0)     THEN 'post only' END)
    FROM crs k
    JOIN GradingTaskCredit g       ON g.courseID = k.courseID
    JOIN GradingTaskCreditMaster m ON m.courseMasterID = k.courseMasterID AND m.taskID = g.taskID
                                  AND (m.standardID = g.standardID OR (m.standardID IS NULL AND g.standardID IS NULL))
    WHERE ISNULL(g.credit, 0)       <> ISNULL(m.credit, 0)
       OR ISNULL(g.termGPA, 0)      <> ISNULL(m.termGPA, 0)
       OR ISNULL(g.termMask, 0)     <> ISNULL(m.termMask, 0)
       OR ISNULL(g.scoreGroupID, 0) <> ISNULL(m.scoreGroupID, 0)
       OR ISNULL(g.postOnly, 0)     <> ISNULL(m.postOnly, 0)
)
SELECT k.schoolID AS [School ID], k.schoolName AS [School], k.endYear AS [School Year],
       k.number AS [Course Number], k.name AS [Course Name], k.masterNumber AS [Course Master Number],
       gt.name AS [Grading Task], cs.name AS [Standard],
       d.courseCredit AS [Course Credit], d.masterCredit AS [Master Credit],
       d.issue AS [Issue]
FROM diff d
JOIN crs k ON k.courseID = d.courseID
LEFT JOIN GradingTask gt        ON gt.taskID     = d.taskID
LEFT JOIN CurriculumStandard cs ON cs.standardID = d.standardID
ORDER BY k.schoolName, k.number, gt.seq, cs.seq;
