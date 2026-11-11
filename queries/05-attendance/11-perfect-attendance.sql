/* ======================================================================================
   #63  Perfect attendance
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      List · Priority 3 · Run Quarter
   Purpose:   Students enrolled for every instructional day in the date range with no
              absence and no tardy of any kind.
   Output:    One row per student: school, grade, first and last instructional day in the
              range, instructional days
   Tables:    SchoolYear, Day, Calendar, School, Enrollment, Attendance, AttendanceExcuse,
              Person, Identity
   Params:    @endYear, @schoolID, @startDate, @endDate  (change them in the PARAMETERS
              block below)
   Check:     Any attendance row with status A (absent) or T (tardy) in the range rules a
              student out, excused or not, whole day or one period; early releases
              (status E) do not. The student must have one primary enrollment covering the
              whole range at the school, so mid-range transfers are left out. Set the
              dates to the quarter you are recognizing.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @startDate date = DATEFROMPARTS(@endYear - 1, 7, 1);   -- first day of the range
DECLARE @endDate   date = CONVERT(date, GETDATE());            -- last day of the range
-- ===========================================================================

WITH span AS (   -- first and last instructional day in the range, per calendar and structure
    SELECT d.calendarID, d.structureID, c.schoolID, s.name AS schoolName, c.endYear,
           MIN(d.date) AS firstDay, MAX(d.date) AS lastDay, COUNT(*) AS instDays
    FROM Day d
    JOIN Calendar c ON c.calendarID = d.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND d.instruction = 1 AND d.attendance = 1
      AND d.date >= @startDate AND d.date <= @endDate
    GROUP BY d.calendarID, d.structureID, c.schoolID, s.name, c.endYear
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       sp.schoolID AS [School ID], sp.schoolName AS [School], sp.endYear AS [School Year],
       e.grade AS [Grade],
       CONVERT(date, sp.firstDay) AS [First Day],
       CONVERT(date, sp.lastDay)  AS [Last Day],
       sp.instDays AS [Instructional Days]
FROM span sp
JOIN Enrollment e ON e.calendarID = sp.calendarID AND e.structureID = sp.structureID
                 AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
                 AND e.startDate <= sp.firstDay
                 AND (e.endDate IS NULL OR e.endDate >= sp.lastDay)
JOIN Person p     ON p.personID   = e.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE NOT EXISTS (SELECT 1
                  FROM Attendance a
                  LEFT JOIN AttendanceExcuse x ON x.excuseID = a.excuseID
                  WHERE a.personID = e.personID AND a.calendarID = e.calendarID
                    AND a.date >= @startDate AND a.date <= @endDate
                    AND COALESCE(x.status, a.status) IN ('A', 'T'))
ORDER BY sp.schoolName, e.grade, i.lastName, i.firstName;
