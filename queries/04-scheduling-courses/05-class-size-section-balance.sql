/* ======================================================================================
   #46  Class size / section balance
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      KPI · Priority 2 · Run BOY
   Purpose:   Students rostered in each section on @asOf against the section's max, to
              spot overloaded and near-empty sections of the same course.
   Output:    One row per section: course, teacher, terms, periods, students, max
              students, seats open, percent full
   Tables:    SchoolYear, Section, Trial, Calendar, School, Course, Roster,
              SectionStaffHistory, Person, Identity, SectionPlacement, Term, Period
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Sections in every term of the year are listed, with students rostered on
              @asOf. Percent Full is blank where the section has no max students. Teacher
              is SectionStaffHistory.staffType = 'P' (primary) on @asOf.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       co.number AS [Course Number], co.name AS [Course Name], se.number AS [Section Number],
       pt.teacher AS [Teacher], tr.terms AS [Terms], pr.periods AS [Periods],
       rc.students AS [Students], se.maxStudents AS [Max Students],
       se.maxStudents - rc.students AS [Seats Open],
       CAST(100.0 * rc.students / NULLIF(se.maxStudents, 0) AS decimal(6,1)) AS [Percent Full]
FROM Section se
JOIN Trial    t ON t.trialID    = se.trialID
JOIN Calendar c ON c.calendarID = t.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Course  co ON co.courseID  = se.courseID
CROSS APPLY (SELECT COUNT(DISTINCT r.personID) AS students
             FROM Roster r
             WHERE r.sectionID = se.sectionID
               AND (r.startDate IS NULL OR r.startDate <= @asOf)
               AND (r.endDate IS NULL OR r.endDate >= @asOf)) rc
OUTER APPLY (SELECT TOP 1 CONCAT(ti.lastName, ', ', ti.firstName) AS teacher
             FROM SectionStaffHistory ssh
             JOIN Person tp     ON tp.personID   = ssh.personID
             JOIN [Identity] ti ON ti.identityID = tp.currentIdentityID
             WHERE ssh.sectionID = se.sectionID AND ssh.staffType = 'P'
               AND (ssh.startDate IS NULL OR ssh.startDate <= @asOf)
               AND (ssh.endDate IS NULL OR ssh.endDate >= @asOf)
             ORDER BY ssh.historyID DESC) pt
OUTER APPLY (SELECT STRING_AGG(x.name, ', ') WITHIN GROUP (ORDER BY x.seq) AS terms
             FROM (SELECT tm.name, MIN(tm.seq) AS seq
                   FROM SectionPlacement sp
                   JOIN Term tm ON tm.termID = sp.termID
                   WHERE sp.sectionID = se.sectionID
                   GROUP BY tm.name) x) tr
OUTER APPLY (SELECT STRING_AGG(x.name, ', ') WITHIN GROUP (ORDER BY x.seq) AS periods
             FROM (SELECT pd.name, MIN(pd.seq) AS seq
                   FROM SectionPlacement sp
                   JOIN Period pd ON pd.periodID = sp.periodID
                   WHERE sp.sectionID = se.sectionID
                   GROUP BY pd.name) x) pr
WHERE t.active = 1
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND co.active = 1
ORDER BY s.name, co.number, se.number;
