/* ======================================================================================
   #97  Bullying with no victim
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      Validation · Priority 2 · Run Monthly
   Purpose:   Bullying or harassment events with nobody in the victim role. CRDC counts
              the students who were bullied or harassed, so each of these needs a victim.
   Output:    One row per event: school, incident ID, event ID, incident date, event code,
              state event code, event type, bullying flag, offender count, issue
   Tables:    SchoolYear, BehaviorEvent, BehaviorIncident, BehaviorType, BehaviorRole,
              Calendar, School
   Params:    @endYear, @schoolID, @bullyPattern ('%bully%'), @harassPattern ('%harass%'),
              @offenderRoles, @victimRoles  (change them in the PARAMETERS block below)
   Check:     Bullying and harassment are found by the event's Bullying checkbox or by the
              event type name matching the two patterns; confirm against your event type
              list. The role names in @victimRoles and @offenderRoles must match your
              BehaviorRole.role values exactly.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int = NULL;               -- NULL = all schools
DECLARE @bullyPattern  varchar(30) = '%bully%';   -- event type names counted as bullying
DECLARE @harassPattern varchar(30) = '%harass%';  -- event type names counted as harassment
DECLARE @offenderRoles varchar(200) = 'Offender';  -- role names counted as the offender, comma-separated
DECLARE @victimRoles   varchar(200) = 'Victim';    -- role names counted as the victim, comma-separated
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       be.incidentID AS [Incident ID], be.eventID AS [Event ID],
       CONVERT(date, bi.timestamp) AS [Incident Date],
       bt.code AS [Event Code], bt.stateEventCode AS [State Event Code], bt.name AS [Event Type],
       CASE WHEN be.bullyingEvent = 1 THEN 'Y' ELSE 'N' END AS [Bullying Checkbox],
       (SELECT COUNT(*) FROM BehaviorRole o
        WHERE o.eventID = be.eventID
          AND o.role IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@offenderRoles, ','))) AS [Offenders],
       'Bullying or harassment event has no victim' AS [Issue]
FROM BehaviorEvent be
JOIN Calendar c ON c.calendarID = be.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
LEFT JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
LEFT JOIN BehaviorType     bt ON bt.typeID     = be.typeID
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (be.bullyingEvent = 1 OR bt.name LIKE @bullyPattern OR bt.name LIKE @harassPattern)
  AND NOT EXISTS (SELECT 1 FROM BehaviorRole v
                  WHERE v.eventID = be.eventID
                    AND v.role IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@victimRoles, ',')))
ORDER BY s.name, bi.timestamp, be.incidentID, be.eventID;
