/* ======================================================================================
   #39  Address changes since a date
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      List · Priority 2 · Run Weekly
   Purpose:   Active students whose household got a new address on or after @sinceDate,
              with the old and new address, school and grade.
   Output:    One row per student per new household address: household, address type, new
              address and start date, old address and end date
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HouseholdMember,
              HouseholdLocation, Address
   Params:    @endYear, @schoolID, @asOf, @sinceDate  (change them in the PARAMETERS block below)
   Check:     @sinceDate defaults to 7 days ago. A change is a household address with a
              start date on or after @sinceDate; a student moved into a different
              household is not listed unless that household address is also new. Old
              address is the household's latest earlier address, blank if it had none.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @sinceDate date = DATEADD(day, -7, CONVERT(date, GETDATE()));   -- list addresses that started on or after this date
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
loc AS (   -- every household address, written on one line
    SELECT hl.householdID, hl.locationID, hl.addressID, hl.startDate, hl.endDate, hl.physical, hl.mailing,
           CONCAT_WS(', ',
               NULLIF(CONCAT_WS(' ', NULLIF(ad.number, ''), NULLIF(ad.prefix, ''), NULLIF(ad.street, ''),
                                     NULLIF(ad.tag, ''), NULLIF(ad.dir, ''), NULLIF(ad.apt, '')), ''),
               NULLIF(ad.city, ''),
               NULLIF(CONCAT_WS(' ', NULLIF(ad.state, ''), NULLIF(ad.zip, '')), '')) AS addressLine
    FROM HouseholdLocation hl
    JOIN [Address] ad ON ad.addressID = hl.addressID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       hm.householdID AS [Household ID],
       CASE WHEN ISNULL(hm.secondary, 0) = 0 THEN 'Primary' ELSE 'Secondary' END AS [Household],
       CASE WHEN n.physical = 1 THEN 'Physical' WHEN n.mailing = 1 THEN 'Mailing' ELSE 'Other' END AS [Address Type],
       CONVERT(date, n.startDate) AS [New Address Start], n.addressLine AS [New Address],
       old.addressLine AS [Old Address], CONVERT(date, old.endDate) AS [Old Address End]
FROM act a
JOIN HouseholdMember hm ON hm.personID = a.personID
                        AND (hm.startDate IS NULL OR hm.startDate <= @asOf)
                        AND (hm.endDate   IS NULL OR hm.endDate   >= @asOf)
JOIN loc n        ON n.householdID = hm.householdID AND n.startDate >= @sinceDate
JOIN Person p     ON p.personID    = a.personID
JOIN [Identity] i ON i.identityID  = p.currentIdentityID
OUTER APPLY (
    SELECT TOP 1 o.addressLine, o.endDate
    FROM loc o
    WHERE o.householdID = n.householdID
      AND o.addressID <> n.addressID
      AND (o.startDate IS NULL OR o.startDate < n.startDate)
    ORDER BY CASE WHEN o.physical = n.physical THEN 0 ELSE 1 END, o.startDate DESC, o.locationID DESC
) old
WHERE a.rn = 1
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName, n.startDate;
