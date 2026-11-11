/* ======================================================================================
   #55  Average daily attendance / membership
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      KPI · Priority 1 · Run Daily
   Purpose:   Students enrolled (membership), students present and the attendance rate for
              each school on each instructional day in the date range.
   Output:    One row per school per day: membership, present, absent all day, ADA %
   Tables:    SchoolYear, Calendar, School, Day, Enrollment, v_AttDayDetail_Exact
   Params:    @endYear, @schoolID, @startDate, @endDate  (change them in the PARAMETERS
              block below)
   Check:     A student counts as present unless absent the whole day (absentDay of 1 or
              more in v_AttDayDetail_Exact), so partial-day absences count as present.
              Membership is primary enrollments that are not no-shows.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @endDate   date = CONVERT(date, GETDATE());      -- last day to report
DECLARE @startDate date = DATEADD(day, -30, @endDate);   -- first day to report
-- ===========================================================================

WITH mem AS (   -- one row per enrolled student per instructional day in the range
    SELECT c.schoolID, s.name AS schoolName, c.endYear, d.date, e.personID, e.calendarID
    FROM Calendar c
    JOIN School s     ON s.schoolID = c.schoolID
    JOIN Day d        ON d.calendarID = c.calendarID
                     AND d.instruction = 1 AND d.attendance = 1
                     AND d.date >= @startDate AND d.date <= @endDate
    JOIN Enrollment e ON e.calendarID = d.calendarID AND e.structureID = d.structureID
                     AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
                     AND e.startDate <= d.date AND (e.endDate IS NULL OR e.endDate >= d.date)
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT m.schoolID AS [School ID], m.schoolName AS [School], m.endYear AS [School Year],
       CONVERT(date, m.date) AS [Date],
       COUNT(*) AS [Membership],
       COUNT(*) - SUM(CASE WHEN a.absentDay >= 1 THEN 1 ELSE 0 END) AS [Present],
       SUM(CASE WHEN a.absentDay >= 1 THEN 1 ELSE 0 END) AS [Absent All Day],
       CAST(100.0 * (COUNT(*) - SUM(CASE WHEN a.absentDay >= 1 THEN 1 ELSE 0 END))
            / COUNT(*) AS decimal(5,1)) AS [ADA %]
FROM mem m
LEFT JOIN v_AttDayDetail_Exact a
       ON a.personID = m.personID AND a.calendarID = m.calendarID AND a.date = m.date
GROUP BY m.schoolID, m.schoolName, m.endYear, m.date
ORDER BY m.schoolName, m.date;
