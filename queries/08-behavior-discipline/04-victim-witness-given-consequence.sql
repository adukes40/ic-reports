/* ======================================================================================
   #96  Victim or witness given a consequence
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      Validation · Priority 2 · Run Monthly
   Purpose:   Resolutions attached to a person whose role on the event is victim, witness or
              reporter rather than offender. Usually the resolution was added to the wrong
              person.
   Output:    One row per resolution: student, school, grade, incident ID, event ID,
              incident date, event type, role, resolution, resolution date, issue
   Tables:    SchoolYear, BehaviorResolution, BehaviorResType, BehaviorRole, BehaviorEvent,
              BehaviorIncident, BehaviorType, Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Role names in the IN (...) list must match your BehaviorRole.role values
              exactly; Reporter is not a standard IC role and is there in case you use it.
              Names are shown because this is a fix-it list; do not share it further.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       be.incidentID AS [Incident ID], be.eventID AS [Event ID],
       CONVERT(date, bi.timestamp) AS [Incident Date], bt.name AS [Event Type],
       br.role AS [Role],
       COALESCE(rt.name, r.name) AS [Resolution], CONVERT(date, r.timestamp) AS [Resolution Date],
       br.role + ' has a resolution' AS [Issue]
FROM BehaviorResolution r
JOIN BehaviorRole  br ON br.roleID  = r.roleID
JOIN BehaviorEvent be ON be.eventID = br.eventID
JOIN Calendar c ON c.calendarID = be.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = br.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN BehaviorIncident bi ON bi.incidentID = be.incidentID
LEFT JOIN BehaviorType     bt ON bt.typeID     = be.typeID
LEFT JOIN BehaviorResType  rt ON rt.typeID     = r.typeID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = br.personID AND e.calendarID = be.calendarID
             ORDER BY e.startDate DESC) g
WHERE br.role IN ('Victim', 'Witness', 'Reporter')   -- roles that should never get a resolution
  AND c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
ORDER BY s.name, bi.timestamp, be.incidentID, i.lastName, i.firstName;
