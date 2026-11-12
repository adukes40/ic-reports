/* ======================================================================================
   #57  Attendance changed after the fact
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      List · Priority 2 · Run Weekly
   Purpose:   Attendance records added, changed or deleted more than @days days after the
              attendance date, with who did it, when, and the old and new code.
   Output:    One row per change: student, school, attendance date, period, changed on,
              days after, changed by, action, old code, new code
   Tables:    SchoolYear, AuditAttendance, AttendanceExcuse, Calendar, School, Period,
              UserAccount, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @days, @changedSince, @yearStart  (change them
              in the PARAMETERS block below)
   Check:     Assumes each AuditAttendance row holds the values saved by that action, so
              Old Code is the previous audit row for the same attendance record (blank
              when there is none). Action is shown as stored (normally I = added,
              U = changed, D = deleted). Changed By assumes modifiedByID is a user
              account ID.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int  = NULL;   -- NULL = all schools
DECLARE @asOf         date = CONVERT(date, GETDATE());
DECLARE @days         int  = 3;      -- list changes made more than this many days after the attendance date
DECLARE @changedSince date = DATEADD(day, -7, @asOf);   -- only changes made on or after this date
DECLARE @yearStart    date = (SELECT MIN(startDate) FROM Calendar WHERE endYear = @endYear AND exclude = 0 AND summerSchool = 0);   -- first day of the school year, from the calendars
-- ===========================================================================

WITH aud AS (   -- this year's attendance audit rows, each with the code saved just before it
    SELECT au.personID, au.periodID, au.date, au.actionType, au.modifiedDate, au.modifiedByID,
           c.schoolID, s.name AS schoolName, c.endYear,
           COALESCE(x.code, au.status) AS code,
           LAG(COALESCE(x.code, au.status))
               OVER (PARTITION BY au.attendanceID ORDER BY au.modifiedDate, au.auditID) AS prevCode
    FROM AuditAttendance au
    JOIN Calendar c ON c.calendarID = au.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    LEFT JOIN AttendanceExcuse x ON x.excuseID = au.excuseID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND au.date >= @yearStart
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year],
       CONVERT(date, a.date) AS [Attendance Date],
       pd.name AS [Period],
       a.modifiedDate AS [Changed On],
       DATEDIFF(day, a.date, a.modifiedDate) AS [Days After],
       COALESCE(ui.lastName + ', ' + ui.firstName, ua.username) AS [Changed By],
       a.actionType AS [Action],
       a.prevCode AS [Old Code],
       a.code AS [New Code]
FROM aud a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN Period pd      ON pd.periodID = a.periodID
LEFT JOIN UserAccount ua ON ua.userID   = a.modifiedByID
LEFT JOIN Person up      ON up.personID = ua.personID
LEFT JOIN [Identity] ui  ON ui.identityID = up.currentIdentityID
WHERE a.modifiedDate >= @changedSince
  AND a.modifiedDate <  DATEADD(day, 1, @asOf)
  AND DATEDIFF(day, a.date, a.modifiedDate) > @days
ORDER BY a.schoolName, a.modifiedDate DESC, i.lastName, i.firstName;
