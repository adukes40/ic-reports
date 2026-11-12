/* ======================================================================================
   #23  No-shows
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      List · Priority 1 · Run BOY, Sept
   Purpose:   Active primary enrollments with no day present since the start date.
   Output:    One row per no-show: start date, instructional days since start, days absent,
              IC no-show flag
   Tables:    Calendar, School, Day, Enrollment, v_AttDayDetail_Exact, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @minDays (3)  (change them in the PARAMETERS block
              below)
   Check:     Present days = instructional days since start minus full-day absences.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @minDays  int = 3;      -- instructional days since start before flagging
-- ===========================================================================

WITH enr AS (
    SELECT e.enrollmentID, e.personID, e.calendarID, e.structureID, e.grade, e.startDate, e.noShow,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P'
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
d AS (
    SELECT en.enrollmentID,
           COUNT(*) AS daysSinceStart,
           SUM(ISNULL(a.absentDay, 0)) AS daysAbsent
    FROM enr en
    JOIN Day dy ON dy.calendarID = en.calendarID AND dy.structureID = en.structureID
               AND dy.instruction = 1 AND dy.attendance = 1
               AND dy.date >= en.startDate AND dy.date <= @asOf
    LEFT JOIN v_AttDayDetail_Exact a
           ON a.personID = en.personID AND a.calendarID = en.calendarID AND a.date = dy.date
    GROUP BY en.enrollmentID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       en.schoolID AS [School ID], en.schoolName AS [School], en.endYear AS [School Year], en.grade AS [Grade],
       CONVERT(date, en.startDate) AS [Start Date],
       d.daysSinceStart AS [Days Since Start], d.daysAbsent AS [Days Absent],
       CASE WHEN en.noShow = 1 THEN 'Y' ELSE 'N' END AS [Marked No-Show],
       'No day present since enrollment start' AS [Issue]
FROM enr en
JOIN d ON d.enrollmentID = en.enrollmentID
JOIN Person p ON p.personID = en.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE d.daysSinceStart >= @minDays
  AND d.daysSinceStart - d.daysAbsent <= 0
ORDER BY en.schoolName, en.grade, i.lastName;
