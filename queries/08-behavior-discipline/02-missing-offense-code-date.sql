/* ======================================================================================
   #94  Missing offense, code or date
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      Validation · Priority 1 · Run Weekly
   Purpose:   This year's behavior incidents with no event (offense) recorded, an event with
              no event type, a type that is not in the event type list or has no code, or
              no incident date.
   Output:    One row per problem: school, incident ID, title, date, status, event ID, event
              code, event type, issue
   Tables:    SchoolYear, BehaviorIncident, BehaviorEvent, BehaviorType, Calendar, School
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     The date checked is the incident's date (BehaviorIncident); this district does
              not fill the event-level date. Draft referrals can show up as incidents with
              no event; the Status column tells you which those are.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH inc AS (   -- this year's incidents with their events; an incident with no event has a NULL eventID
    SELECT bi.incidentID, bi.title, bi.timestamp AS incidentDate, bi.status,
           c.schoolID, s.name AS schoolName, c.endYear,
           be.eventID, be.typeID, bt.typeID AS listTypeID, bt.code AS eventCode, bt.name AS eventType
    FROM BehaviorIncident bi
    JOIN Calendar c ON c.calendarID = bi.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    LEFT JOIN BehaviorEvent be ON be.incidentID = bi.incidentID
    LEFT JOIN BehaviorType  bt ON bt.typeID     = be.typeID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT inc.schoolID AS [School ID], inc.schoolName AS [School], inc.endYear AS [School Year],
       inc.incidentID AS [Incident ID], inc.title AS [Incident Title],
       CONVERT(date, inc.incidentDate) AS [Incident Date], inc.status AS [Status],
       inc.eventID AS [Event ID], inc.eventCode AS [Event Code], inc.eventType AS [Event Type],
       x.issue AS [Issue]
FROM inc
CROSS APPLY (VALUES
    (CASE WHEN inc.eventID IS NULL THEN 'Incident has no event (no offense recorded)' END),
    (CASE WHEN inc.eventID IS NOT NULL AND inc.typeID IS NULL THEN 'Event has no event type' END),
    (CASE WHEN inc.typeID IS NOT NULL AND inc.listTypeID IS NULL
          THEN 'Event type ID ' + CAST(inc.typeID AS varchar(12)) + ' is not in the event type list' END),
    (CASE WHEN inc.listTypeID IS NOT NULL AND NULLIF(LTRIM(RTRIM(inc.eventCode)), '') IS NULL
          THEN 'Event type has no code' END),
    (CASE WHEN inc.incidentDate IS NULL THEN 'Incident has no date' END)
) x(issue)
WHERE x.issue IS NOT NULL
ORDER BY inc.schoolName, inc.incidentID, inc.eventID;
