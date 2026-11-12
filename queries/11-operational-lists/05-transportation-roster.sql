/* ======================================================================================
   #122  Transportation roster
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 2 · Run On request
   Purpose:   Active students with their bus number, stops and times and home address.
              Students with no transportation record are listed as a separate group. Used
              by the transportation office.
   Output:    One row per student per route type (one row for a student with no route):
              group, route type, route, bus number, pickup and dropoff stop and time,
              address
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity,
              TransportationRoute, TransportationBus, HouseholdMember, HouseholdLocation,
              Address
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Routes are almost never end-dated here, so the newest route per student per
              route type is shown; spot-check that old routes are not showing. The address
              is the student's primary household's current address, physical one first.
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
rt AS (   -- newest current route per student per route type
    SELECT tr.personID, tr.routeTypeCode, tr.routeName, b.number AS busNumber,
           tr.pickupLocation, tr.pickupTime, tr.dropoffLocation, tr.dropoffTime,
           ROW_NUMBER() OVER (PARTITION BY tr.personID, tr.routeTypeCode
                              ORDER BY tr.startDate DESC, tr.transportationRouteID DESC) AS rn
    FROM TransportationRoute tr
    LEFT JOIN TransportationBus b ON b.busID = tr.busID
    WHERE tr.startDate <= @asOf AND (tr.endDate IS NULL OR tr.endDate >= @asOf)
)
SELECT CASE WHEN rt.personID IS NULL THEN 'No transportation record' ELSE 'Has transportation' END AS [Group],
       p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       rt.routeTypeCode AS [Route Type], rt.routeName AS [Route], rt.busNumber AS [Bus Number],
       rt.pickupLocation AS [Pickup Stop], CONVERT(varchar(5), rt.pickupTime, 108) AS [Pickup Time],
       rt.dropoffLocation AS [Dropoff Stop], CONVERT(varchar(5), rt.dropoffTime, 108) AS [Dropoff Time],
       CONCAT_WS(' ', NULLIF(ad.number, ''), NULLIF(ad.prefix, ''), NULLIF(ad.street, ''),
                 NULLIF(ad.tag, ''), NULLIF(ad.dir, ''), NULLIF(ad.apt, '')) AS [Address],
       ad.city AS [City], ad.state AS [State], ad.zip AS [Zip]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN rt ON rt.personID = a.personID AND rt.rn = 1
OUTER APPLY (
    SELECT TOP 1 adr.number, adr.prefix, adr.street, adr.tag, adr.dir, adr.apt, adr.city, adr.state, adr.zip
    FROM HouseholdMember hm
    JOIN HouseholdLocation hl ON hl.householdID = hm.householdID
    JOIN [Address] adr        ON adr.addressID  = hl.addressID
    WHERE hm.personID = a.personID
      AND ISNULL(hm.secondary, 0) = 0
      AND (hm.endDate IS NULL OR hm.endDate >= @asOf)
      AND (hl.endDate IS NULL OR hl.endDate >= @asOf)
    ORDER BY ISNULL(hl.physical, 0) DESC, ISNULL(hl.secondary, 0), adr.addressID DESC
) ad
WHERE a.rn = 1
ORDER BY [Group], a.schoolName, rt.busNumber, rt.routeTypeCode, i.lastName, i.firstName;
