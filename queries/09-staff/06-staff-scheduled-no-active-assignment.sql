/* ======================================================================================
   #110  Staff scheduled with no active assignment
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Staff
   Type:      Validation · Priority 2 · Run BOY
   Purpose:   Staff on this year's sections who have no district assignment open on
              @asOf at the school where they are scheduled.
   Output:    One row per staff person and school: staff number, name, school, number of
              sections, issue
   Tables:    SchoolYear, SectionStaffHistory, Section, Trial, Calendar, School,
              EmploymentAssignment, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Counts every staff row on a section (primary teacher, teacher and section
              staff) whose section-staff dates cover @asOf; blank dates count as current.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH sched AS (   -- one row per staff person and school: sections they are on in the active trial
    SELECT ssh.personID, c.schoolID, s.name AS schoolName, c.endYear,
           COUNT(DISTINCT se.sectionID) AS sections
    FROM SectionStaffHistory ssh
    JOIN Section  se ON se.sectionID = ssh.sectionID
    JOIN Trial    t  ON t.trialID    = se.trialID AND t.active = 1
    JOIN Calendar c  ON c.calendarID = t.calendarID
    JOIN School   s  ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND (ssh.startDate IS NULL OR ssh.startDate <= @asOf)
      AND (ssh.endDate   IS NULL OR ssh.endDate   >= @asOf)
    GROUP BY ssh.personID, c.schoolID, s.name, c.endYear
)
SELECT p.staffNumber AS [Staff Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       sc.schoolID AS [School ID], sc.schoolName AS [School], sc.endYear AS [School Year],
       sc.sections AS [Sections],
       CASE WHEN EXISTS (SELECT 1 FROM EmploymentAssignment ea
                         WHERE ea.personID = sc.personID AND ea.schoolID = sc.schoolID)
            THEN 'District assignment at this school is not active'
            ELSE 'No district assignment at this school' END AS [Issue]
FROM sched sc
JOIN Person p     ON p.personID   = sc.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE NOT EXISTS (SELECT 1 FROM EmploymentAssignment ea
                  WHERE ea.personID = sc.personID AND ea.schoolID = sc.schoolID
                    AND (ea.startDate IS NULL OR ea.startDate <= @asOf)
                    AND (ea.endDate   IS NULL OR ea.endDate   >= @asOf))
ORDER BY sc.schoolName, i.lastName, i.firstName;
