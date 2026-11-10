/* ======================================================================================
   #30  Missing or invalid sex / gender
   --------------------------------------------------------------------------------------
   Status:    Needs review
   Category:  Demographics
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Active students with a blank gender, or a code not in the Identity gender
              list.
   Output:    One row per student: gender value, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, CampusAttribute,
              CampusDictionary
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Valid codes come from CampusDictionary for Identity.gender. If your district
              has no list there, only blanks are flagged.
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
),
genderCodes AS (
    SELECT cd.code
    FROM CampusAttribute ca
    JOIN CampusDictionary cd ON cd.attributeID = ca.attributeID
    WHERE ca.object = 'Identity' AND ca.element = 'gender'
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       i.gender AS [Gender],
       CASE WHEN NULLIF(LTRIM(RTRIM(i.gender)), '') IS NULL THEN 'Gender is blank'
            ELSE 'Gender code ' + i.gender + ' is not in the gender list' END AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND (NULLIF(LTRIM(RTRIM(i.gender)), '') IS NULL
       OR (EXISTS (SELECT 1 FROM genderCodes)
           AND i.gender NOT IN (SELECT code FROM genderCodes)))
ORDER BY a.schoolName, a.grade, i.lastName;
