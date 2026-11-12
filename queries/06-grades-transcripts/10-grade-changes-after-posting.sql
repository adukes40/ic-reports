/* ======================================================================================
   #74  Grade changes after posting
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 2 · Run Term
   Purpose:   Posted grades whose record was last changed after grading closed for the
              term.
   Output:    One row per changed grade: course, section, teacher, term, task, current
              mark and percent, date posted, when grading closed, when it was last changed
   Tables:    SchoolYear, Calendar, School, ScheduleStructure, TermSchedule, Term,
              GradingWindow, GradingScore, GradingTask, Section, Trial, Course,
              Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @closeDate  (change them in the PARAMETERS block below)
   Check:     Campus keeps only the current mark and the last-changed time on a posted
              grade here: who changed it and the old value are not stored, so they are
              not in the output. With @closeDate blank, grading closes for a term when
              its last grading window ends, or on the term end date if it has no window.
              A comment edit also moves the last-changed time.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @closeDate date = NULL;   -- last day grades could be posted; NULL = each term's grading window end
-- ===========================================================================

WITH win AS (   -- every term this year and the moment grading closed for it
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear, t.termID, t.name AS termName,
           COALESCE(DATEADD(day, 1, CAST(@closeDate AS datetime)),
                    (SELECT MAX(gw.endDateTime) FROM GradingWindow gw
                     WHERE gw.termID = t.termID AND gw.calendarID = c.calendarID),
                    DATEADD(day, 1, t.endDate)) AS closedAt
    FROM Calendar c
    JOIN School s             ON s.schoolID       = c.schoolID
    JOIN ScheduleStructure ss ON ss.calendarID    = c.calendarID
    JOIN TermSchedule ts      ON ts.structureID   = ss.structureID
    JOIN Term t               ON t.termScheduleID = ts.termScheduleID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       w.schoolID AS [School ID], w.schoolName AS [School], w.endYear AS [School Year], g.grade AS [Grade],
       co.number AS [Course Number], co.name AS [Course], se.number AS [Section], se.teacherDisplay AS [Teacher],
       w.termName AS [Term], gt.name AS [Task],
       gs.score AS [Current Mark], CAST(gs.[percent] AS decimal(6,2)) AS [Current Percent],
       CONVERT(date, gs.[date]) AS [Date Posted],
       w.closedAt AS [Grading Closed], gs.modifiedDate AS [Last Changed]
FROM win w
JOIN GradingScore gs ON gs.termID = w.termID AND gs.calendarID = w.calendarID
JOIN GradingTask gt  ON gt.taskID    = gs.taskID
JOIN Section se      ON se.sectionID = gs.sectionID
JOIN Trial tr        ON tr.trialID   = se.trialID AND tr.active = 1
JOIN Course co       ON co.courseID  = se.courseID
JOIN Person p        ON p.personID   = gs.personID
JOIN [Identity] i    ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade            -- latest enrollment in that calendar
             FROM Enrollment e
             WHERE e.personID = gs.personID AND e.calendarID = gs.calendarID
             ORDER BY e.startDate DESC) g
WHERE NULLIF(LTRIM(RTRIM(gs.score)), '') IS NOT NULL
  AND gs.modifiedDate > w.closedAt
ORDER BY w.schoolName, gs.modifiedDate DESC, i.lastName, i.firstName;
