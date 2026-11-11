/* ======================================================================================
   #50  Teacher load
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Scheduling & courses
   Type:      KPI · Priority 3 · Run Semester
   Purpose:   For each primary teacher on @asOf: how many sections they teach, how many
              different courses (preps) and how many different students.
   Output:    One row per teacher per school: sections, preps, students
   Tables:    SchoolYear, SectionStaffHistory, Section, Trial, Calendar, School,
              SectionPlacement, Term, Roster, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Primary teacher is SectionStaffHistory.staffType = 'P' with dates covering
              @asOf; confirm 'P' is the primary-teacher code in your data. Only sections
              that meet in a term covering @asOf are counted, so set @asOf to a day inside
              the term you want. A teacher at two schools gets a row for each.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH teach AS (   -- one row per primary teacher and section meeting in a term that covers @asOf
    SELECT DISTINCT ssh.personID, c.schoolID, s.name AS schoolName, c.endYear, se.sectionID, se.courseID
    FROM SectionStaffHistory ssh
    JOIN Section se ON se.sectionID = ssh.sectionID
    JOIN Trial    t ON t.trialID    = se.trialID
    JOIN Calendar c ON c.calendarID = t.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE ssh.staffType = 'P'
      AND (ssh.startDate IS NULL OR ssh.startDate <= @asOf)
      AND (ssh.endDate IS NULL OR ssh.endDate >= @asOf)
      AND t.active = 1
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND EXISTS (
          SELECT 1
          FROM SectionPlacement sp
          JOIN Term tm ON tm.termID = sp.termID
          WHERE sp.sectionID = se.sectionID
            AND (tm.startDate IS NULL OR tm.startDate <= @asOf)
            AND (tm.endDate IS NULL OR tm.endDate >= @asOf))
)
SELECT k.schoolID AS [School ID], k.schoolName AS [School], k.endYear AS [School Year],
       ti.lastName AS [Teacher Last Name], ti.firstName AS [Teacher First Name],
       COUNT(DISTINCT k.sectionID) AS [Sections],
       COUNT(DISTINCT k.courseID)  AS [Preps],
       COUNT(DISTINCT r.personID)  AS [Students]
FROM teach k
JOIN Person tp     ON tp.personID   = k.personID
JOIN [Identity] ti ON ti.identityID = tp.currentIdentityID
LEFT JOIN Roster r ON r.sectionID = k.sectionID
                  AND (r.startDate IS NULL OR r.startDate <= @asOf)
                  AND (r.endDate IS NULL OR r.endDate >= @asOf)
GROUP BY k.schoolID, k.schoolName, k.endYear, k.personID, ti.lastName, ti.firstName
ORDER BY k.schoolName, ti.lastName, ti.firstName;
