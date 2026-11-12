/* ======================================================================================
   #139  Attendance rate
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      KPI · Run Monthly
   Purpose:   Minute-weighted attendance rate per school and grade for the year so far:
              (scheduled minutes - absent minutes) / scheduled minutes, summed over every
              student day. Daily rates are never averaged.
   Output:    One row per school per grade: student days counted and skipped, scheduled
              minutes, absent minutes, attendance rate %
   Tables:    SchoolYear, Calendar, School, Enrollment, AttDayAggregation
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Student days with no scheduled minutes in AttDayAggregation are skipped and
              counted in Student Days Skipped. If that number is large next to Student Days
              Counted, scheduled minutes are not being stored for every day and the rate
              is not reliable. Absent minutes above the day's scheduled minutes are capped.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());   -- count days up to and including this date
-- ===========================================================================

WITH cal AS (   -- this year's calendars
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear, c.startDate
    FROM Calendar c
    JOIN School s ON s.schoolID = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
studentDays AS (   -- one row per student per day, with the grade of the primary enrollment covering it
    SELECT cal.schoolID, cal.schoolName, cal.endYear, e.grade,
           a.scheduledMinutes,
           CASE WHEN a.absentMinutes > a.scheduledMinutes THEN a.scheduledMinutes
                ELSE a.absentMinutes END AS absentMinutes
    FROM AttDayAggregation a
    JOIN cal ON cal.calendarID = a.calendarID
    JOIN Enrollment e ON e.personID = a.personID AND e.calendarID = a.calendarID
                     AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
                     AND e.startDate <= a.date
                     AND (e.endDate IS NULL OR e.endDate >= a.date)
    WHERE a.date >= cal.startDate AND a.date <= @asOf
)
SELECT schoolID AS [School ID], schoolName AS [School], endYear AS [School Year], grade AS [Grade],
       SUM(CASE WHEN scheduledMinutes > 0 THEN 1 ELSE 0 END) AS [Student Days Counted],
       SUM(CASE WHEN scheduledMinutes > 0 THEN 0 ELSE 1 END) AS [Student Days Skipped],
       SUM(CASE WHEN scheduledMinutes > 0 THEN CAST(scheduledMinutes AS int) END) AS [Scheduled Minutes],
       SUM(CASE WHEN scheduledMinutes > 0 THEN CAST(absentMinutes AS int) END)    AS [Absent Minutes],
       CAST(100.0 * SUM(CASE WHEN scheduledMinutes > 0 THEN scheduledMinutes - absentMinutes END)
            / NULLIF(SUM(CASE WHEN scheduledMinutes > 0 THEN CAST(scheduledMinutes AS int) END), 0)
            AS decimal(5,1)) AS [Attendance Rate %]
FROM studentDays
GROUP BY schoolID, schoolName, endYear, grade
ORDER BY schoolName, grade;
