/* ======================================================================================
   #58  Attendance on non-school days
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      Validation · Priority 2 · Run Monthly
   Purpose:   Attendance recorded on dates that are outside the calendar, have no Day
              record, or are marked non-instructional or not for attendance.
   Output:    One row per student per date: school, grade, attendance date, weekday,
              attendance rows, issue
   Tables:    SchoolYear, Attendance, Calendar, School, Day, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @startDate, @endDate  (change them in the PARAMETERS
              block below)
   Check:     A school day is a Day row with both Instruction and Attendance checked.
              Only attendance dated from @startDate to @endDate is scanned.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @startDate date = DATEFROMPARTS(@endYear - 1, 7, 1);   -- first attendance date to scan
DECLARE @endDate   date = DATEFROMPARTS(@endYear, 6, 30);      -- last attendance date to scan
-- ===========================================================================

WITH bad AS (   -- attendance per student and date with no instructional attendance day behind it
    SELECT a.personID, a.calendarID, a.date, COUNT(*) AS attRows
    FROM Attendance a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND a.date >= @startDate AND a.date <= @endDate
      AND NOT EXISTS (SELECT 1 FROM Day d
                      WHERE d.calendarID = a.calendarID AND d.date = a.date
                        AND d.instruction = 1 AND d.attendance = 1)
    GROUP BY a.personID, a.calendarID, a.date
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       CONVERT(date, b.date) AS [Attendance Date],
       DATENAME(weekday, b.date) AS [Weekday],
       b.attRows AS [Attendance Rows],
       CASE WHEN b.date < c.startDate OR b.date > c.endDate
                 THEN 'Attendance dated outside the calendar start and end dates'
            WHEN NOT EXISTS (SELECT 1 FROM Day d
                             WHERE d.calendarID = b.calendarID AND d.date = b.date)
                 THEN 'Attendance on a date with no Day record in the calendar'
            WHEN NOT EXISTS (SELECT 1 FROM Day d
                             WHERE d.calendarID = b.calendarID AND d.date = b.date AND d.instruction = 1)
                 THEN 'Attendance on a day marked non-instructional'
            ELSE 'Attendance on a day not marked for attendance' END AS [Issue]
FROM bad b
JOIN Calendar c ON c.calendarID = b.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = b.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = b.personID AND e.calendarID = b.calendarID
             ORDER BY e.startDate DESC) g
ORDER BY s.name, b.date, i.lastName, i.firstName;
