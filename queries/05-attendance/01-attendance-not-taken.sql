/* ======================================================================================
   #53  Attendance not taken
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      Validation · Priority 1 · Run Daily
   Purpose:   Sections that met on the chosen day and have students on the roster, but no
              teacher attendance was saved for them.
   Output:    One row per section per period: teacher, course, section, period, students
              rostered, issue
   Tables:    SchoolYear, Calendar, School, Day, Period, SectionPlacement, Trial, Term,
              Section, Course, Roster, AttendanceCounts, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     "Taken" = an AttendanceCounts row for the section and date. Its per-period
              bitmask is not decoded, so a section that meets several periods counts as
              taken once any one period is saved. Only courses with the Attendance box
              checked and periods not marked non-instructional are listed. Spot-check one
              section you know was taken and one you know was not.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());   -- the day to check
-- ===========================================================================

WITH met AS (   -- attendance-taking sections and the periods they met on @asOf
    SELECT c.schoolID, s.name AS schoolName, c.endYear,
           se.sectionID, se.number AS sectionNumber, se.teacherPersonID, se.teacherDisplay,
           co.number AS courseNumber, co.name AS courseName,
           pd.name AS periodName, pd.seq AS periodSeq
    FROM Calendar c
    JOIN School s            ON s.schoolID = c.schoolID
    JOIN Day d               ON d.calendarID = c.calendarID AND d.date = @asOf
                            AND d.instruction = 1 AND d.attendance = 1
    JOIN Period pd           ON pd.periodScheduleID = d.periodScheduleID AND pd.nonInstructional = 0
    JOIN SectionPlacement sp ON sp.periodID = pd.periodID
    JOIN Trial t             ON t.trialID = sp.trialID AND t.calendarID = c.calendarID AND t.active = 1
    JOIN Term tm             ON tm.termID = sp.termID AND tm.startDate <= @asOf AND tm.endDate >= @asOf
    JOIN Section se          ON se.sectionID = sp.sectionID AND se.trialID = t.trialID
    JOIN Course co           ON co.courseID = se.courseID AND co.attendance = 1
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT m.schoolID AS [School ID], m.schoolName AS [School], m.endYear AS [School Year],
       COALESCE(ti.lastName + ', ' + ti.firstName, m.teacherDisplay) AS [Teacher],
       m.courseNumber AS [Course Number], m.courseName AS [Course], m.sectionNumber AS [Section],
       m.periodName AS [Period],
       r.students AS [Students Rostered],
       @asOf AS [Date],
       'No attendance taken for this section on ' + CONVERT(varchar(10), @asOf, 23) AS [Issue]
FROM met m
CROSS APPLY (SELECT COUNT(*) AS students
             FROM Roster ro
             WHERE ro.sectionID = m.sectionID
               AND (ro.startDate IS NULL OR ro.startDate <= @asOf)
               AND (ro.endDate   IS NULL OR ro.endDate   >= @asOf)) r
LEFT JOIN Person tp     ON tp.personID   = m.teacherPersonID
LEFT JOIN [Identity] ti ON ti.identityID = tp.currentIdentityID
WHERE r.students > 0
  AND NOT EXISTS (SELECT 1 FROM AttendanceCounts ac
                  WHERE ac.sectionID = m.sectionID AND ac.date = @asOf)
ORDER BY m.schoolName, [Teacher], m.periodSeq, m.courseNumber, m.sectionNumber;
