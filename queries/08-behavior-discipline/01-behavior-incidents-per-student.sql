/* ======================================================================================
   #100  Behavior incidents per student, by type
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Behavior & discipline
   Type:      List · Priority 1 · Run Weekly
   Purpose:   Per student, how many behavior events they were in this year as offender or
              participant, with a breakdown by event type. Filter Total Events to 2 or more
              for repeat referrals.
   Output:    One row per student per school: grade, school, year, total events, breakdown
              like Disruption (3), Fighting (1)
   Tables:    SchoolYear, BehaviorEvent, BehaviorRole, BehaviorType, Calendar, School,
              Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @schoolName (partial match), @countedRoles  (change them
              in the PARAMETERS block below)
   Check:     @countedRoles must match your BehaviorRole.role values exactly. A student in two
              roles on the same event counts once. A student with events at two schools gets
              a row for each. Adapted from a query by Matthew Prins (2026).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

SET NOCOUNT ON;   -- stops row-count messages from hiding the results in the extract
-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int          = NULL;   -- NULL = all schools
DECLARE @schoolName varchar(100) = '';     -- partial school name, e.g. 'Washington'; '' = all
DECLARE @countedRoles varchar(200) = 'Offender,Participant';   -- role names to count, comma-separated
-- ===========================================================================

WITH studentEvents AS (   -- one row per student per event
    SELECT br.personID, be.eventID,
           c.schoolID, s.name AS schoolName, c.endYear,
           COALESCE(bt.name, '(no event type)') AS eventType
    FROM BehaviorEvent be
    JOIN BehaviorRole br ON br.eventID = be.eventID
    JOIN Calendar c      ON c.calendarID = be.calendarID
    JOIN School   s      ON s.schoolID   = c.schoolID
    LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
    WHERE br.role IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@countedRoles, ','))   -- roles to count
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND s.name LIKE '%' + @schoolName + '%'
    GROUP BY br.personID, be.eventID, c.schoolID, s.name, c.endYear, COALESCE(bt.name, '(no event type)')
),
typeCounts AS (
    SELECT personID, schoolID, schoolName, endYear, eventType, COUNT(*) AS eventCount
    FROM studentEvents
    GROUP BY personID, schoolID, schoolName, endYear, eventType
),
perStudent AS (
    SELECT personID, schoolID, schoolName, endYear,
           SUM(eventCount) AS totalEvents,
           STRING_AGG(CAST(eventType + ' (' + CAST(eventCount AS varchar(10)) + ')' AS varchar(max)), ', ')
               WITHIN GROUP (ORDER BY eventCount DESC, eventType) AS eventBreakdown
    FROM typeCounts
    GROUP BY personID, schoolID, schoolName, endYear
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       ps.schoolID AS [School ID], ps.schoolName AS [School], ps.endYear AS [School Year], g.grade AS [Grade],
       ps.totalEvents AS [Total Events], ps.eventBreakdown AS [Event Breakdown]
FROM perStudent ps
JOIN Person p     ON p.personID   = ps.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade             -- latest enrollment at that school this year
             FROM Enrollment e
             JOIN Calendar ec ON ec.calendarID = e.calendarID
             WHERE e.personID = ps.personID
               AND ec.schoolID = ps.schoolID AND ec.endYear = ps.endYear
             ORDER BY e.startDate DESC) g
ORDER BY ps.totalEvents DESC, ps.schoolName, i.lastName, i.firstName;
