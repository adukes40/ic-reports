/* ======================================================================================
   #109  Assignment / employment date conflicts
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Staff
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   District assignments still open after the person's employment ended, and
              district assignments or employment records with no start date.
   Output:    One row per problem: staff number, name, school, assignment start and end,
              employment start and end, issue
   Tables:    SchoolYear, EmploymentAssignment, Employment, School, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Assignments are matched to employment by person. An assignment counts as
              still open when the person has employment records and every one of them
              ended before @asOf. Employment records have no school, so they show the
              person's latest assignment school.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH emp AS (   -- one row per person with employment records: latest start/end and whether any is still open
    SELECT em.personID, MAX(em.startDate) AS lastStart, MAX(em.endDate) AS lastEnd,
           MAX(CASE WHEN em.endDate IS NULL OR em.endDate >= @asOf THEN 1 ELSE 0 END) AS hasOpen
    FROM Employment em
    GROUP BY em.personID
),
prob AS (       -- one row per date problem
    SELECT ea.personID, ea.schoolID, ea.startDate AS asgStart, ea.endDate AS asgEnd,
           emp.lastStart AS empStart, emp.lastEnd AS empEnd,
           'District assignment still open after employment ended' AS issue
    FROM EmploymentAssignment ea
    JOIN emp ON emp.personID = ea.personID
    WHERE emp.hasOpen = 0
      AND (ea.endDate IS NULL OR ea.endDate >= @asOf)

    UNION ALL

    SELECT ea.personID, ea.schoolID, ea.startDate, ea.endDate, NULL, NULL,
           'District assignment has no start date'
    FROM EmploymentAssignment ea
    WHERE ea.startDate IS NULL

    UNION ALL

    SELECT em.personID, la.schoolID, NULL, NULL, em.startDate, em.endDate,
           'Employment record has no start date'
    FROM Employment em
    OUTER APPLY (SELECT TOP 1 ea.schoolID
                 FROM EmploymentAssignment ea
                 WHERE ea.personID = em.personID
                 ORDER BY ea.startDate DESC, ea.assignmentID DESC) la
    WHERE em.startDate IS NULL
)
SELECT p.staffNumber AS [Staff Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       pr.schoolID AS [School ID], s.name AS [School], @endYear AS [School Year],
       CONVERT(date, pr.asgStart) AS [Assignment Start], CONVERT(date, pr.asgEnd) AS [Assignment End],
       CONVERT(date, pr.empStart) AS [Employment Start], CONVERT(date, pr.empEnd) AS [Employment End],
       pr.issue AS [Issue]
FROM prob pr
JOIN Person p     ON p.personID   = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN School s ON s.schoolID  = pr.schoolID
WHERE (s.schoolID IS NULL OR s.exclude = 0)
  AND (@schoolID IS NULL OR pr.schoolID = @schoolID)
ORDER BY s.name, i.lastName, i.firstName, pr.issue;
