/* ======================================================================================
   #84  504 roster for teachers
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      List · Priority 1 · Run BOY, semester
   Purpose:   For each section meeting on @asOf, the rostered students who have an active
              504, with teacher and period, so teachers know whose accommodations apply.
              Shows only that a 504 exists and its dates.
   Output:    One row per student per section: school, grade, teacher, course, section,
              period, 504 start and end
   Tables:    SchoolYear, Enrollment, Calendar, School, Trial, Section, Course, Roster,
              SectionPlacement, Term, Period, Section504, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     504s are read from the Section 504 tab (Section504), not from plan
              documents: a record counts when it has started, has not ended, and has no
              did-not-qualify date. Teacher is the section's teacher display name.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
plan504 AS (   -- active 504 records on @asOf, newest first per student
    SELECT f.personID, f.startDate, f.endDate,
           ROW_NUMBER() OVER (PARTITION BY f.personID ORDER BY f.startDate DESC, f.section504ID DESC) AS rn
    FROM Section504 f
    WHERE f.startDate <= @asOf AND (f.endDate IS NULL OR f.endDate >= @asOf)
      AND f.dnqDate IS NULL
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year], a.grade AS [Grade],
       se.teacherDisplay AS [Teacher],
       co.number AS [Course Number], co.name AS [Course], se.number AS [Section],
       per.periods AS [Period],
       CONVERT(date, f.startDate) AS [504 Start], CONVERT(date, f.endDate) AS [504 End]
FROM Trial t
JOIN Calendar c   ON c.calendarID  = t.calendarID
JOIN School   s   ON s.schoolID    = c.schoolID
JOIN Section se   ON se.trialID    = t.trialID
JOIN Course co    ON co.courseID   = se.courseID
JOIN Roster r     ON r.sectionID   = se.sectionID AND r.trialID = t.trialID
JOIN plan504 f    ON f.personID    = r.personID AND f.rn = 1
JOIN act a        ON a.personID    = r.personID AND a.rn = 1
JOIN Person p     ON p.personID    = r.personID
JOIN [Identity] i ON i.identityID  = p.currentIdentityID
CROSS APPLY (SELECT STRING_AGG(x.name, ', ') WITHIN GROUP (ORDER BY x.seq) AS periods
             FROM (SELECT pd.name, MIN(pd.seq) AS seq          -- periods the section meets in the current term
                   FROM SectionPlacement sp
                   JOIN Term tm   ON tm.termID   = sp.termID
                   JOIN Period pd ON pd.periodID = sp.periodID
                   WHERE sp.sectionID = se.sectionID AND sp.trialID = se.trialID
                     AND (tm.startDate IS NULL OR tm.startDate <= @asOf)
                     AND (tm.endDate   IS NULL OR tm.endDate   >= @asOf)
                   GROUP BY pd.name) x) per
WHERE t.active = 1
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (r.startDate IS NULL OR r.startDate <= @asOf)
  AND (r.endDate   IS NULL OR r.endDate   >= @asOf)
  AND per.periods IS NOT NULL
ORDER BY s.name, se.teacherDisplay, per.periods, co.name, se.number, i.lastName, i.firstName;
