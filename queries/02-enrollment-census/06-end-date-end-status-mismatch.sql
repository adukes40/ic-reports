/* ======================================================================================
   #6  End date / end status mismatch
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run Ongoing, EOY
   Purpose:   End date with no end status, end status with no end date, or a graduation end
              status below grade 12.
   Output:    One row per problem: grade, dates, end status, issue
   Tables:    Calendar, School, Enrollment, CampusAttribute, CampusDictionary, Person,
              Identity
   Params:    @endYear, @schoolID, @gradWord ('%grad%')  (change them in the PARAMETERS
              block below)
   Check:     Graduation codes are found by dictionary name containing 'grad'. Confirm
              against your end status list.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @gradWord varchar(20) = '%grad%';
-- ===========================================================================

WITH gradCodes AS (
    SELECT d.code, d.name
    FROM CampusAttribute a
    JOIN CampusDictionary d ON d.attributeID = a.attributeID
    WHERE a.object = 'Enrollment' AND a.element = 'endStatus'
      AND d.name LIKE @gradWord
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       e.grade AS [Grade], e.serviceType AS [Service Type],
       CONVERT(date, e.startDate) AS [Start Date],
       CONVERT(date, e.endDate)   AS [End Date],
       e.endStatus AS [End Status],
       x.issue AS [Issue]
FROM Enrollment e
JOIN Calendar c ON c.calendarID = e.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN e.endDate IS NOT NULL AND NULLIF(LTRIM(RTRIM(e.endStatus)), '') IS NULL
          THEN 'End date with no end status' END),
    (CASE WHEN e.endDate IS NULL AND NULLIF(LTRIM(RTRIM(e.endStatus)), '') IS NOT NULL
          THEN 'End status with no end date' END),
    (CASE WHEN e.endStatus IN (SELECT code FROM gradCodes)
           AND TRY_CAST(e.grade AS int) < 12
          THEN 'Graduation end status below grade 12' END)
) x(issue)
WHERE x.issue IS NOT NULL
  AND c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY s.name, x.issue, i.lastName;
