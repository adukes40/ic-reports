/* ======================================================================================
   #1  Unit count readiness
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Delaware DOE
   Type:      Validation · Priority 1 · Run Sept
   Purpose:   Two unit-count problems in the last 10 instructional days of September:
              enrolled but never present, and attendance on a day with no primary
              enrollment.
   Output:    One row per problem: student, school, grade, SPED status, EL, window days
              enrolled and present, issue
   Tables:    Calendar, School, Day, Enrollment, v_AttDayDetail_Exact, Attendance, Lep,
              Person, Identity
   Params:    @endYear (active year), @schoolID (NULL = all)  (change them in the PARAMETERS
              block below)
   Check:     Present days = window days enrolled minus full-day absences from
              v_AttDayDetail_Exact. Confirm the window matches DDOE's 10 days for each
              calendar.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH cal AS (
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear
    FROM Calendar c
    JOIN School s ON s.schoolID = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
sepDays AS (   -- instructional September days, newest first, per calendar/structure
    SELECT d.calendarID, d.structureID, d.date,
           ROW_NUMBER() OVER (PARTITION BY d.calendarID, d.structureID ORDER BY d.date DESC) AS rn
    FROM Day d
    JOIN cal ON cal.calendarID = d.calendarID
    WHERE d.instruction = 1 AND d.attendance = 1
      AND MONTH(d.date) = 9 AND YEAR(d.date) = @endYear - 1
),
win AS (SELECT calendarID, structureID, date FROM sepDays WHERE rn <= 10),
winRange AS (
    SELECT calendarID, structureID, MIN(date) AS winStart, MAX(date) AS winEnd
    FROM win GROUP BY calendarID, structureID
),
enr AS (
    SELECT e.enrollmentID, e.personID, e.calendarID, e.structureID, e.grade,
           e.specialEdStatus, e.startDate, e.endDate
    FROM Enrollment e
    JOIN winRange w ON w.calendarID = e.calendarID AND w.structureID = e.structureID
    WHERE e.serviceType = 'P'
      AND e.stateExclude = 0
      AND e.startDate <= w.winEnd
      AND (e.endDate IS NULL OR e.endDate >= w.winStart)
),
enrDays AS (   -- window days each enrollment covers, and full-day absences on them
    SELECT e.enrollmentID,
           COUNT(*)                          AS daysEnrolled,
           SUM(ISNULL(a.absentDay, 0))       AS daysAbsent
    FROM enr e
    JOIN win w ON w.calendarID = e.calendarID AND w.structureID = e.structureID
              AND w.date >= e.startDate
              AND (e.endDate IS NULL OR w.date <= e.endDate)
    LEFT JOIN v_AttDayDetail_Exact a
           ON a.personID = e.personID AND a.calendarID = e.calendarID AND a.date = w.date
    GROUP BY e.enrollmentID
),
problems AS (
    -- 1. Enrolled in the window, never present
    SELECT e.personID, e.calendarID, e.grade, e.specialEdStatus,
           d.daysEnrolled, d.daysEnrolled - d.daysAbsent AS daysPresent,
           'Enrolled in count window but no day present' AS issue
    FROM enr e
    JOIN enrDays d ON d.enrollmentID = e.enrollmentID
    WHERE d.daysEnrolled - d.daysAbsent <= 0

    UNION ALL

    -- 2. Attendance on a window day with no primary enrollment covering it
    SELECT DISTINCT at.personID, at.calendarID, NULL, NULL, NULL, NULL,
           'Attendance recorded in count window with no primary enrollment on that date'
    FROM Attendance at
    JOIN (SELECT DISTINCT calendarID, date FROM win) w
      ON w.calendarID = at.calendarID AND w.date = at.date
    WHERE NOT EXISTS (
        SELECT 1 FROM Enrollment e2
        WHERE e2.personID = at.personID AND e2.calendarID = at.calendarID
          AND e2.serviceType = 'P'
          AND e2.startDate <= at.date
          AND (e2.endDate IS NULL OR e2.endDate >= at.date))
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       cal.schoolID AS [School ID], cal.schoolName AS [School], cal.endYear AS [School Year],
       pr.grade AS [Grade],
       pr.specialEdStatus AS [Special Ed Status],
       CASE WHEN EXISTS (SELECT 1 FROM Lep l
                         WHERE l.personID = pr.personID AND l.programStatus = 'LEP'
                           AND (l.exitDate IS NULL OR l.exitDate >= DATEFROMPARTS(@endYear - 1, 9, 1)))
            THEN 'Y' ELSE 'N' END AS [EL],
       pr.daysEnrolled AS [Days Enrolled in Window],
       pr.daysPresent  AS [Days Present in Window],
       pr.issue AS [Issue]
FROM problems pr
JOIN cal ON cal.calendarID = pr.calendarID
JOIN Person p ON p.personID = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY cal.schoolName, pr.issue, i.lastName, i.firstName;
