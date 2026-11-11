/* ======================================================================================
   #61  Period skipping
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      List · Priority 2 · Run Weekly
   Purpose:   Students who were at school for the day but marked absent from one or more
              periods, counted by period over the date range.
   Output:    One row per student per period: school, grade, period, days absent from the
              period, how many were unexcused or unknown, first and last date
   Tables:    SchoolYear, Attendance, AttendanceExcuse, Calendar, School, Period,
              v_AttDayDetail_Exact, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @startDate, @endDate  (change them in the PARAMETERS
              block below)
   Check:     Absent = status A; unexcused or unknown = excuse U, K or blank (IC's standard
              values). "Present for the day" means the day is not a full-day absence
              (absentDay under 1 in v_AttDayDetail_Exact). Periods are grouped by period
              name. Excused period absences are counted in the first number, so read the
              unexcused or unknown column for skipping.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @endDate   date = CONVERT(date, GETDATE());      -- last day to count
DECLARE @startDate date = DATEADD(day, -30, @endDate);   -- first day to count
-- ===========================================================================

WITH periodAbs AS (   -- period absences in the range on days the student was not absent all day
    SELECT a.personID, a.calendarID, a.date, pd.name AS periodName, pd.seq AS periodSeq,
           CASE WHEN ISNULL(COALESCE(x.excuse, a.excuse), 'K') IN ('U', 'K') THEN 1 ELSE 0 END AS notExcused
    FROM Attendance a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Period  pd ON pd.periodID  = a.periodID
    LEFT JOIN AttendanceExcuse x ON x.excuseID = a.excuseID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND a.date >= @startDate AND a.date <= @endDate
      AND COALESCE(x.status, a.status) = 'A'
      AND NOT EXISTS (SELECT 1 FROM v_AttDayDetail_Exact v
                      WHERE v.personID = a.personID AND v.calendarID = a.calendarID
                        AND v.date = a.date AND v.absentDay >= 1)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       pa.periodName AS [Period],
       COUNT(DISTINCT pa.date) AS [Days Absent From Period],
       SUM(pa.notExcused) AS [Unexcused or Unknown],
       CONVERT(date, MIN(pa.date)) AS [First Date],
       CONVERT(date, MAX(pa.date)) AS [Last Date]
FROM periodAbs pa
JOIN Calendar c ON c.calendarID = pa.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = pa.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = pa.personID AND e.calendarID = pa.calendarID
             ORDER BY e.startDate DESC) g
GROUP BY p.studentNumber, i.lastName, i.firstName, c.schoolID, s.name, c.endYear, g.grade,
         pa.personID, pa.periodName
ORDER BY s.name, i.lastName, i.firstName, MIN(pa.periodSeq);
