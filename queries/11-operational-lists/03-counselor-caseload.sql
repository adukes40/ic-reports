/* ======================================================================================
   #120  Counselor caseload
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 2 · Run On request
   Purpose:   Each counselor's assigned active students with grade, attendance rate, D/F
              count and referral count this year. Used by counselors.
   Output:    One row per student per counselor: counselor, grade, days enrolled, days
              absent, attendance rate, D/F grades, referrals
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, TeamMember,
              v_AttDaySummary_Exact, BehaviorEvent, BehaviorRole, GradingScore,
              GradingTask, Term
   Params:    @endYear, @schoolID, @asOf, @counselorID, @counselorLike, @task, @term
              (change them in the PARAMETERS block below)
   Check:     Counselor assignment is read from the student's Team Members (TeamMember)
              where the role or title matches @counselorLike; confirm that is where your
              district assigns counselors and what the role is called. @counselorID is the
              counselor's personID. @task must match your grading task name and @term your
              term name. D/F marks are 'D+', 'D', 'D-', 'F'. Referral roles are 'Offender'
              and 'Participant'.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int  = NULL;   -- NULL = all schools
DECLARE @asOf          date = CONVERT(date, GETDATE());
DECLARE @counselorID   int  = NULL;   -- counselor's personID; NULL = all counselors
DECLARE @counselorLike varchar(50) = '%Counselor%';   -- team member role or title; % is a wildcard
DECLARE @task          varchar(50) = '%Quarter%';     -- grading task name; % is a wildcard
DECLARE @term          varchar(10) = NULL;            -- term name, e.g. 'Q1'; NULL = every term this year
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
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
caseload AS (   -- current counselor-student assignments
    SELECT DISTINCT tm.personID, tm.staffPersonID, tm.lastName, tm.firstName
    FROM TeamMember tm
    WHERE (tm.role LIKE @counselorLike OR tm.title LIKE @counselorLike)
      AND (@counselorID IS NULL OR tm.staffPersonID = @counselorID)
      AND (tm.startDate IS NULL OR tm.startDate <= @asOf)
      AND (tm.endDate   IS NULL OR tm.endDate   >= @asOf)
),
att AS (   -- scheduled days and full-day absences per student this year
    SELECT a.personID, SUM(a.scheduledDays) AS scheduledDays, SUM(a.daysAbsent) AS daysAbsent
    FROM v_AttDaySummary_Exact a
    JOIN Calendar c ON c.calendarID = a.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
    GROUP BY a.personID
),
ref AS (   -- behavior incidents per student this year
    SELECT br.personID, COUNT(DISTINCT be.incidentID) AS referrals
    FROM BehaviorEvent be
    JOIN BehaviorRole br ON br.eventID = be.eventID
    JOIN Calendar c      ON c.calendarID = be.calendarID
    JOIN School   s      ON s.schoolID   = c.schoolID
    WHERE br.role IN ('Offender', 'Participant')   -- roles to count
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
    GROUP BY br.personID
),
df AS (   -- D and F grades per student for @task in @term
    SELECT gs.personID, COUNT(*) AS dfCount
    FROM GradingScore gs
    JOIN GradingTask gt ON gt.taskID    = gs.taskID
    JOIN Term tm        ON tm.termID    = gs.termID
    JOIN Calendar c     ON c.calendarID = gs.calendarID
    JOIN School   s     ON s.schoolID   = c.schoolID
    WHERE gs.score IN ('D+', 'D', 'D-', 'F')       -- D and F marks
      AND gt.name LIKE @task
      AND (@term IS NULL OR tm.name = @term)
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
    GROUP BY gs.personID
)
SELECT cl.staffPersonID AS [Counselor ID], cl.lastName AS [Counselor Last Name], cl.firstName AS [Counselor First Name],
       p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       att.scheduledDays AS [Days Enrolled], att.daysAbsent AS [Days Absent],
       CAST(100.0 - 100.0 * att.daysAbsent / NULLIF(att.scheduledDays, 0) AS decimal(5,1)) AS [Attendance Rate %],
       ISNULL(df.dfCount, 0) AS [D/F Grades],
       ISNULL(ref.referrals, 0) AS [Referrals]
FROM caseload cl
JOIN act a        ON a.personID   = cl.personID AND a.rn = 1
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN att ON att.personID = a.personID
LEFT JOIN ref ON ref.personID = a.personID
LEFT JOIN df  ON df.personID  = a.personID
ORDER BY cl.lastName, cl.firstName, a.schoolName, a.grade, i.lastName, i.firstName;
