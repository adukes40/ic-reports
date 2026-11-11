/* ======================================================================================
   #47  Empty sections
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      List · Priority 3 · Run BOY
   Purpose:   Active-trial sections with no students rostered on @asOf. They still sync
              to Google and ClassLink, so delete them or roster them.
   Output:    One row per empty section: course, section, teacher, terms, periods, room,
              max students
   Tables:    SchoolYear, Section, Trial, Calendar, School, Course, Room, Roster,
              SectionStaffHistory, Person, Identity, SectionPlacement, Term, Period
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Sections in every term of the year are listed, so a later-term section not
              rostered yet will show. Teacher is SectionStaffHistory.staffType = 'P'
              (primary) on @asOf.
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
       rm.name AS [Room], se.maxStudents AS [Max Students]
FROM Section se
JOIN Trial    t ON t.trialID    = se.trialID
JOIN Calendar c ON c.calendarID = t.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Course  co ON co.courseID  = se.courseID
LEFT JOIN Room rm ON rm.roomID  = se.roomID
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
  AND NOT EXISTS (
      SELECT 1
      FROM Roster r
      WHERE r.sectionID = se.sectionID
        AND (r.startDate IS NULL OR r.startDate <= @asOf)
        AND (r.endDate IS NULL OR r.endDate >= @asOf))
ORDER BY s.name, co.number, se.number;
