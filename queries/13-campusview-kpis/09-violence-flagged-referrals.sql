/* ======================================================================================
   #147  Violence-flagged referrals
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      List · Run Monthly
   Purpose:   Lists this year's behavior events flagged as violent, or whose event type
              carries one of the state event codes you list, with each offender's grade.
   Output:    One row per violent event per offender: incident ID, event ID, incident date,
              event type, state event code, offender grade, why it was flagged
   Tables:    SchoolYear, BehaviorEvent, BehaviorIncident, BehaviorRole, BehaviorType,
              Calendar, School, Enrollment
   Params:    @endYear, @schoolID, @violentCodes (blank)  (change them in the PARAMETERS
              block below)
   Check:     By default only events with the violence indicator ticked are listed; that box
              is not filled on older converted events. To add the state's violent offense
              codes, put the BehaviorType.stateEventCode values in @violentCodes. Offender
              names are left out on purpose. The role name Offender must match your
              BehaviorRole.role values.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int          = NULL;   -- NULL = all schools
DECLARE @violentCodes varchar(500) = '';     -- state event codes to treat as violent, comma-separated, e.g. 'A1,B2'; '' = none
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       bi.incidentID AS [Incident ID], be.eventID AS [Event ID],
       CONVERT(date, bi.timestamp) AS [Incident Date],
       COALESCE(bt.name, '(no event type)') AS [Event Type],
       bt.stateEventCode AS [State Event Code],
       g.grade AS [Offender Grade],
       CASE WHEN be.violenceIndicator = 1 THEN 'Violence indicator on the event'
            ELSE 'State event code in @violentCodes' END AS [Flagged By]
FROM BehaviorEvent be
JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
JOIN Calendar c          ON c.calendarID = be.calendarID
JOIN School   s          ON s.schoolID   = c.schoolID
LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
LEFT JOIN BehaviorRole br ON br.eventID = be.eventID AND br.role = 'Offender'
OUTER APPLY (SELECT TOP 1 e.grade             -- latest enrollment in the event's calendar
             FROM Enrollment e
             WHERE e.personID = br.personID AND e.calendarID = be.calendarID
             ORDER BY e.startDate DESC) g
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (be.violenceIndicator = 1
       OR bt.stateEventCode IN (SELECT LTRIM(RTRIM(v.value))
                                FROM STRING_SPLIT(@violentCodes, ',') v
                                WHERE LTRIM(RTRIM(v.value)) <> ''))
ORDER BY s.name, bi.timestamp DESC, bi.incidentID, be.eventID;
