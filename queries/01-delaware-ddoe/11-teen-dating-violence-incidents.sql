/* ======================================================================================
   #11  Teen dating violence / sexual assault incidents
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      List · Priority 2 · Run EOY
   Purpose:   This year's events whose type maps to teen dating violence or sexual assault,
              with role counts only, for the Reg 601 TDV report.
   Output:    One row per event: school, date, codes, type, location, offender / victim /
              participant counts, police notified
   Tables:    Calendar, School, BehaviorEvent, BehaviorIncident, BehaviorType, BehaviorRole
   Params:    @endYear, @schoolID, @codes (edit the list)  (change them in the PARAMETERS
              block below)
   Check:     The code list holds placeholders (TDV, SXA, SXO). Put in your real event codes
              before running.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- Codes: edit this list (local BehaviorType.code or stateEventCode)
DECLARE @codes TABLE (code varchar(30));
INSERT INTO @codes VALUES ('TDV'), ('SXA'), ('SXO');   -- placeholders; replace with real codes
-- ===========================================================================

SELECT c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       be.eventID AS [Event ID], CONVERT(date, bi.timestamp) AS [Event Date],
       bt.code AS [Event Code], bt.stateEventCode AS [State Event Code], bt.name AS [Event Type],
       bi.location AS [Location],
       SUM(CASE WHEN br.role = 'Offender'    THEN 1 ELSE 0 END) AS [Offenders],
       SUM(CASE WHEN br.role = 'Victim'      THEN 1 ELSE 0 END) AS [Victims],
       SUM(CASE WHEN br.role = 'Participant' THEN 1 ELSE 0 END) AS [Participants],
       SUM(CASE WHEN br.role NOT IN ('Offender', 'Victim', 'Participant') OR br.role IS NULL
                THEN 1 ELSE 0 END) AS [Other Roles],
       MAX(CAST(be.policeNotified AS int)) AS [Police Notified]
FROM BehaviorEvent be
JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID   -- date and location are on the incident
JOIN BehaviorType bt ON bt.typeID = be.typeID
JOIN Calendar c ON c.calendarID = be.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
LEFT JOIN BehaviorRole br ON br.eventID = be.eventID
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (bt.code IN (SELECT code FROM @codes)
       OR bt.stateEventCode IN (SELECT code FROM @codes)
       OR bt.name LIKE '%dating%' OR bt.name LIKE '%sexual assault%')
GROUP BY c.schoolID, s.name, c.endYear, be.eventID, bi.timestamp,
         bt.code, bt.stateEventCode, bt.name, bi.location
ORDER BY s.name, bi.timestamp;
