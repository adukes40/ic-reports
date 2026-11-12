/* ======================================================================================
   #142  Referrals by type, location, status
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      KPI · Run Monthly
   Purpose:   Counts this year's offender referrals by event type, incident location and
              incident status. Incidents with no status get their own bucket and count as
              open.
   Output:    One row per school per event type per location per status: open or complete,
              referrals, distinct students
   Tables:    SchoolYear, BehaviorIncident, BehaviorEvent, BehaviorRole, BehaviorType,
              Calendar, School, CampusAttribute, CampusDictionary
   Params:    @endYear, @schoolID, @completeStatus (CM), @offenderRoles  (change them in
              the PARAMETERS block below)
   Check:     A referral is one student in one of the @offenderRoles roles on one event;
              the role names must match your BehaviorRole.role values. Status codes are
              assumed to be DF draft, SB submitted, IP in progress, CM complete; any other
              code shows as is. Location shows the raw code if it is not in the
              BehaviorIncident location dictionary.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int        = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int        = NULL;   -- NULL = all schools
DECLARE @completeStatus varchar(6) = 'CM';   -- incident status code that means complete
DECLARE @offenderRoles  varchar(200) = 'Offender';   -- role names counted as the offender, comma-separated
-- ===========================================================================

WITH ref AS (   -- one row per offender per event this year
    SELECT c.schoolID, s.name AS schoolName, c.endYear, br.personID,
           COALESCE(bt.name, '(no event type)') AS eventType,
           COALESCE(loc.name, NULLIF(bi.location, ''), '(no location)') AS location,
           CASE bi.status WHEN 'DF' THEN 'Draft' WHEN 'SB' THEN 'Submitted'
                          WHEN 'IP' THEN 'In progress' WHEN 'CM' THEN 'Complete'
                          ELSE COALESCE(bi.status, '(no status)') END AS incidentStatus,
           CASE WHEN bi.status IS NULL OR bi.status <> @completeStatus THEN 'Open' ELSE 'Complete' END AS openOrComplete
    FROM BehaviorEvent be
    JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
    JOIN BehaviorRole br     ON br.eventID = be.eventID
                            AND br.role IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@offenderRoles, ','))
    JOIN Calendar c          ON c.calendarID = be.calendarID
    JOIN School   s          ON s.schoolID   = c.schoolID
    LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
    OUTER APPLY (SELECT MAX(d.name) AS name       -- location name from the dictionary
                 FROM CampusAttribute ca
                 JOIN CampusDictionary d ON d.attributeID = ca.attributeID
                 WHERE ca.object = 'BehaviorIncident' AND ca.element = 'location'
                   AND d.code = bi.location) loc
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT schoolID AS [School ID], schoolName AS [School], endYear AS [School Year],
       eventType AS [Event Type], location AS [Location],
       incidentStatus AS [Incident Status], openOrComplete AS [Open or Complete],
       COUNT(*) AS [Referrals], COUNT(DISTINCT personID) AS [Students]
FROM ref
GROUP BY schoolID, schoolName, endYear, eventType, location, incidentStatus, openOrComplete
ORDER BY schoolName, [Referrals] DESC, eventType, location;
