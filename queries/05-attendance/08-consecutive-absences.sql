/* ======================================================================================
   #60  Consecutive absences
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      List · Priority 1 · Run Daily
   Purpose:   Active students absent all day for @n or more instructional days in a row,
              ending on the latest instructional day up to @asOf.
   Output:    One row per student: school, grade, consecutive days absent, streak start,
              last day absent
   Tables:    SchoolYear, Enrollment, Calendar, School, Day, v_AttDayDetail_Exact, Person,
              Identity
   Params:    @endYear, @schoolID, @asOf, @n, @lookback  (change them in the PARAMETERS
              block below)
   Check:     Absent all day = absentDay of 1 or more in v_AttDayDetail_Exact. Streaks are
              counted inside the student's current enrollment and no further back than
              @lookback calendar days. If today's attendance is not in yet, set @asOf to
              the last school day.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @n        int  = 3;      -- list streaks of this many days or more
DECLARE @lookback int  = 90;     -- calendar days to look back for the streak start
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, e.calendarID, e.structureID, e.startDate,
           c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
days AS (   -- each student's recent instructional days, flagged absent all day or not, with the last day not absent
    SELECT a.personID, d.date,
           CASE WHEN v.absentDay >= 1 THEN 1 ELSE 0 END AS absent,
           MAX(CASE WHEN v.absentDay >= 1 THEN NULL ELSE d.date END)
               OVER (PARTITION BY a.personID) AS lastNotAbsent
    FROM act a
    JOIN Day d ON d.calendarID = a.calendarID AND d.structureID = a.structureID
              AND d.instruction = 1 AND d.attendance = 1
              AND d.date >= a.startDate
              AND d.date >= DATEADD(day, -@lookback, @asOf) AND d.date <= @asOf
    LEFT JOIN v_AttDayDetail_Exact v
           ON v.personID = a.personID AND v.calendarID = a.calendarID AND v.date = d.date
    WHERE a.rn = 1
),
streak AS (   -- the run of absent days after the last day not absent
    SELECT personID, COUNT(*) AS daysAbsent, MIN(date) AS streakStart, MAX(date) AS lastAbsent
    FROM days
    WHERE absent = 1 AND (lastNotAbsent IS NULL OR date > lastNotAbsent)
    GROUP BY personID
    HAVING COUNT(*) >= @n
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       st.daysAbsent AS [Consecutive Days Absent],
       CONVERT(date, st.streakStart) AS [Streak Start],
       CONVERT(date, st.lastAbsent)  AS [Last Day Absent]
FROM streak st
JOIN act a        ON a.personID   = st.personID AND a.rn = 1
JOIN Person p     ON p.personID   = st.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY a.schoolName, st.daysAbsent DESC, i.lastName, i.firstName;
