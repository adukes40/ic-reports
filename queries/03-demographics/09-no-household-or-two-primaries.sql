/* ======================================================================================
   #38  Students in no household / two primaries
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Active students with no current household membership, more than one
              household marked primary, or households but none marked primary.
   Output:    One row per student: current household count, primary household count, the
              households, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HouseholdMember,
              Household
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Primary household = HouseholdMember.secondary = 0 (the Secondary box
              unchecked). A student with two primary households gets mailings and portal
              data from both.
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
       hh.households AS [Current Households], hh.primaries AS [Primary Households], hh.householdList AS [Households],
       CASE WHEN hh.households = 0 THEN 'No current household'
            WHEN hh.primaries  = 0 THEN 'No household marked primary'
            ELSE 'More than one primary household' END AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (
    SELECT COUNT(DISTINCT hm.householdID) AS households,
           COUNT(DISTINCT CASE WHEN ISNULL(hm.secondary, 0) = 0 THEN hm.householdID END) AS primaries,
           STRING_AGG(CONCAT(h.name, ' (ID ', hm.householdID,
                             CASE WHEN ISNULL(hm.secondary, 0) = 0 THEN ', primary)' ELSE ', secondary)' END), '; ') AS householdList
    FROM HouseholdMember hm
    JOIN Household h ON h.householdID = hm.householdID
    WHERE hm.personID = a.personID
      AND (hm.startDate IS NULL OR hm.startDate <= @asOf)
      AND (hm.endDate   IS NULL OR hm.endDate   >= @asOf)
) hh
WHERE a.rn = 1
  AND (hh.households = 0 OR hh.primaries <> 1)
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
