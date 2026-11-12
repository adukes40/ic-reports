/* ======================================================================================
   #69  High school course warning
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 1 · Run Quarter
   Purpose:   Active grade 9-12 students with a failing grade in any course in the term.
   Output:    One row per student: number of failing courses, the courses with the mark
   Tables:    SchoolYear, Enrollment, Calendar, School, ScheduleStructure, TermSchedule,
              Term, GradingScore, GradingTask, Section, Trial, Course, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @term, @task, @failMarks, @hsGrades  (change
              them in the PARAMETERS block below)
   Check:     @failMarks must list your failing marks exactly as posted (default F); a
              school that posts only numbers needs its own list. @hsGrades must list your
              high school grade names. Uses the posted grade, or the in-progress grade
              when nothing is posted. @task is matched against your GradingTask names;
              blank means every task.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int          = NULL;   -- NULL = all schools
DECLARE @asOf      date         = CONVERT(date, GETDATE());
DECLARE @term      varchar(10)  = NULL;   -- term name, e.g. 'Q1'; NULL = the term in session on @asOf
DECLARE @task      varchar(100) = '';     -- part of the grading task name, e.g. 'Quarter'; '' = every task
DECLARE @failMarks varchar(200) = 'F';    -- failing marks, comma separated
DECLARE @hsGrades  varchar(200) = '09,10,11,12';   -- high school grade names, comma-separated
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per grade 9-12 student on @asOf
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
      AND e.grade IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@hsGrades, ','))
),
trm AS (   -- the term to report on in each calendar
    SELECT ss.calendarID, t.termID
    FROM ScheduleStructure ss
    JOIN TermSchedule ts ON ts.structureID   = ss.structureID
    JOIN Term t          ON t.termScheduleID = ts.termScheduleID
    WHERE t.name = @term OR (@term IS NULL AND t.startDate <= @asOf AND t.endDate >= @asOf)
),
fails AS (   -- failing posted mark, else failing in-progress mark, per student and course
    SELECT a.personID, se.sectionID, co.name AS courseName, x.mark
    FROM act a
    JOIN GradingScore gs ON gs.personID = a.personID AND gs.calendarID = a.calendarID
    JOIN trm tm          ON tm.termID   = gs.termID  AND tm.calendarID = gs.calendarID
    JOIN GradingTask gt  ON gt.taskID    = gs.taskID
    JOIN Section se      ON se.sectionID = gs.sectionID
    JOIN Trial tr        ON tr.trialID   = se.trialID AND tr.active = 1
    JOIN Course co       ON co.courseID  = se.courseID
    CROSS APPLY (SELECT COALESCE(NULLIF(LTRIM(RTRIM(gs.score)), ''),
                                 NULLIF(LTRIM(RTRIM(gs.progressScore)), '')) AS mark) x
    WHERE a.rn = 1
      AND gt.name LIKE '%' + @task + '%'
      AND CHARINDEX(',' + x.mark + ',', ',' + REPLACE(@failMarks, ' ', '') + ',') > 0
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       f.failingCount AS [Failing Courses], f.failingCourses AS [Courses]
FROM (SELECT personID, COUNT(DISTINCT sectionID) AS failingCount,
             STRING_AGG(CAST(courseName + ' (' + mark + ')' AS varchar(max)), ', ')
                 WITHIN GROUP (ORDER BY courseName) AS failingCourses
      FROM fails
      GROUP BY personID) f
JOIN act a        ON a.personID   = f.personID AND a.rn = 1
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY f.failingCount DESC, a.schoolName, a.grade, i.lastName, i.firstName;
