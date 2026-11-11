/* ======================================================================================
   #75  Grade book usage
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      KPI · Priority 3 · Run Monthly
   Purpose:   For every graded section meeting this term, how many assignments have at
              least one score and when a score was last entered. Flags sections with
              fewer than the minimum.
   Output:    One row per section: course, section, teacher, students, scored assignments,
              last scoring date, days since, flag
   Tables:    SchoolYear, Calendar, School, ScheduleStructure, TermSchedule, Term, Trial,
              Section, SectionPlacement, Course, GradingTaskCredit, Roster,
              LessonPlanGroupActivity, LessonPlanScore
   Params:    @endYear, @schoolID, @asOf, @term, @minAssignments (3)  (change them in the
              PARAMETERS block below)
   Check:     A section counts when its course has a grading task and it has students, so
              courses graded outside the Campus grade book (or synced late from another
              system) will be flagged. Last Scored is the last time any score for the
              term was entered or changed.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int         = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int         = NULL;   -- NULL = all schools
DECLARE @asOf           date        = CONVERT(date, GETDATE());
DECLARE @term           varchar(10) = NULL;   -- term name, e.g. 'Q1'; NULL = the term in session on @asOf
DECLARE @minAssignments int         = 3;      -- flag sections with fewer scored assignments than this
-- ===========================================================================

WITH trm AS (   -- the term to report on in each calendar, and the date used to read the roster
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear, t.termID, t.name AS termName,
           CASE WHEN t.endDate < @asOf THEN CONVERT(date, t.endDate) ELSE @asOf END AS rosterDate
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
sec AS (   -- graded sections that meet in the term, with their student count
    SELECT tm.schoolID, tm.schoolName, tm.endYear, tm.termID, tm.termName,
           se.sectionID, co.number AS courseNumber, co.name AS courseName,
           se.number AS sectionNumber, se.teacherDisplay,
           (SELECT COUNT(DISTINCT r.personID) FROM Roster r
            WHERE r.sectionID = se.sectionID AND r.trialID = tr.trialID
              AND (r.startDate IS NULL OR r.startDate <= tm.rosterDate)
              AND (r.endDate   IS NULL OR r.endDate   >= tm.rosterDate)) AS students
    FROM trm tm
    JOIN Trial tr   ON tr.calendarID = tm.calendarID AND tr.active = 1
    JOIN Section se ON se.trialID    = tr.trialID
    JOIN Course co  ON co.courseID   = se.courseID
    WHERE EXISTS (SELECT 1 FROM SectionPlacement sp
                  WHERE sp.sectionID = se.sectionID AND sp.termID = tm.termID)
      AND EXISTS (SELECT 1 FROM GradingTaskCredit gtc WHERE gtc.courseID = co.courseID)
),
scored AS (   -- assignments with at least one score, per section and term
    SELECT ga.sectionID, ga.termID,
           COUNT(DISTINCT ga.objectSectionID) AS assignments,
           MAX(ls.modifiedDate) AS lastScored
    FROM LessonPlanGroupActivity ga
    JOIN LessonPlanScore ls ON ls.groupActivityID = ga.groupActivityID
    WHERE ga.termID IN (SELECT termID FROM trm)
      AND NULLIF(LTRIM(RTRIM(ls.score)), '') IS NOT NULL
    GROUP BY ga.sectionID, ga.termID
)
SELECT sc.schoolID AS [School ID], sc.schoolName AS [School], sc.endYear AS [School Year],
       sc.termName AS [Term], sc.courseNumber AS [Course Number], sc.courseName AS [Course],
       sc.sectionNumber AS [Section], sc.teacherDisplay AS [Teacher], sc.students AS [Students],
       ISNULL(sd.assignments, 0) AS [Scored Assignments],
       CONVERT(date, sd.lastScored) AS [Last Scored],
       DATEDIFF(day, sd.lastScored, @asOf) AS [Days Since Last Score],
       CASE WHEN ISNULL(sd.assignments, 0) = 0 THEN 'No scored assignments'
            WHEN sd.assignments < @minAssignments THEN 'Below minimum'
            ELSE '' END AS [Flag]
FROM sec sc
LEFT JOIN scored sd ON sd.sectionID = sc.sectionID AND sd.termID = sc.termID
WHERE sc.students > 0
ORDER BY sc.schoolName, ISNULL(sd.assignments, 0), sc.teacherDisplay, sc.courseNumber, sc.sectionNumber;
