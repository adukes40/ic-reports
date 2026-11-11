/* ======================================================================================
   #111  Staff roster by school and role
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Staff
   Type:      List · Priority 3 · Run BOY
   Purpose:   Directory of active staff by school for building leaders and HR.
   Output:    One row per active district assignment: staff number, name, school, roles,
              department, assignment start date, email
   Tables:    SchoolYear, EmploymentAssignment, School, Department, Person, Identity,
              Contact
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     The assignment Title field is not filled in, so Roles comes from the
              assignment checkboxes (Teacher, Special Ed, Counselor, Advisor, Behavior,
              Health). Email is the one on the person's contact record.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

SELECT p.staffNumber AS [Staff Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       ea.schoolID AS [School ID], s.name AS [School], @endYear AS [School Year],
       CONCAT_WS(', ',
           CASE WHEN ea.teacher   = 1 THEN 'Teacher'    END,
           CASE WHEN ea.specialed = 1 THEN 'Special Ed' END,
           CASE WHEN ea.counselor = 1 THEN 'Counselor'  END,
           CASE WHEN ea.advisor   = 1 THEN 'Advisor'    END,
           CASE WHEN ea.behavior  = 1 THEN 'Behavior'   END,
           CASE WHEN ea.health    = 1 THEN 'Health'     END) AS [Roles],
       d.name AS [Department],
       CONVERT(date, ea.startDate) AS [Assignment Start],
       (SELECT MAX(NULLIF(LTRIM(RTRIM(con.email)), ''))
          FROM Contact con
         WHERE con.personID = ea.personID) AS [Email]
FROM EmploymentAssignment ea
JOIN School s          ON s.schoolID     = ea.schoolID
JOIN Person p          ON p.personID     = ea.personID
JOIN [Identity] i      ON i.identityID   = p.currentIdentityID
LEFT JOIN Department d ON d.departmentID = ea.departmentID
WHERE s.exclude = 0
  AND (@schoolID IS NULL OR ea.schoolID = @schoolID)
  AND (ea.startDate IS NULL OR ea.startDate <= @asOf)
  AND (ea.endDate   IS NULL OR ea.endDate   >= @asOf)
ORDER BY s.name, i.lastName, i.firstName;
