/* ======================================================================================
   #2  Unit count transfers
   --------------------------------------------------------------------------------------
   Status:    Needs review
   Category:  Delaware DOE
   Type:      List · Priority 1 · Run Sept
   Purpose:   Primary enrollments that started or ended inside the count window, with where
              the student came from or went.
   Output:    One row per moving enrollment: movement, window dates, start/end dates and
              status, prior school, next school, resident/serving district
   Tables:    Calendar, School, Day, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @lookbackDays (30, for the prior in-district school)
              (change them in the PARAMETERS block below)
   Check:     Prior school finds only in-district enrollments. Out-of-state or other-
              district senders show as blank.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @lookbackDays int = 30; -- how far back to look for the student's prior school
-- ===========================================================================

WITH cal AS (
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear
    FROM Calendar c
    JOIN School s ON s.schoolID = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
sepDays AS (
    SELECT d.calendarID, d.structureID, d.date,
           ROW_NUMBER() OVER (PARTITION BY d.calendarID, d.structureID ORDER BY d.date DESC) AS rn
    FROM Day d
    JOIN cal ON cal.calendarID = d.calendarID
    WHERE d.instruction = 1 AND d.attendance = 1
      AND MONTH(d.date) = 9 AND YEAR(d.date) = @endYear - 1
),
winRange AS (
    SELECT calendarID, structureID, MIN(date) AS winStart, MAX(date) AS winEnd
    FROM sepDays WHERE rn <= 10
    GROUP BY calendarID, structureID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       cal.schoolID AS [School ID], cal.schoolName AS [School], cal.endYear AS [School Year],
       e.grade AS [Grade],
       CASE WHEN e.startDate BETWEEN w.winStart AND w.winEnd
             AND e.endDate   BETWEEN w.winStart AND w.winEnd THEN 'Entered and left'
            WHEN e.startDate BETWEEN w.winStart AND w.winEnd THEN 'Entered'
            ELSE 'Left' END                         AS [Movement],
       CONVERT(date, w.winStart) AS [Window Start],
       CONVERT(date, w.winEnd)   AS [Window End],
       CONVERT(date, e.startDate) AS [Start Date], e.startStatus AS [Start Status],
       CONVERT(date, e.endDate)   AS [End Date],   e.endStatus AS [End Status],
       prior.priorSchool AS [Prior School],                        -- where an entering student came from (in-district)
       nxt.name                    AS [Next School], -- where a leaving student is going (if set)
       e.residentDistrict AS [Resident District]
FROM Enrollment e
JOIN winRange w ON w.calendarID = e.calendarID AND w.structureID = e.structureID
JOIN cal ON cal.calendarID = e.calendarID
JOIN Person p ON p.personID = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (
    SELECT TOP 1 s2.name AS priorSchool
    FROM Enrollment e2
    JOIN Calendar c2 ON c2.calendarID = e2.calendarID
    JOIN School s2 ON s2.schoolID = c2.schoolID
    WHERE e2.personID = e.personID
      AND e2.enrollmentID <> e.enrollmentID
      AND e2.serviceType = 'P'
      AND e2.endDate BETWEEN DATEADD(day, -@lookbackDays, e.startDate) AND e.startDate
    ORDER BY e2.endDate DESC
) prior
LEFT JOIN Calendar nc ON nc.calendarID = e.nextCalendar
LEFT JOIN School nxt  ON nxt.schoolID = nc.schoolID
WHERE e.serviceType = 'P'
  AND e.stateExclude = 0
  AND (e.startDate BETWEEN w.winStart AND w.winEnd
       OR e.endDate BETWEEN w.winStart AND w.winEnd)
ORDER BY cal.schoolName, [Movement], i.lastName, i.firstName;
