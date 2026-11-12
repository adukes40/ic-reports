/* ======================================================================================
   #62  Tardies
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      List · Priority 3 · Run Weekly
   Purpose:   Tardy counts per student and period over the date range, for students with
              @minTardies or more tardies in total.
   Output:    One row per student per period: school, grade, period, tardies in the period,
              student total, last tardy date
   Tables:    SchoolYear, Attendance, AttendanceExcuse, Calendar, School, Period,
              Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @startDate, @endDate, @minTardies  (change them in the
              PARAMETERS block below)
   Check:     Tardy = status T (IC's standard value), read from the attendance code when
              the row has one, else from the row itself. Periods are grouped by period
              name.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int  = NULL;   -- NULL = all schools
DECLARE @endDate    date = CONVERT(date, GETDATE());      -- last day to count
DECLARE @startDate  date = DATEADD(day, -30, @endDate);   -- first day to count
DECLARE @minTardies int  = 5;      -- list students with this many tardies or more
-- ===========================================================================

WITH tardy AS (   -- tardies per student, calendar and period name in the range
    SELECT a.personID, a.calendarID, pd.name AS periodName, MIN(pd.seq) AS periodSeq,
           COUNT(*) AS tardies, MAX(a.date) AS lastTardy
    FROM Attendance a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Period  pd ON pd.periodID  = a.periodID
    LEFT JOIN AttendanceExcuse x ON x.excuseID = a.excuseID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND a.date >= @startDate AND a.date <= @endDate
      AND COALESCE(x.status, a.status) = 'T'
    GROUP BY a.personID, a.calendarID, pd.name
),
tot AS (   -- adds each student's total across periods
    SELECT t.*, SUM(t.tardies) OVER (PARTITION BY t.personID, t.calendarID) AS totalTardies
    FROM tardy t
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       t.periodName AS [Period],
       t.tardies AS [Tardies in Period],
       t.totalTardies AS [Student Total Tardies],
       CONVERT(date, t.lastTardy) AS [Last Tardy in Period]
FROM tot t
JOIN Calendar c ON c.calendarID = t.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = t.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = t.personID AND e.calendarID = t.calendarID
             ORDER BY e.startDate DESC) g
WHERE t.totalTardies >= @minTardies
ORDER BY s.name, t.totalTardies DESC, i.lastName, i.firstName, t.periodSeq;
