/* ======================================================================================
   #99  Open referrals by age
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      List · Priority 1 · Run Daily
   Purpose:   This year's behavior incidents that are not marked complete, with the number
              of days since the incident and an age bucket, oldest first.
   Output:    One row per incident: school, incident ID, title, incident date, referral
              date, status, submitted by, event types, offender count, days open, age
              bucket
   Tables:    SchoolYear, BehaviorIncident, BehaviorEvent, BehaviorType, BehaviorRole,
              Calendar, School, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @completeStatus ('CM')  (change them in the
              PARAMETERS block below)
   Check:     Complete is assumed to be stored as 'CM' in BehaviorIncident.status (IC's
              standard: DF draft, SB submitted, IP in progress, CM complete). A blank status
              counts as open. Days are calendar days, not school days.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int  = NULL;   -- NULL = all schools
DECLARE @asOf           date = CONVERT(date, GETDATE());
DECLARE @completeStatus varchar(6) = 'CM';   -- status code that means complete
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       bi.incidentID AS [Incident ID], bi.title AS [Incident Title],
       CONVERT(date, bi.timestamp) AS [Incident Date],
       CONVERT(date, bi.referralTimestamp) AS [Referral Date],
       COALESCE(bi.status, '(blank)') AS [Status],
       ri.lastName + ', ' + ri.firstName AS [Submitted By],
       ev.eventTypes AS [Event Types],
       (SELECT COUNT(DISTINCT br.personID)
        FROM BehaviorEvent be
        JOIN BehaviorRole br ON br.eventID = be.eventID
        WHERE be.incidentID = bi.incidentID AND br.role = 'Offender') AS [Offenders],
       d.daysOpen AS [Days Open],
       CASE WHEN d.daysOpen <= 2  THEN '0-2 days'
            WHEN d.daysOpen <= 5  THEN '3-5 days'
            WHEN d.daysOpen <= 10 THEN '6-10 days'
            ELSE 'Over 10 days' END AS [Age Bucket]
FROM BehaviorIncident bi
JOIN Calendar c ON c.calendarID = bi.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
LEFT JOIN Person rp     ON rp.personID   = bi.referralPersonID
LEFT JOIN [Identity] ri ON ri.identityID = rp.currentIdentityID
CROSS APPLY (SELECT DATEDIFF(day, bi.timestamp, @asOf) AS daysOpen) d
OUTER APPLY (SELECT STRING_AGG(CAST(t.name AS varchar(max)), ', ') WITHIN GROUP (ORDER BY t.name) AS eventTypes
             FROM (SELECT DISTINCT bt.name
                   FROM BehaviorEvent be
                   JOIN BehaviorType bt ON bt.typeID = be.typeID
                   WHERE be.incidentID = bi.incidentID) t) ev
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (bi.status IS NULL OR bi.status <> @completeStatus)
  AND bi.timestamp < DATEADD(day, 1, @asOf)
ORDER BY d.daysOpen DESC, s.name, bi.incidentID;
