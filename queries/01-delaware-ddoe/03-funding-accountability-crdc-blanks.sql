/* ======================================================================================
   #3  Funding / accountability / CRDC school blanks
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      Validation · Priority 1 · Run BOY, Sept
   Purpose:   Current primary enrollments missing Funding School, Accountability School or
              CRDC School of Accountability, or still using retired DAFB code 100893.
   Output:    One row per problem: student, school, grade, the three field values, issue
   Tables:    Calendar, School, Enrollment, EnrollmentDE, Person, Identity
   Params:    @endYear, @schoolID, @retiredCode ('100893'), @activeOnly (1)  (change them in
              the PARAMETERS block below)
   Check:     CRDC School of Accountability is assumed to be
              Enrollment.schoolOfAccountability. Confirm on the DE Enrollments tab.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int = NULL;          -- NULL = all schools
DECLARE @retiredCode  varchar(10) = '100893';  -- DAFB funding code retired for 2025-26 (now 140893)
DECLARE @activeOnly   bit = 1;             -- 1 = only enrollments open today
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       e.grade AS [Grade],
       CONVERT(date, e.startDate) AS [Start Date],
       CONVERT(date, e.endDate)   AS [End Date],
       de.fundingSchool AS [Funding School], de.accountabilitySchool AS [Accountability School],
       e.schoolOfAccountability   AS [CRDC School of Accountability],
       x.issue AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN EnrollmentDE de ON de.enrollmentID = e.enrollmentID
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(de.fundingSchool)), '') IS NULL
          THEN 'Funding School is blank' END),
    (CASE WHEN LTRIM(RTRIM(de.fundingSchool)) = @retiredCode
          THEN 'Funding School uses retired DAFB code ' + @retiredCode END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(de.accountabilitySchool)), '') IS NULL
          THEN 'Accountability School is blank' END),
    (CASE WHEN e.schoolOfAccountability IS NULL
          THEN 'CRDC School of Accountability is blank' END)
) x(issue)
WHERE x.issue IS NOT NULL
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND e.serviceType = 'P'
  AND e.stateExclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (@activeOnly = 0 OR (e.startDate <= GETDATE() AND (e.endDate IS NULL OR e.endDate >= CONVERT(date, GETDATE()))))
ORDER BY s.name, x.issue, i.lastName, i.firstName;
