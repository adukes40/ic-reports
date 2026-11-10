/* ======================================================================================
   #8  Truancy ladder
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      List · Priority 1 · Run Weekly
   Purpose:   Students over the truancy line in unexcused full-day absences, with the date
              they reached each step and the highest step.
   Output:    One row per student per school: grade, unexcused days, dates each step was
              reached, highest step, last unexcused date
   Tables:    Calendar, School, Enrollment, v_AttDayDetail_Exact, Person, Identity
   Params:    @endYear, @schoolID, @truantLine (3), @step1-4 (3 / 10 / 15 / 20)  (change
              them in the PARAMETERS block below)
   Check:     Full day = unexcusedAbsentDay of 1 or more. 14 Del. C. §2721 says truant after
              more than 3 days. Set the step days to your district's ladder.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int = NULL;   -- NULL = all schools
DECLARE @truantLine int = 3;      -- return students with more than this many
DECLARE @step1 int = 3, @step2 int = 10, @step3 int = 15, @step4 int = 20;
-- ===========================================================================

WITH days AS (   -- full unexcused absent days, running count per student per calendar
    SELECT a.personID, a.calendarID, a.date,
           ROW_NUMBER() OVER (PARTITION BY a.personID, a.calendarID ORDER BY a.date) AS n
    FROM v_AttDayDetail_Exact a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND a.unexcusedAbsentDay >= 1
),
ladder AS (
    SELECT personID, calendarID,
           MAX(n) AS unexcusedDays,
           MIN(CASE WHEN n = @step1 THEN date END) AS step1Date,
           MIN(CASE WHEN n = @step2 THEN date END) AS step2Date,
           MIN(CASE WHEN n = @step3 THEN date END) AS step3Date,
           MIN(CASE WHEN n = @step4 THEN date END) AS step4Date,
           MAX(date) AS lastUnexcusedDate
    FROM days
    GROUP BY personID, calendarID
    HAVING MAX(n) > @truantLine
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       l.unexcusedDays AS [Unexcused Days],
       CONVERT(date, l.step1Date) AS [Reached Step 1],
       CONVERT(date, l.step2Date) AS [Reached Step 2],
       CONVERT(date, l.step3Date) AS [Reached Step 3],
       CONVERT(date, l.step4Date) AS [Reached Step 4],
       CASE WHEN l.unexcusedDays >= @step4 THEN @step4
            WHEN l.unexcusedDays >= @step3 THEN @step3
            WHEN l.unexcusedDays >= @step2 THEN @step2
            ELSE @step1 END AS [Highest Step],
       CONVERT(date, l.lastUnexcusedDate) AS [Last Unexcused Date]
FROM ladder l
JOIN Calendar c ON c.calendarID = l.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = l.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = l.personID AND e.calendarID = l.calendarID AND e.serviceType = 'P'
             ORDER BY e.startDate DESC) g
ORDER BY s.name, l.unexcusedDays DESC, i.lastName;
