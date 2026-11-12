/* ======================================================================================
   #48  Courses missing grading tasks
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      Validation · Priority 2 · Run BOY
   Purpose:   Active courses this year that have sections in the active trial but no
              grading task or standard assigned, which stops grades from posting.
   Output:    One row per course: course number and name, number of sections
   Tables:    SchoolYear, Course, Calendar, School, Trial, Section, GradingTaskCredit
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     A course counts as set up when it has any GradingTaskCredit row (grading
              task or standard). Courses that are never graded (lunch, homeroom, study
              hall) will show.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       co.number AS [Course Number], co.name AS [Course Name],
       sc.sections AS [Sections],
       'No grading task or standard assigned' AS [Issue]
FROM Course co
JOIN Calendar c ON c.calendarID = co.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
CROSS APPLY (SELECT COUNT(*) AS sections
             FROM Trial t
             JOIN Section se ON se.trialID = t.trialID
             WHERE t.calendarID = co.calendarID AND t.active = 1
               AND se.courseID = co.courseID) sc
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND co.active = 1
  AND sc.sections > 0
  AND NOT EXISTS (SELECT 1 FROM GradingTaskCredit g WHERE g.courseID = co.courseID)
ORDER BY s.name, co.number;
