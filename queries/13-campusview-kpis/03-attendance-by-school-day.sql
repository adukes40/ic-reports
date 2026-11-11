/* ======================================================================================
   #141  Attendance by school day
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      KPI · Run Weekly
   Purpose:   Per school per instructional day so far this year: membership, students
              absent all day and the minute-weighted attendance rate. Days with zero
              scheduled minutes are left out.
   Output:    One row per school per day: membership, students with scheduled minutes,
              absent all day, scheduled minutes, absent minutes, attendance rate %
   Tables:    SchoolYear, Calendar, School, Day, Enrollment, AttDayAggregation
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Minutes come from AttDayAggregation. Students With Scheduled Minutes should be
              close to Membership; if it is far below, scheduled minutes are not being
              stored for every student day and the rate is not reliable (and days with none
              at all do not appear). Absent all day = absent minutes cover all of the
              student's scheduled minutes that day.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());   -- show days up to and including this date
-- ===========================================================================

WITH cal AS (   -- this year's calendars
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear
    FROM Calendar c
    JOIN School s ON s.schoolID = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
memberDays AS (   -- one row per enrolled student per instructional day, with that day's minutes if any were scheduled
    SELECT cal.schoolID, cal.schoolName, cal.endYear, d.date, e.personID,
           a.scheduledMinutes,
           CASE WHEN a.absentMinutes > a.scheduledMinutes THEN a.scheduledMinutes
                ELSE a.absentMinutes END AS absentMinutes
    FROM cal
    JOIN Day d ON d.calendarID = cal.calendarID
              AND d.instruction = 1 AND d.attendance = 1
              AND d.date <= @asOf
    JOIN Enrollment e ON e.calendarID = d.calendarID AND e.structureID = d.structureID
                     AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
                     AND e.startDate <= d.date
                     AND (e.endDate IS NULL OR e.endDate >= d.date)
    LEFT JOIN AttDayAggregation a
           ON a.calendarID = e.calendarID AND a.personID = e.personID AND a.date = d.date
          AND a.scheduledMinutes > 0
)
SELECT schoolID AS [School ID], schoolName AS [School], endYear AS [School Year],
       CONVERT(date, date) AS [Date],
       COUNT(DISTINCT personID) AS [Membership],
       COUNT(scheduledMinutes)  AS [Students With Scheduled Minutes],
       SUM(CASE WHEN absentMinutes >= scheduledMinutes THEN 1 ELSE 0 END) AS [Absent All Day],
       SUM(CAST(scheduledMinutes AS int)) AS [Scheduled Minutes],
       SUM(CAST(absentMinutes AS int))    AS [Absent Minutes],
       CAST(100.0 * SUM(scheduledMinutes - absentMinutes)
            / SUM(CAST(scheduledMinutes AS int)) AS decimal(5,1)) AS [Attendance Rate %]
FROM memberDays
GROUP BY schoolID, schoolName, endYear, date
HAVING SUM(CAST(scheduledMinutes AS int)) > 0
ORDER BY schoolName, date;
