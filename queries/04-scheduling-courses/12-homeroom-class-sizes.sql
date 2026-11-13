/* ======================================================================================
   #139  Homeroom class sizes
   --------------------------------------------------------------------------------------
   Status:    Needs review
   Category:  Scheduling & courses
   Type:      KPI · Priority 2 · Run BOY
   Purpose:   How many students sit in each homeroom on @asOf, by school and grade, with
              the homeroom teacher and room, to balance homerooms and answer class-size
              questions.
   Output:    One row per school, grade and homeroom section: teacher, room, section,
              students in that grade, the grade's total across all its homerooms, the
              grade's average homeroom size and the school's average homeroom size
   Tables:    SchoolYear, Section, Trial, Calendar, School, Course, Room, Roster,
              Enrollment, SectionStaffHistory, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Homerooms are sections flagged Section.homeroomSection = 1 in the active
              trial. Grade is the student's primary enrollment grade on @asOf, so a
              mixed-grade homeroom shows one row per grade. Teacher is
              SectionStaffHistory.staffType = 'P' (primary) on @asOf. Students rostered
              without a primary enrollment that day are not counted. Grade Avg = grade
              total / homerooms with that grade; School Avg = school students / distinct
              homerooms in the school.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

SET NOCOUNT ON;

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH hr AS (
SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       e.grade AS [Grade], pt.teacher AS [Homeroom Teacher], rm.name AS [Room],
       co.name AS [Course Name], se.number AS [Section Number],
       COUNT(DISTINCT r.personID) AS [Students],
       se.sectionID
FROM Section se
JOIN Trial    t ON t.trialID    = se.trialID
JOIN Calendar c ON c.calendarID = t.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Course  co ON co.courseID  = se.courseID
LEFT JOIN Room rm ON rm.roomID  = se.roomID
JOIN Roster   r ON r.sectionID  = se.sectionID
               AND (r.startDate IS NULL OR r.startDate <= @asOf)
               AND (r.endDate IS NULL OR r.endDate >= @asOf)
JOIN Enrollment e ON e.personID = r.personID
                 AND e.calendarID = c.calendarID
                 AND e.serviceType = 'P'
                 AND e.startDate <= @asOf
                 AND (e.endDate IS NULL OR e.endDate >= @asOf)
OUTER APPLY (SELECT TOP 1 CONCAT(ti.lastName, ', ', ti.firstName) AS teacher
             FROM SectionStaffHistory ssh
             JOIN Person tp     ON tp.personID   = ssh.personID
             JOIN [Identity] ti ON ti.identityID = tp.currentIdentityID
             WHERE ssh.sectionID = se.sectionID AND ssh.staffType = 'P'
               AND (ssh.startDate IS NULL OR ssh.startDate <= @asOf)
               AND (ssh.endDate IS NULL OR ssh.endDate >= @asOf)
             ORDER BY ssh.historyID DESC) pt
WHERE se.homeroomSection = 1
  AND t.active = 1
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
GROUP BY c.schoolID, s.name, c.endYear, e.grade, pt.teacher, rm.name,
         co.name, se.number, se.sectionID
), x AS (
SELECT hr.*,
       -- two DENSE_RANKs = distinct homerooms per school (COUNT DISTINCT isn't allowed OVER)
       DENSE_RANK() OVER (PARTITION BY [School ID] ORDER BY sectionID)
     + DENSE_RANK() OVER (PARTITION BY [School ID] ORDER BY sectionID DESC) - 1 AS schoolHomerooms
FROM hr
)
SELECT [School ID], [School], [School Year], [Grade], [Homeroom Teacher], [Room],
       [Course Name], [Section Number], [Students],
       SUM([Students]) OVER (PARTITION BY [School ID], [Grade]) AS [Grade Total],
       CAST(1.0 * SUM([Students]) OVER (PARTITION BY [School ID], [Grade])
            / COUNT(*) OVER (PARTITION BY [School ID], [Grade]) AS decimal(6,1)) AS [Grade Avg],
       CAST(1.0 * SUM([Students]) OVER (PARTITION BY [School ID])
            / schoolHomerooms AS decimal(6,1)) AS [School Avg]
FROM x
ORDER BY [School], [Grade], [Homeroom Teacher], [Section Number];
