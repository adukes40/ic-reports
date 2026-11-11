/* ======================================================================================
   #54  Chronic absence list + rate
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      KPI · Priority 1 · Run Weekly
   Purpose:   Instructional days enrolled, full-day absences and percent absent per student
              per school this year, flagging 10% or more, with the school's chronic
              absence rate beside it.
   Output:    One row per student per school: grade, days enrolled, days absent, percent
              absent, status, school numerator / denominator / rate
   Tables:    SchoolYear, Enrollment, Calendar, School, Day, v_AttDayDetail_Exact, Person,
              Identity
   Params:    @endYear, @schoolID, @asOf, @chronicPct, @minDays  (change them in the
              PARAMETERS block below)
   Check:     Calendar.wholeDayAbsence is blank in this district, so a full-day absence is
              a day with absentDay of 1 or more in v_AttDayDetail_Exact; partial days do
              not count. All absence reasons count, excused or not. Students enrolled
              fewer than @minDays days are left out of the list and the rate.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int  = NULL;   -- NULL = all schools
DECLARE @asOf       date = CONVERT(date, GETDATE());   -- count days through this date
DECLARE @chronicPct decimal(5,2) = 10.0;   -- flag at or over this percent absent
DECLARE @minDays    int  = 10;     -- skip students enrolled fewer days than this
-- ===========================================================================

WITH stu AS (   -- per student per school: instructional days enrolled and full-day absences through @asOf
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear,
           COUNT(*) AS daysEnrolled,
           SUM(CASE WHEN a.absentDay >= 1 THEN 1 ELSE 0 END) AS daysAbsent
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Day d      ON d.calendarID = e.calendarID AND d.structureID = e.structureID
                   AND d.instruction = 1 AND d.attendance = 1
                   AND d.date >= e.startDate AND (e.endDate IS NULL OR d.date <= e.endDate)
                   AND d.date <= @asOf
    LEFT JOIN v_AttDayDetail_Exact a
           ON a.personID = e.personID AND a.calendarID = e.calendarID AND a.date = d.date
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
    GROUP BY e.personID, c.schoolID, s.name, c.endYear
    HAVING COUNT(*) >= @minDays
),
flag AS (   -- adds percent absent and the chronic flag
    SELECT stu.*,
           CAST(100.0 * daysAbsent / daysEnrolled AS decimal(5,1)) AS pctAbsent,
           CASE WHEN 100.0 * daysAbsent / daysEnrolled >= @chronicPct THEN 1 ELSE 0 END AS chronic
    FROM stu
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       f.schoolID AS [School ID], f.schoolName AS [School], f.endYear AS [School Year],
       g.grade AS [Grade],
       f.daysEnrolled AS [Days Enrolled], f.daysAbsent AS [Days Absent], f.pctAbsent AS [Percent Absent],
       CASE f.chronic WHEN 1 THEN 'Chronically absent' ELSE 'Not chronic' END AS [Status],
       SUM(f.chronic) OVER (PARTITION BY f.schoolID) AS [School Chronically Absent],
       COUNT(*)       OVER (PARTITION BY f.schoolID) AS [School Students],
       CAST(100.0 * SUM(f.chronic) OVER (PARTITION BY f.schoolID)
            / COUNT(*) OVER (PARTITION BY f.schoolID) AS decimal(5,1)) AS [School Chronic Absence %]
FROM flag f
JOIN Person p     ON p.personID   = f.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade
             FROM Enrollment e
             JOIN Calendar c ON c.calendarID = e.calendarID
             WHERE e.personID = f.personID AND c.schoolID = f.schoolID AND c.endYear = f.endYear
               AND e.serviceType = 'P'
             ORDER BY e.startDate DESC) g
ORDER BY f.schoolName, f.pctAbsent DESC, i.lastName, i.firstName;
