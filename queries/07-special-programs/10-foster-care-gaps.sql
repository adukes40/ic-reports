/* ======================================================================================
   #88  Foster care gaps
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Active foster care records for active students where the student has no
              state ID or the record has no case worker name or phone.
   Output:    One row per problem: school, grade, foster care record start and end, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, FosterCare, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     The state ID checked is the student's own. The foster ID, agency, placement
              type and custody dates on the foster care record are not checked because
              they are not filled in here; add them to the list of checks if your
              district uses them.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       CONVERT(date, f.startDate) AS [Foster Care Start], CONVERT(date, f.endDate) AS [Foster Care End],
       x.issue AS [Issue]
FROM act a
JOIN FosterCare f ON f.personID   = a.personID
                 AND f.startDate <= @asOf AND (f.endDate IS NULL OR f.endDate >= @asOf)
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(p.stateID)), '') IS NULL THEN 'Student has no state ID' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(f.caseWorkerLName)), '') IS NULL
           AND NULLIF(LTRIM(RTRIM(f.caseWorkerFName)), '') IS NULL THEN 'No case worker name' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(f.caseWorkerPhone)), '') IS NULL THEN 'No case worker phone' END)
) x(issue)
WHERE a.rn = 1
  AND x.issue IS NOT NULL
ORDER BY a.schoolName, x.issue, a.grade, i.lastName, i.firstName;
