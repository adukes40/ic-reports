/* ======================================================================================
   #41  Legal vs preferred name differences
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      List · Priority 3 · Run Ongoing
   Purpose:   Active students whose preferred name (the Nickname field) differs from their
              first name, with both values, so account and roster syncs use the name the
              district intends.
   Output:    One row per student: last, first and middle name, preferred name
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     The Legal Name fields (Identity.legalFirstName, legalLastName) are not
              filled in here, so first/last name is taken as the legal name and
              Identity.alias (Nickname) as the preferred name. A nickname equal to the
              first name or to first + last name is not listed. If Legal Name fields start
              being used, this query needs to compare those instead.
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
       i.middleName AS [Middle Name], LTRIM(RTRIM(i.alias)) AS [Preferred Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND NULLIF(LTRIM(RTRIM(i.alias)), '') IS NOT NULL
  AND LTRIM(RTRIM(i.alias)) <> LTRIM(RTRIM(i.firstName))
  AND LTRIM(RTRIM(i.alias)) <> CONCAT(LTRIM(RTRIM(i.firstName)), ' ', LTRIM(RTRIM(i.lastName)))
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
