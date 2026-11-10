/* ======================================================================================
   #7  On-Track Attendance (DSSF chronic absence)
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      KPI · Priority 1 · Run Monthly
   Purpose:   Scheduled days, full-day absences for any reason and percent absent per
              student per school, with a 10% flag and school rate.
   Output:    One row per student per school: grade, scheduled days, days absent, %, status,
              school numerator / denominator / %
   Tables:    Calendar, School, Enrollment, v_AttDaySummary_Exact, Person, Identity
   Params:    @endYear, @schoolID, @chronicPct (10), @minDays (10)  (change them in the
              PARAMETERS block below)
   Check:     OSS counts only if OSS days are recorded as absences in attendance. Spot-check
              one suspended student.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int = NULL;   -- NULL = all schools
DECLARE @chronicPct   decimal(5,2) = 10.0;
DECLARE @minDays      int = 10;     -- skip students enrolled fewer days than this
-- ===========================================================================

WITH base AS (
    SELECT a.personID, c.schoolID, s.name AS schoolName, c.endYear,
           a.scheduledDays, a.daysAbsent,
           CAST(100.0 * a.daysAbsent / NULLIF(a.scheduledDays, 0) AS decimal(5,1)) AS pctAbsent
    FROM v_AttDaySummary_Exact a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND a.scheduledDays >= @minDays
      AND EXISTS (SELECT 1 FROM Enrollment e
                  WHERE e.personID = a.personID AND e.calendarID = a.calendarID
                    AND e.serviceType = 'P' AND e.stateExclude = 0)
),
flag AS (
    SELECT base.*, CASE WHEN pctAbsent >= @chronicPct THEN 1 ELSE 0 END AS chronic
    FROM base
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       f.schoolID AS [School ID], f.schoolName AS [School], f.endYear AS [School Year],
       g.grade AS [Grade],
       f.scheduledDays AS [Scheduled Days], f.daysAbsent AS [Days Absent], f.pctAbsent AS [Percent Absent],
       CASE f.chronic WHEN 1 THEN 'Chronically absent' ELSE 'On track' END AS [Status],
       SUM(f.chronic) OVER (PARTITION BY f.schoolID) AS [School Chronically Absent],   -- numerator
       COUNT(*)       OVER (PARTITION BY f.schoolID) AS [School Students],  -- denominator
       CAST(100.0 * SUM(f.chronic) OVER (PARTITION BY f.schoolID)
            / COUNT(*) OVER (PARTITION BY f.schoolID) AS decimal(5,1)) AS [School Chronic Absence %]
FROM flag f
JOIN Person p ON p.personID = f.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             JOIN Calendar c ON c.calendarID = e.calendarID
             WHERE e.personID = f.personID AND c.schoolID = f.schoolID AND c.endYear = f.endYear
               AND e.serviceType = 'P'
             ORDER BY e.startDate DESC) g
ORDER BY f.schoolName, f.pctAbsent DESC;
