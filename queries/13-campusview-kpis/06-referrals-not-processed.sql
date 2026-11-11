/* ======================================================================================
   #144  Referrals not processed
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      List · Run Weekly
   Purpose:   Lists this year's offender referrals that have no resolution and whose incident
              is not marked complete, oldest first.
   Output:    One row per offender per event: student, grade, incident ID, event ID,
              incident date, event type, incident status, days open
   Tables:    SchoolYear, BehaviorIncident, BehaviorEvent, BehaviorRole, BehaviorType,
              BehaviorResolution, Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @completeStatus (CM)  (change them in the
              PARAMETERS block below)
   Check:     Not complete means the incident status is blank or anything other than
              @completeStatus. Status codes are assumed to be DF draft, SB submitted, IP in
              progress, CM complete. The role name Offender must match your
              BehaviorRole.role values.
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

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year], g.grade AS [Grade],
       bi.incidentID AS [Incident ID], be.eventID AS [Event ID],
       CONVERT(date, bi.timestamp) AS [Incident Date],
       COALESCE(bt.name, '(no event type)') AS [Event Type],
       CASE bi.status WHEN 'DF' THEN 'Draft' WHEN 'SB' THEN 'Submitted'
                      WHEN 'IP' THEN 'In progress'
                      ELSE COALESCE(bi.status, '(no status)') END AS [Incident Status],
       DATEDIFF(day, bi.timestamp, @asOf) AS [Days Open]
FROM BehaviorEvent be
JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
JOIN BehaviorRole br     ON br.eventID = be.eventID AND br.role = 'Offender'
JOIN Calendar c          ON c.calendarID = be.calendarID
JOIN School   s          ON s.schoolID   = c.schoolID
LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
JOIN Person p     ON p.personID   = br.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade             -- latest enrollment in the event's calendar
             FROM Enrollment e
             WHERE e.personID = br.personID AND e.calendarID = be.calendarID
             ORDER BY e.startDate DESC) g
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND (bi.status IS NULL OR bi.status <> @completeStatus)
  AND NOT EXISTS (SELECT 1 FROM BehaviorResolution r WHERE r.roleID = br.roleID)
ORDER BY bi.timestamp, s.name, i.lastName, i.firstName;
