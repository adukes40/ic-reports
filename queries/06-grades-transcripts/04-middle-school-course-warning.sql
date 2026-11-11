/* ======================================================================================
   #68  Middle school course warning
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 1 · Run Quarter
   Purpose:   Active grade 6-8 students failing an English or math course in the term, or
              with a term GPA under the minimum (2.0).
   Output:    One row per student: failing English/math courses with the mark, term GPA,
              reason
   Tables:    SchoolYear, Enrollment, Calendar, School, ScheduleStructure, TermSchedule,
              Term, GradingScore, GradingTask, Section, Trial, Course, GradingTaskCredit,
              ScoreListItem, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @term, @task, @failMarks, @minGPA  (change them
              in the PARAMETERS block below)
   Check:     @failMarks must list your failing marks exactly as posted (default F).
              English and math are courses with SCED subject area 01 or 02, so courses
              with no SCED code are missed. Term GPA is worked out here from each mark's
              GPA value in the course's score group, weighted by the course GPA weight;
              it is blank where score groups carry no GPA values. Uses the posted grade,
              or the in-progress grade when nothing is posted. Set @task to the one task
              that carries the term grade, or the GPA mixes every task.
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
DECLARE @minGPA    decimal(4,2) = 2.0;    -- warn when the term GPA is below this
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per grade 6-8 student on @asOf
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
      AND e.grade IN ('06', '07', '08')
),
trm AS (   -- the term to report on in each calendar
    SELECT ss.calendarID, t.termID
    FROM ScheduleStructure ss
    JOIN TermSchedule ts ON ts.structureID   = ss.structureID
    JOIN Term t          ON t.termScheduleID = ts.termScheduleID
    WHERE t.name = @term OR (@term IS NULL AND t.startDate <= @asOf AND t.endDate >= @asOf)
),
marks AS (   -- posted mark, else in-progress mark, per student and course, with its GPA value
    SELECT a.personID, co.name AS courseName, co.gpaWeight, x.mark, gv.gpaValue,
           CASE WHEN co.scedSubjectArea IN ('01', '02')
                 AND CHARINDEX(',' + x.mark + ',', ',' + REPLACE(@failMarks, ' ', '') + ',') > 0
                THEN 1 ELSE 0 END AS failingCore
    FROM act a
    JOIN GradingScore gs ON gs.personID = a.personID AND gs.calendarID = a.calendarID
    JOIN trm tm          ON tm.termID   = gs.termID  AND tm.calendarID = gs.calendarID
    JOIN GradingTask gt  ON gt.taskID    = gs.taskID
    JOIN Section se      ON se.sectionID = gs.sectionID
    JOIN Trial tr        ON tr.trialID   = se.trialID AND tr.active = 1
    JOIN Course co       ON co.courseID  = se.courseID
    CROSS APPLY (SELECT COALESCE(NULLIF(LTRIM(RTRIM(gs.score)), ''),
                                 NULLIF(LTRIM(RTRIM(gs.progressScore)), '')) AS mark) x
    OUTER APPLY (SELECT TOP 1 sli.gpaValue
                 FROM GradingTaskCredit gtc
                 JOIN ScoreListItem sli ON sli.scoreGroupID = gtc.scoreGroupID
                 WHERE gtc.courseID = co.courseID AND gtc.taskID = gs.taskID
                   AND sli.score = x.mark AND sli.gpaValue IS NOT NULL) gv
    WHERE a.rn = 1
      AND gt.name LIKE '%' + @task + '%'
      AND x.mark IS NOT NULL
),
stu AS (   -- per student: failing English/math courses and the term GPA
    SELECT m.personID,
           STRING_AGG(CASE WHEN m.failingCore = 1 THEN CAST(m.courseName + ' (' + m.mark + ')' AS varchar(max)) END, ', ')
               WITHIN GROUP (ORDER BY m.courseName) AS failingCourses,
           CAST(SUM(CASE WHEN m.gpaWeight > 0 THEN m.gpaValue * m.gpaWeight END)
                / NULLIF(SUM(CASE WHEN m.gpaWeight > 0 AND m.gpaValue IS NOT NULL THEN m.gpaWeight END), 0)
                AS decimal(5,3)) AS termGPA
    FROM marks m
    GROUP BY m.personID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       st.failingCourses AS [Failing English/Math], st.termGPA AS [Term GPA],
       CASE WHEN st.failingCourses IS NOT NULL AND st.termGPA < @minGPA THEN 'Failing English or math, and low term GPA'
            WHEN st.failingCourses IS NOT NULL THEN 'Failing English or math'
            ELSE 'Low term GPA' END AS [Reason]
FROM stu st
JOIN act a        ON a.personID   = st.personID AND a.rn = 1
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE st.failingCourses IS NOT NULL OR st.termGPA < @minGPA
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
