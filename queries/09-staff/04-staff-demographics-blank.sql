/* ======================================================================================
   #108  Staff demographics blank
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Staff
   Type:      Validation · Priority 2 · Run BOY
   Purpose:   Active staff whose current identity has no race, Hispanic/Latino answer,
              gender or birthdate.
   Output:    One row per problem: staff number, name, school, issue
   Tables:    SchoolYear, EmploymentAssignment, School, Person, Identity,
              IdentityRaceEthnicity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Active staff = a district assignment open on @asOf. Race is read from the
              race checkboxes (IdentityRaceEthnicity), not the state race code.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH staff AS (   -- one row per active staff person (first school by assignment start)
    SELECT ea.personID, ea.schoolID, s.name AS schoolName,
           ROW_NUMBER() OVER (PARTITION BY ea.personID ORDER BY ea.startDate, ea.assignmentID) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
    WHERE s.exclude = 0
      AND (ea.startDate IS NULL OR ea.startDate <= @asOf)
      AND (ea.endDate IS NULL OR ea.endDate >= @asOf)
      AND (@schoolID IS NULL OR ea.schoolID = @schoolID)
)
SELECT p.staffNumber AS [Staff Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       sf.schoolID AS [School ID], sf.schoolName AS [School], @endYear AS [School Year],
       x.issue AS [Issue]
FROM staff sf
JOIN Person p     ON p.personID   = sf.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NOT EXISTS (SELECT 1 FROM IdentityRaceEthnicity ire WHERE ire.identityID = i.identityID)
          THEN 'No race selected' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(i.hispanicEthnicity)), '') IS NULL
          THEN 'Hispanic/Latino answer is blank' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(i.gender)), '') IS NULL
          THEN 'Gender is blank' END),
    (CASE WHEN i.birthdate IS NULL
          THEN 'Birthdate is blank' END)
) x(issue)
WHERE sf.rn = 1 AND x.issue IS NOT NULL
ORDER BY sf.schoolName, i.lastName, i.firstName, x.issue;
