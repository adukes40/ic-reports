/* ======================================================================================
   #71  Credit-deficient students by grade
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 2 · Run Term
   Purpose:   Active grade 9-12 students whose total earned transcript credits are below
              the number expected for their grade.
   Output:    One row per student: credits earned, credits expected for the grade,
              credits behind
   Tables:    SchoolYear, Enrollment, Calendar, School, TranscriptCredit, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @expected09 (0), @expected10 (6), @expected11
              (12), @expected12 (18), @grade9, @grade10, @grade11, @seniorGrade  (change
              them in the PARAMETERS block below)
   Check:     The defaults are the credits a student should hold at the start of each
              grade on Delaware's 24-credit diploma (6 a year). Raise them as the year
              goes on, or to match your district's promotion rules. Only credit posted to
              the transcript counts.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear     int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID    int          = NULL;   -- NULL = all schools
DECLARE @asOf        date         = CONVERT(date, GETDATE());
DECLARE @expected09  decimal(5,2) = 0;      -- credits a 9th grader should have by now
DECLARE @expected10  decimal(5,2) = 6;      -- credits a 10th grader should have by now
DECLARE @expected11  decimal(5,2) = 12;     -- credits an 11th grader should have by now
DECLARE @expected12  decimal(5,2) = 18;     -- credits a 12th grader should have by now
DECLARE @grade9      varchar(10)  = '09';   -- grade name of your 9th graders
DECLARE @grade10     varchar(10)  = '10';   -- grade name of your 10th graders
DECLARE @grade11     varchar(10)  = '11';   -- grade name of your 11th graders
DECLARE @seniorGrade varchar(10)  = '12';   -- grade name of your 12th graders
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per grade 9-12 student on @asOf, with the credits expected
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           CASE e.grade WHEN @grade9  THEN @expected09 WHEN @grade10 THEN @expected10
                        WHEN @grade11 THEN @expected11 ELSE @expected12 END AS expected,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND e.grade IN (@grade9, @grade10, @grade11, @seniorGrade)
),
earned AS (   -- total transcript credits earned per student, all years
    SELECT tcr.personID, SUM(tcr.creditsEarned) AS credits
    FROM TranscriptCredit tcr
    WHERE tcr.personID IN (SELECT personID FROM act WHERE rn = 1)
    GROUP BY tcr.personID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       CAST(ISNULL(er.credits, 0) AS decimal(6,2)) AS [Credits Earned],
       a.expected AS [Credits Expected],
       CAST(a.expected - ISNULL(er.credits, 0) AS decimal(6,2)) AS [Credits Behind]
FROM act a
LEFT JOIN earned er ON er.personID  = a.personID
JOIN Person p       ON p.personID   = a.personID
JOIN [Identity] i   ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND ISNULL(er.credits, 0) < a.expected
ORDER BY a.schoolName, a.grade, [Credits Behind] DESC, i.lastName, i.firstName;
