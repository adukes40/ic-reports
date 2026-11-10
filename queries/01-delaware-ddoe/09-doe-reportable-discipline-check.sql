/* ======================================================================================
   #9  DOE-reportable discipline check
   --------------------------------------------------------------------------------------
   Status:    Broken
   Category:  Delaware DOE
   Type:      Validation · Priority 1 · Run Monthly
   Purpose:   On state-coded behavior events: offenders with no resolution, suspensions
              missing start, end or length, and offenders missing gender, race or grade.
   Output:    One row per problem: student, school, grade, event, date, type, state code,
              resolution, issue
   Tables:    Calendar, School, BehaviorEvent, BehaviorType, BehaviorRole,
              BehaviorResolution, BehaviorResType, Enrollment, Person, Identity
   Params:    @startDate (July 1), @endDate (today), @schoolID, @suspPattern ('%susp%')
              (change them in the PARAMETERS block below)
   Check:     Offender is matched as role = 'Offender', and suspensions by resolution name
              or state code. Confirm both against your codes.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @startDate   date = DATEFROMPARTS((SELECT TOP 1 startYear FROM SchoolYear WHERE active = 1), 7, 1);
DECLARE @endDate     date = CONVERT(date, GETDATE());
DECLARE @schoolID    int  = NULL;          -- NULL = all schools
DECLARE @suspPattern varchar(30) = '%susp%';
-- ===========================================================================

WITH ev AS (
    SELECT be.eventID, be.calendarID, be.timestamp, bt.name AS eventType, bt.stateEventCode,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM BehaviorEvent be
    JOIN BehaviorType bt ON bt.typeID = be.typeID
    JOIN Calendar c ON c.calendarID = be.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE be.timestamp >= @startDate AND be.timestamp < DATEADD(day, 1, @endDate)
      AND NULLIF(LTRIM(RTRIM(bt.stateEventCode)), '') IS NOT NULL
      AND c.exclude = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
off AS (
    SELECT ev.*, br.roleID, br.personID
    FROM ev
    JOIN BehaviorRole br ON br.eventID = ev.eventID
    WHERE br.role = 'Offender'
),
problems AS (
    SELECT o.personID, o.eventID, o.calendarID, o.timestamp, o.eventType, o.stateEventCode,
           NULL AS resolution, 'Offender has no resolution' AS issue
    FROM off o
    WHERE NOT EXISTS (SELECT 1 FROM BehaviorResolution r WHERE r.roleID = o.roleID)

    UNION ALL

    SELECT o.personID, o.eventID, o.calendarID, o.timestamp, o.eventType, o.stateEventCode,
           rt.name,
           CASE WHEN r.timestamp IS NULL THEN 'Suspension has no start date'
                WHEN r.endDate   IS NULL THEN 'Suspension has no end date'
                ELSE 'Suspension has no length' END
    FROM off o
    JOIN BehaviorResolution r ON r.roleID = o.roleID
    JOIN BehaviorResType rt   ON rt.typeID = r.typeID
    WHERE (rt.name LIKE @suspPattern OR rt.stateResCode LIKE @suspPattern)
      AND (r.timestamp IS NULL OR r.endDate IS NULL
           OR COALESCE(r.daysOverride, r.schoolDaysDuration, r.duration) IS NULL)

    UNION ALL

    SELECT o.personID, o.eventID, o.calendarID, o.timestamp, o.eventType, o.stateEventCode,
           NULL, x.issue
    FROM off o
    JOIN Person p ON p.personID = o.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
                 WHERE e.personID = o.personID AND e.calendarID = o.calendarID
                 ORDER BY e.startDate DESC) g
    CROSS APPLY (VALUES
        (CASE WHEN NULLIF(LTRIM(RTRIM(i.gender)), '') IS NULL THEN 'Offender missing gender' END),
        (CASE WHEN NULLIF(LTRIM(RTRIM(i.raceEthnicity)), '') IS NULL
               AND NULLIF(LTRIM(RTRIM(i.raceEthnicityFed)), '') IS NULL THEN 'Offender missing race/ethnicity' END),
        (CASE WHEN NULLIF(LTRIM(RTRIM(g.grade)), '') IS NULL THEN 'Offender has no grade (no enrollment in event calendar)' END)
    ) x(issue)
    WHERE x.issue IS NOT NULL
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       pr.eventID AS [Event ID], CONVERT(date, pr.timestamp) AS [Event Date], pr.eventType AS [Event Type], pr.stateEventCode AS [State Event Code],
       pr.resolution AS [Resolution], pr.issue AS [Issue]
FROM problems pr
JOIN Calendar c ON c.calendarID = pr.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = pr.personID AND e.calendarID = pr.calendarID
             ORDER BY e.startDate DESC) g
ORDER BY s.name, pr.timestamp, i.lastName;
