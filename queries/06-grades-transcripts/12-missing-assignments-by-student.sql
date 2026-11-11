/* ======================================================================================
   #76  Missing assignments by student
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 3 · Run Weekly
   Purpose:   Assignments flagged Missing in the grade book for active students, due in
              the date range, in classes they are still in.
   Output:    One row per student and missing assignment: course, section, teacher,
              assignment, due date
   Tables:    SchoolYear, Enrollment, Calendar, School, LessonPlanScore,
              IMLearningObjectSection, IMLearningObject, Section, Trial, Course, Roster,
              Person, Identity
   Params:    @endYear, @schoolID, @asOf, @startDate, @endDate  (change them in the
              PARAMETERS block below)
   Check:     Only work the teacher has ticked Missing is listed; an empty score is not
              counted. The due date is the assignment's end date. The default range is
              the 30 days up to today.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @asOf      date = CONVERT(date, GETDATE());
DECLARE @startDate date = DATEADD(day, -30, @asOf);   -- first due date to include
DECLARE @endDate   date = @asOf;                      -- last due date to include
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
)
SELECT DISTINCT
       p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       co.number AS [Course Number], co.name AS [Course], se.number AS [Section], se.teacherDisplay AS [Teacher],
       lo.name AS [Assignment], CONVERT(date, os.endDate) AS [Due Date]
FROM LessonPlanScore ls
JOIN IMLearningObjectSection os ON os.objectSectionID = ls.objectSectionID
JOIN IMLearningObject lo        ON lo.objectID        = os.objectID
JOIN Section se   ON se.sectionID = ls.sectionID
JOIN Trial tr     ON tr.trialID   = se.trialID AND tr.active = 1
JOIN Course co    ON co.courseID  = se.courseID
JOIN act a        ON a.personID   = ls.personID AND a.calendarID = tr.calendarID AND a.rn = 1
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE ls.missing = 1
  AND os.active = 1
  AND os.endDate >= @startDate AND os.endDate < DATEADD(day, 1, @endDate)
  AND EXISTS (SELECT 1 FROM Roster r
              WHERE r.sectionID = se.sectionID AND r.trialID = tr.trialID AND r.personID = ls.personID
                AND (r.startDate IS NULL OR r.startDate <= @asOf)
                AND (r.endDate   IS NULL OR r.endDate   >= @asOf))
ORDER BY [School], [Last Name], [First Name], [Due Date], [Course Number];
