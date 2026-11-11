/* ======================================================================================
   #103  Referrals by location, time and type
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      KPI · Priority 2 · Run Monthly
   Purpose:   Where and when behavior incidents happen: incident counts per school by
              location, hour of day, weekday and event type over a date range.
   Output:    One row per school per breakdown value: breakdown (Location, Hour of day,
              Weekday, Event type), value, incidents, total incidents at the school, percent
              of the school's incidents
   Tables:    SchoolYear, BehaviorIncident, BehaviorEvent, BehaviorType, Calendar, School,
              CampusAttribute, CampusDictionary
   Params:    @startDate (July 1), @endDate (today), @schoolID  (change them in the
              PARAMETERS block below)
   Check:     Date, time and location come from the incident (BehaviorIncident). An incident
              saved without a time shows under 00:00. Location shows the dictionary name
              when one is found for BehaviorIncident.location, otherwise the stored code. An
              incident with two event types counts once under each, so the Event type rows
              can add up to more than the total.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @startDate date = DATEFROMPARTS((SELECT TOP 1 startYear FROM SchoolYear WHERE active = 1), 7, 1);
DECLARE @endDate   date = CONVERT(date, GETDATE());
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
-- ===========================================================================

WITH inc AS (   -- one row per incident in the date range
    SELECT bi.incidentID, c.schoolID, s.name AS schoolName, c.endYear, bi.timestamp,
           COALESCE(loc.name, NULLIF(LTRIM(RTRIM(bi.location)), ''), '(blank)') AS location
    FROM BehaviorIncident bi
    JOIN Calendar c ON c.calendarID = bi.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    OUTER APPLY (SELECT TOP 1 cd.name
                 FROM CampusAttribute ca
                 JOIN CampusDictionary cd ON cd.attributeID = ca.attributeID
                 WHERE ca.object = 'BehaviorIncident' AND ca.element = 'location'
                   AND cd.code = bi.location
                 ORDER BY cd.active DESC, cd.dictionaryID) loc
    WHERE bi.timestamp >= @startDate AND bi.timestamp < DATEADD(day, 1, @endDate)
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
cuts AS (   -- each incident listed once under each breakdown value it falls in
    SELECT i.schoolID, i.schoolName, i.endYear, i.incidentID, x.cutOrder, x.breakdown, x.value, x.valueOrder
    FROM inc i
    CROSS APPLY (VALUES
        (1, 'Location',    i.location, 0),
        (2, 'Hour of day', RIGHT('0' + CAST(DATEPART(hour, i.timestamp) AS varchar(2)), 2) + ':00',
                           DATEPART(hour, i.timestamp)),
        (3, 'Weekday',     DATENAME(weekday, i.timestamp),
                           (DATEPART(weekday, i.timestamp) + @@DATEFIRST + 5) % 7)   -- Monday first
    ) x(cutOrder, breakdown, value, valueOrder)

    UNION ALL

    SELECT i.schoolID, i.schoolName, i.endYear, i.incidentID, 4, 'Event type',
           COALESCE(bt.name, '(no event type)'), 0
    FROM inc i
    JOIN BehaviorEvent be ON be.incidentID = i.incidentID
    LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
),
tot AS (   -- total incidents per school and year, the denominator
    SELECT schoolID, endYear, COUNT(*) AS totalIncidents
    FROM inc
    GROUP BY schoolID, endYear
)
SELECT k.schoolID AS [School ID], k.schoolName AS [School], k.endYear AS [School Year],
       k.breakdown AS [Breakdown], k.value AS [Value],
       COUNT(DISTINCT k.incidentID) AS [Incidents],
       t.totalIncidents AS [Total Incidents],
       CAST(100.0 * COUNT(DISTINCT k.incidentID) / NULLIF(t.totalIncidents, 0) AS decimal(5,1)) AS [% of Incidents]
FROM cuts k
JOIN tot t ON t.schoolID = k.schoolID AND t.endYear = k.endYear
GROUP BY k.schoolID, k.schoolName, k.endYear, k.cutOrder, k.breakdown, k.value, k.valueOrder, t.totalIncidents
ORDER BY k.schoolName, k.endYear, k.cutOrder, k.valueOrder, COUNT(DISTINCT k.incidentID) DESC, k.value;
