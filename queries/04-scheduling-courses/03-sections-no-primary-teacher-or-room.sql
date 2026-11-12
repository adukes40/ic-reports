/* ======================================================================================
   #44  Sections with no primary teacher or room
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Active-trial sections that have students on @asOf but no active primary
              teacher, or no room. These break rosters, state course reporting and
              ClassLink.
   Output:    One row per section and problem: course, section, teacher, room, students
   Tables:    SchoolYear, Section, Trial, Calendar, School, Course, Room, Roster,
              SectionStaffHistory, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Primary teacher is read as SectionStaffHistory.staffType = 'P' with dates
              covering @asOf; confirm 'P' is the primary-teacher code in your data.
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
       pt.teacher AS [Teacher], rm.name AS [Room], rc.students AS [Students],
       iss.issue AS [Issue]
FROM Section se
JOIN Trial    t ON t.trialID    = se.trialID
JOIN Calendar c ON c.calendarID = t.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Course  co ON co.courseID  = se.courseID
LEFT JOIN Room rm ON rm.roomID  = se.roomID
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
CROSS APPLY (VALUES (CASE WHEN pt.teacher IS NULL THEN 'No active primary teacher' END),
                    (CASE WHEN se.roomID IS NULL  THEN 'No room assigned' END)) iss(issue)
WHERE t.active = 1
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND rc.students > 0
  AND iss.issue IS NOT NULL
ORDER BY s.name, co.number, se.number, iss.issue;
