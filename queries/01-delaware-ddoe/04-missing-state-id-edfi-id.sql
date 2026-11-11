/* ======================================================================================
   #4  Students missing state ID / Ed-Fi ID
   --------------------------------------------------------------------------------------
   Status:    Needs review
   Category:  Delaware DOE
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Active students with no state ID or Ed-Fi ID, and active staff with no staff
              state ID.
   Output:    One row per problem: person type, local number, name, school, grade or title,
              issue
   Tables:    Calendar, School, Enrollment, EmploymentAssignment, Person, Identity
   Params:    @endYear, @schoolID, @asOf (today)  (change them in the PARAMETERS block
              below)
   Check:     State-excluded enrollments skip the Ed-Fi ID check, as the prompt asked.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH stu AS (   -- one row per active student (their primary school today)
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade, e.stateExclude,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P'
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
staff AS (      -- one row per active staff person (first school by assignment start)
    SELECT ea.personID, ea.schoolID, s.name AS schoolName, ea.title,
           ROW_NUMBER() OVER (PARTITION BY ea.personID ORDER BY ea.startDate) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
    WHERE s.exclude = 0
      AND (ea.startDate IS NULL OR ea.startDate <= @asOf)
      AND (ea.endDate IS NULL OR ea.endDate >= @asOf)
      AND (@schoolID IS NULL OR ea.schoolID = @schoolID)
)
SELECT 'Student' AS [Person Type], p.studentNumber AS [Local Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year], st.grade AS [Grade], NULL AS [Staff Title],
       x.issue AS [Issue]
FROM stu st
JOIN Person p ON p.personID = st.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(p.stateID)), '') IS NULL THEN 'Student has no state ID' END),
    (CASE WHEN st.stateExclude = 0 AND NULLIF(LTRIM(RTRIM(p.edFiID)), '') IS NULL
          THEN 'Student has no Ed-Fi ID' END)
) x(issue)
WHERE st.rn = 1 AND x.issue IS NOT NULL

UNION ALL

SELECT 'Staff', p.staffNumber, i.lastName, i.firstName,
       sf.schoolID, sf.schoolName, @endYear, NULL, sf.title,
       'Staff member has no staff state ID'
FROM staff sf
JOIN Person p ON p.personID = sf.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE sf.rn = 1
  AND NULLIF(LTRIM(RTRIM(p.staffStateID)), '') IS NULL

ORDER BY [Person Type], [School], [Last Name], [First Name];
