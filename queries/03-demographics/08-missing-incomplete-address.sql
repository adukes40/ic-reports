/* ======================================================================================
   #37  Missing or incomplete address
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Primary household with no current address, no current address marked physical,
              or an address missing street, city, state or zip.
   Output:    One row per household per problem: household, address parts, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HouseholdMember,
              HouseholdLocation, Address
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Primary household = HouseholdMember.secondary = 0. Students in no household
              are left to #38. A missing physical flag silently drops guardian and address
              data in extracts.
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
hh AS (
    SELECT a.personID, hm.householdID
    FROM act a
    JOIN HouseholdMember hm ON hm.personID = a.personID
    WHERE a.rn = 1
      AND ISNULL(hm.secondary, 0) = 0
      AND (hm.endDate IS NULL OR hm.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       hh.householdID AS [Household ID], ad.addressID AS [Address ID], ad.number AS [House Number], ad.street AS [Street], ad.city AS [City], ad.state AS [State], ad.zip AS [Zip],
       x.issue AS [Issue]
FROM hh
JOIN act a        ON a.personID   = hh.personID AND a.rn = 1
JOIN Person p     ON p.personID   = hh.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (
    SELECT COUNT(*) AS currentLocations,
           ISNULL(SUM(CASE WHEN hl.physical = 1 THEN 1 ELSE 0 END), 0) AS physicalLocations
    FROM HouseholdLocation hl
    WHERE hl.householdID = hh.householdID
      AND (hl.endDate IS NULL OR hl.endDate >= @asOf)
) loc
OUTER APPLY (
    SELECT TOP 1 adr.addressID, adr.number, adr.street, adr.city, adr.state, adr.zip
    FROM HouseholdLocation hl
    JOIN [Address] adr ON adr.addressID = hl.addressID
    WHERE hl.householdID = hh.householdID
      AND (hl.endDate IS NULL OR hl.endDate >= @asOf)
    ORDER BY ISNULL(hl.physical, 0) DESC, adr.addressID DESC
) ad
CROSS APPLY (VALUES
    (CASE WHEN loc.currentLocations = 0 THEN 'Household has no current address' END),
    (CASE WHEN loc.currentLocations > 0 AND loc.physicalLocations = 0
          THEN 'No current address is marked physical' END),
    (CASE WHEN ad.addressID IS NOT NULL AND NULLIF(LTRIM(RTRIM(ad.street)), '') IS NULL THEN 'Address has no street' END),
    (CASE WHEN ad.addressID IS NOT NULL AND NULLIF(LTRIM(RTRIM(ad.city)),   '') IS NULL THEN 'Address has no city' END),
    (CASE WHEN ad.addressID IS NOT NULL AND NULLIF(LTRIM(RTRIM(ad.state)),  '') IS NULL THEN 'Address has no state' END),
    (CASE WHEN ad.addressID IS NOT NULL AND NULLIF(LTRIM(RTRIM(ad.zip)),    '') IS NULL THEN 'Address has no zip' END)
) x(issue)
WHERE x.issue IS NOT NULL
ORDER BY a.schoolName, a.grade, i.lastName;
