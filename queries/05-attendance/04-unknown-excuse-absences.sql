/* ======================================================================================
   #56  Unknown-excuse absences
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      Validation · Priority 2 · Run Weekly
   Purpose:   Absences this year that are still coded with an Unknown excuse more than
              @days days after the absence date.
   Output:    One row per absence: student, school, grade, absence date, period, attendance
              code, days old, issue
   Tables:    SchoolYear, Attendance, AttendanceExcuse, Calendar, School, Period,
              Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @days, @yearStart  (change them in the
              PARAMETERS block below)
   Check:     Absent = status A and Unknown = excuse K (IC's standard values), read from the
              attendance code when the row has one, else from the row itself. An absence
              with no excuse value at all is also treated as Unknown.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @days     int  = 5;      -- list absences older than this many days
DECLARE @yearStart date = (SELECT MIN(startDate) FROM Calendar WHERE endYear = @endYear AND exclude = 0 AND summerSchool = 0);   -- first day of the school year, from the calendars
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       CONVERT(date, a.date) AS [Absence Date],
       pd.name AS [Period],
       x.code AS [Attendance Code],
       DATEDIFF(day, a.date, @asOf) AS [Days Old],
       'Absence still coded Unknown after ' + CAST(@days AS varchar(5)) + ' days' AS [Issue]
FROM Attendance a
JOIN Calendar c ON c.calendarID = a.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN AttendanceExcuse x ON x.excuseID = a.excuseID
LEFT JOIN Period pd          ON pd.periodID = a.periodID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = a.personID AND e.calendarID = a.calendarID
             ORDER BY e.startDate DESC) g
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND a.date >= @yearStart
  AND a.date <  DATEADD(day, -@days, @asOf)
  AND COALESCE(x.status, a.status) = 'A'
  AND ISNULL(COALESCE(x.excuse, a.excuse), 'K') = 'K'
ORDER BY s.name, a.date, i.lastName, i.firstName, pd.seq;
