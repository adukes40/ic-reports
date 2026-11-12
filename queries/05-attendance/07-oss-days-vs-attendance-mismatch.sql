/* ======================================================================================
   #59  OSS days vs. attendance mismatch
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      Validation · Priority 1 · Run Monthly
   Purpose:   Out-of-school suspension days with no OSS attendance code on that date, and
              OSS attendance codes on dates no suspension covers.
   Output:    One row per student per date: school, grade, date, issue
   Tables:    SchoolYear, Calendar, School, BehaviorResolution, BehaviorResType, Day,
              Attendance, AttendanceExcuse, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @ossNamePattern, @ossCodePattern, @yearStart
              (change them in the PARAMETERS block below)
   Check:     OSS resolutions are found by resolution type name LIKE @ossNamePattern or
              code LIKE @ossCodePattern; OSS attendance by attendance code description or
              code with the same two patterns. Confirm both against your resolution types
              and attendance codes. A suspension runs from the resolution start date
              through its end date, counting the end date as a suspended day; if your
              end date is the return date, the last day will be listed in error.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int  = NULL;   -- NULL = all schools
DECLARE @asOf           date = CONVERT(date, GETDATE());   -- check days through this date
DECLARE @ossNamePattern varchar(50) = '%out%school%';   -- matches resolution type name and attendance code description
DECLARE @ossCodePattern varchar(10) = 'OSS%';           -- matches resolution type code and attendance code
DECLARE @yearStart      date = (SELECT MIN(startDate) FROM Calendar WHERE endYear = @endYear AND exclude = 0 AND summerSchool = 0);   -- first day of the school year, from the calendars
-- ===========================================================================

WITH cal AS (   -- this year's calendars
    SELECT c.calendarID
    FROM Calendar c
    JOIN School s ON s.schoolID = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
susp AS (   -- OSS resolutions this year with their first and last day
    SELECT r.personID, r.calendarID,
           CONVERT(date, r.timestamp) AS firstDay,
           CONVERT(date, COALESCE(r.endDate, r.timestamp)) AS lastDay
    FROM BehaviorResolution r
    JOIN BehaviorResType rt ON rt.typeID = r.typeID
    JOIN cal ON cal.calendarID = r.calendarID
    WHERE (rt.name LIKE @ossNamePattern OR rt.code LIKE @ossCodePattern)
      AND r.timestamp < DATEADD(day, 1, @asOf)
),
suspDays AS (   -- each instructional day an OSS resolution covers, through @asOf
    SELECT DISTINCT su.personID, su.calendarID, d.date
    FROM susp su
    JOIN Day d ON d.calendarID = su.calendarID
              AND d.instruction = 1 AND d.attendance = 1
              AND d.date >= su.firstDay AND d.date <= su.lastDay AND d.date <= @asOf
),
ossAtt AS (   -- each student day with an OSS-coded attendance row
    SELECT DISTINCT a.personID, a.calendarID, a.date
    FROM AttendanceExcuse x
    JOIN cal ON cal.calendarID = x.calendarID
    JOIN Attendance a ON a.excuseID = x.excuseID AND a.calendarID = x.calendarID
    WHERE (x.description LIKE @ossNamePattern OR x.code LIKE @ossCodePattern)
      AND a.date >= @yearStart AND a.date <= @asOf
),
problems AS (   -- suspension days with no OSS attendance, then OSS attendance with no suspension
    SELECT sd.personID, sd.calendarID, sd.date,
           'Suspension day with no OSS attendance code' AS issue
    FROM suspDays sd
    WHERE NOT EXISTS (SELECT 1 FROM ossAtt o
                      WHERE o.personID = sd.personID AND o.date = sd.date)

    UNION ALL

    SELECT o.personID, o.calendarID, o.date,
           'OSS attendance code with no suspension covering the date'
    FROM ossAtt o
    WHERE NOT EXISTS (SELECT 1 FROM susp su
                      WHERE su.personID = o.personID
                        AND o.date >= su.firstDay AND o.date <= su.lastDay)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       CONVERT(date, pr.date) AS [Date],
       pr.issue AS [Issue]
FROM problems pr
JOIN Calendar c ON c.calendarID = pr.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = pr.personID AND e.calendarID = pr.calendarID
             ORDER BY e.startDate DESC) g
ORDER BY s.name, i.lastName, i.firstName, pr.date;
