/* ======================================================================================
   #77  Honor roll / class rank
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 3 · Run Term
   Purpose:   Active students whose term GPA meets the minimum, with their cumulative GPA
              and class rank within their school and grade.
   Output:    One row per honor roll student: term GPA, courses in the term GPA,
              cumulative GPA, class rank, class size
   Tables:    SchoolYear, Enrollment, Calendar, School, ScheduleStructure, TermSchedule,
              Term, GradingScore, GradingTask, Section, Trial, Course, GradingTaskCredit,
              ScoreListItem, TranscriptCourse, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @term, @task, @minGPA (3.0)  (change them in
              the PARAMETERS block below)
   Check:     GPA is not stored in a table here, so both are worked out. Term GPA = posted
              marks for @task in the term, each mark's GPA value from the course's score
              group, weighted by the course GPA weight. Set @task to the one task that
              carries the term grade, or the GPA mixes every task posted in the term.
              Cumulative GPA = transcript GPA value weighted by GPA weight, all years, no
              bonus points. Rank is by cumulative GPA among active students in the same
              school and grade, leaving out enrollments marked Class Rank Exclude; ties
              share a rank. Compare a few students with the Campus transcript before
              publishing.
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
DECLARE @minGPA   decimal(4,2) = 3.0;    -- lowest term GPA on the honor roll
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, e.calendarID, c.schoolID, s.name AS schoolName, c.endYear, e.grade, e.classRankExclude,
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
termGpa AS (   -- term GPA per student from the marks posted in the term
    SELECT a.personID, MAX(tm.termName) AS termName, COUNT(*) AS courses,
           CAST(SUM(gv.gpaValue * co.gpaWeight) / SUM(co.gpaWeight) AS decimal(5,3)) AS termGPA
    FROM act a
    JOIN GradingScore gs ON gs.personID = a.personID AND gs.calendarID = a.calendarID
    JOIN trm tm          ON tm.termID   = gs.termID  AND tm.calendarID = gs.calendarID
    JOIN GradingTask gt  ON gt.taskID    = gs.taskID
    JOIN Section se      ON se.sectionID = gs.sectionID
    JOIN Trial tr        ON tr.trialID   = se.trialID AND tr.active = 1
    JOIN Course co       ON co.courseID  = se.courseID
    CROSS APPLY (SELECT TOP 1 sli.gpaValue
                 FROM GradingTaskCredit gtc
                 JOIN ScoreListItem sli ON sli.scoreGroupID = gtc.scoreGroupID
                 WHERE gtc.courseID = co.courseID AND gtc.taskID = gs.taskID
                   AND sli.score = LTRIM(RTRIM(gs.score)) AND sli.gpaValue IS NOT NULL) gv
    WHERE a.rn = 1
      AND gt.name LIKE '%' + @task + '%'
      AND co.gpaWeight > 0
    GROUP BY a.personID
),
cum AS (   -- cumulative GPA per active student from the transcript
    SELECT tc.personID,
           CAST(SUM(tc.gpaValue * tc.gpaWeight) / SUM(tc.gpaWeight) AS decimal(5,3)) AS cumGPA
    FROM TranscriptCourse tc
    WHERE tc.gpaWeight > 0 AND tc.gpaValue IS NOT NULL
      AND tc.personID IN (SELECT personID FROM act WHERE rn = 1)
    GROUP BY tc.personID
),
ranked AS (   -- class rank and class size within school and grade, for students who can be ranked
    SELECT a.personID,
           RANK()   OVER (PARTITION BY a.schoolID, a.grade ORDER BY cu.cumGPA DESC) AS classRank,
           COUNT(*) OVER (PARTITION BY a.schoolID, a.grade) AS classSize
    FROM act a
    JOIN cum cu ON cu.personID = a.personID
    WHERE a.rn = 1 AND a.classRankExclude = 0
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       tg.termName AS [Term], tg.termGPA AS [Term GPA], tg.courses AS [Courses In Term GPA],
       cu.cumGPA AS [Cumulative GPA], rk.classRank AS [Class Rank], rk.classSize AS [Class Size]
FROM termGpa tg
JOIN act a          ON a.personID   = tg.personID AND a.rn = 1
LEFT JOIN cum cu    ON cu.personID  = a.personID
LEFT JOIN ranked rk ON rk.personID  = a.personID
JOIN Person p       ON p.personID   = a.personID
JOIN [Identity] i   ON i.identityID = p.currentIdentityID
WHERE tg.termGPA >= @minGPA
ORDER BY a.schoolName, a.grade, tg.termGPA DESC, i.lastName, i.firstName;
