/* ======================================================================================
   #10  Behavior responses not synced
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      Validation · Priority 2 · Run Monthly
   Purpose:   Offender roles with no resolution more than @days days after the event; these
              show up as gaps in State Edition.
   Output:    One row per unresolved offender: school, grade, event, date, type, reported
              by, days open
   Tables:    Calendar, School, BehaviorEvent, BehaviorType, BehaviorRole,
              BehaviorResolution, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @days (5)  (change them in the PARAMETERS block below)
   Check:     Overlaps the first check in #9; this one adds the age of the gap.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @days     int = 5;      -- grace period after the event
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       be.eventID AS [Event ID], CONVERT(date, be.timestamp) AS [Event Date],
       bt.name AS [Event Type], bt.stateEventCode AS [State Event Code],
       be.staffName AS [Reported By],
       DATEDIFF(day, be.timestamp, GETDATE()) AS [Days Open],
       'Offender has no resolution after ' + CAST(@days AS varchar(5)) + ' days' AS [Issue]
FROM BehaviorEvent be
JOIN BehaviorRole br ON br.eventID = be.eventID AND br.role = 'Offender'
JOIN Calendar c ON c.calendarID = be.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
JOIN Person p ON p.personID = br.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = br.personID AND e.calendarID = be.calendarID
             ORDER BY e.startDate DESC) g
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND be.timestamp < DATEADD(day, -@days, GETDATE())
  AND NOT EXISTS (SELECT 1 FROM BehaviorResolution r WHERE r.roleID = br.roleID)
ORDER BY s.name, [Days Open] DESC;
