/* ======================================================================================
   #143  Open referrals with age buckets
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      List · Run Weekly
   Purpose:   Lists this year's behavior incidents that are not marked complete, with the
              days open since the incident date and an age bucket.
   Output:    One row per open incident: incident ID, date, title, status, location, event
              types, number of offenders, days open, age bucket
   Tables:    SchoolYear, BehaviorIncident, BehaviorEvent, BehaviorRole, BehaviorType,
              Calendar, School, CampusAttribute, CampusDictionary
   Params:    @endYear, @schoolID, @asOf, @completeStatus (CM)  (change them in the
              PARAMETERS block below)
   Check:     Open means the incident status is blank or anything other than
              @completeStatus, so drafts are included. Status codes are assumed to be DF
              draft, SB submitted, IP in progress, CM complete. The role name Offender must
              match your BehaviorRole.role values.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int        = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int        = NULL;   -- NULL = all schools
DECLARE @asOf           date       = CONVERT(date, GETDATE());   -- days open are counted to this date
DECLARE @completeStatus varchar(6) = 'CM';   -- incident status code that means complete
-- ===========================================================================

WITH inc AS (   -- this year's incidents that are not complete
    SELECT bi.incidentID, bi.timestamp, bi.title, bi.status, bi.location,
           c.schoolID, s.name AS schoolName, c.endYear,
           DATEDIFF(day, bi.timestamp, @asOf) AS daysOpen
    FROM BehaviorIncident bi
    JOIN Calendar c ON c.calendarID = bi.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND (bi.status IS NULL OR bi.status <> @completeStatus)
)
SELECT inc.schoolID AS [School ID], inc.schoolName AS [School], inc.endYear AS [School Year],
       inc.incidentID AS [Incident ID], CONVERT(date, inc.timestamp) AS [Incident Date],
       inc.title AS [Title],
       CASE inc.status WHEN 'DF' THEN 'Draft' WHEN 'SB' THEN 'Submitted'
                       WHEN 'IP' THEN 'In progress'
                       ELSE ISNULL(inc.status, '(no status)') END AS [Incident Status],
       COALESCE(loc.name, NULLIF(inc.location, ''), '(no location)') AS [Location],
       ev.eventTypes AS [Event Types], ISNULL(off.offenders, 0) AS [Offenders],
       inc.daysOpen AS [Days Open],
       CASE WHEN inc.daysOpen <= 2  THEN '0 to 2 days'
            WHEN inc.daysOpen <= 5  THEN '3 to 5 days'
            WHEN inc.daysOpen <= 10 THEN '6 to 10 days'
            ELSE 'Over 10 days' END AS [Age Bucket]
FROM inc
OUTER APPLY (SELECT MAX(d.name) AS name           -- location name from the dictionary
             FROM CampusAttribute ca
             JOIN CampusDictionary d ON d.attributeID = ca.attributeID
             WHERE ca.object = 'BehaviorIncident' AND ca.element = 'location'
               AND d.code = inc.location) loc
OUTER APPLY (SELECT STRING_AGG(CAST(t.name AS varchar(max)), ', ') AS eventTypes   -- event types on the incident
             FROM (SELECT DISTINCT COALESCE(bt.name, '(no event type)') AS name
                   FROM BehaviorEvent be
                   LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
                   WHERE be.incidentID = inc.incidentID) t) ev
OUTER APPLY (SELECT COUNT(DISTINCT br.personID) AS offenders
             FROM BehaviorEvent be
             JOIN BehaviorRole br ON br.eventID = be.eventID AND br.role = 'Offender'
             WHERE be.incidentID = inc.incidentID) off
ORDER BY inc.schoolName, inc.daysOpen DESC, inc.incidentID;
