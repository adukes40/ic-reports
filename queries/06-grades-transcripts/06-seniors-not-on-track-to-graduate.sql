/* ======================================================================================
   #70  Seniors not on track to graduate
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      List · Priority 1 · Run Fall, spring
   Purpose:   Active 12th graders whose earned plus in-progress credits fall short of the
              graduation requirement, in total or in any credit area.
   Output:    One row per senior and credit area that is short: required, earned, in
              progress, shortfall
   Tables:    SchoolYear, Enrollment, Calendar, School, TranscriptCredit,
              TranscriptCourse, Trial, Roster, Section, Course, GradingTaskCredit,
              CurriculumStandard, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @requiredCredits (24), @seniorGrade,
              @reqEnglish, @englishLike, @reqMath, @mathLike, @reqScience, @scienceLike,
              @reqSocial, @socialLike, @reqWorldLang, @worldLangLike, @reqPE, @peLike,
              @reqHealth, @healthLike, @reqCareer, @careerLike  (change them in the
              PARAMETERS block below)
   Check:     Requirements are not stored in Campus here, so they are parameters: 24 total
              and the Delaware minimums per area (14 DE Admin. Code 505, 5.1). Change the
              @req... values to your district's; 0 means the area is not required. The
              rule that one math credit is earned in the senior year is not tested. The
              @...Like name patterns must match your credit type names, or every senior
              shows as short in that area. Electives are covered by the total. In
              progress = credit set on this year's scheduled courses that is not on the
              transcript yet; it carries a credit type only where the course's grading
              task has one.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear         int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID        int          = NULL;   -- NULL = all schools
DECLARE @asOf            date         = CONVERT(date, GETDATE());
DECLARE @requiredCredits decimal(5,2) = 24;     -- total credits needed to graduate
DECLARE @seniorGrade     varchar(10)  = '12';   -- grade name of your seniors
DECLARE @reqEnglish      decimal(4,1) = 4.0;    -- English credits required (0 = not required)
DECLARE @englishLike     varchar(50)  = 'English%';   -- credit type names that count as English (% = any text)
DECLARE @reqMath         decimal(4,1) = 4.0;    -- mathematics credits required
DECLARE @mathLike        varchar(50)  = 'Math%';      -- credit type names that count as mathematics
DECLARE @reqScience      decimal(4,1) = 3.0;    -- science credits required
DECLARE @scienceLike     varchar(50)  = 'Science%';   -- credit type names that count as science
DECLARE @reqSocial       decimal(4,1) = 3.0;    -- social studies credits required
DECLARE @socialLike      varchar(50)  = 'Social%';    -- credit type names that count as social studies
DECLARE @reqWorldLang    decimal(4,1) = 2.0;    -- world language credits required
DECLARE @worldLangLike   varchar(50)  = 'World%';     -- credit type names that count as world language
DECLARE @reqPE           decimal(4,1) = 1.0;    -- physical education credits required
DECLARE @peLike          varchar(50)  = 'Phys%';      -- credit type names that count as physical education
DECLARE @reqHealth       decimal(4,1) = 0.5;    -- health credits required
DECLARE @healthLike      varchar(50)  = 'Health%';    -- credit type names that count as health
DECLARE @reqCareer       decimal(4,1) = 3.0;    -- career pathway credits required
DECLARE @careerLike      varchar(50)  = 'Career%';    -- credit type names that count as career pathway
-- ===========================================================================

WITH req AS (   -- credit area, credit type name pattern, credits required (set in the PARAMETERS block)
    SELECT v.area, v.pattern, v.required
    FROM (VALUES ('English',            @englishLike,   @reqEnglish),
                 ('Mathematics',        @mathLike,      @reqMath),
                 ('Science',            @scienceLike,   @reqScience),
                 ('Social Studies',     @socialLike,    @reqSocial),
                 ('World Language',     @worldLangLike, @reqWorldLang),
                 ('Physical Education', @peLike,        @reqPE),
                 ('Health',             @healthLike,    @reqHealth),
                 ('Career Pathway',     @careerLike,    @reqCareer),
                 ('Total credits',      '%',            @requiredCredits)) v(area, pattern, required)
),
act AS (   -- one active primary enrollment per 12th grader on @asOf
    SELECT e.personID, e.calendarID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND e.grade = @seniorGrade
),
earned AS (   -- transcript credits earned per senior and credit type, all years
    SELECT tcr.personID, tcr.standardID, SUM(tcr.creditsEarned) AS earned
    FROM TranscriptCredit tcr
    WHERE tcr.personID IN (SELECT personID FROM act WHERE rn = 1)
    GROUP BY tcr.personID, tcr.standardID
),
posted AS (   -- credit already on this year's transcript per senior, course and credit type
    SELECT tc.personID, tc.courseNumber, tcr.standardID, SUM(tcr.creditsAttempted) AS attempted
    FROM TranscriptCourse tc
    JOIN TranscriptCredit tcr ON tcr.transcriptID = tc.transcriptID
    WHERE tc.endYear = @endYear
      AND tc.personID IN (SELECT personID FROM act WHERE rn = 1)
    GROUP BY tc.personID, tc.courseNumber, tcr.standardID
),
sched AS (   -- the courses on each senior's schedule this year
    SELECT DISTINCT a.personID, co.courseID, co.number AS courseNumber
    FROM act a
    JOIN Trial tr   ON tr.calendarID = a.calendarID AND tr.active = 1
    JOIN Roster r   ON r.trialID     = tr.trialID   AND r.personID = a.personID
    JOIN Section se ON se.sectionID  = r.sectionID  AND se.trialID = tr.trialID
    JOIN Course co  ON co.courseID   = se.courseID
    WHERE a.rn = 1
      AND (r.endDate IS NULL OR r.endDate >= @asOf)
),
prog AS (   -- credit still to come from the schedule: course credit less what is already posted
    SELECT sc.personID, cc.standardID,
           SUM(CASE WHEN cc.credit > ISNULL(po.attempted, 0) THEN cc.credit - ISNULL(po.attempted, 0) ELSE 0 END) AS inProgress
    FROM sched sc
    JOIN (SELECT courseID, standardID, SUM(credit) AS credit
          FROM GradingTaskCredit
          WHERE credit > 0
          GROUP BY courseID, standardID) cc ON cc.courseID = sc.courseID
    LEFT JOIN posted po ON po.personID = sc.personID AND po.courseNumber = sc.courseNumber
                       AND ISNULL(po.standardID, 0) = ISNULL(cc.standardID, 0)
    GROUP BY sc.personID, cc.standardID
),
byType AS (   -- earned and in-progress credit per senior and credit type
    SELECT u.personID, u.standardID, SUM(u.earned) AS earned, SUM(u.inProgress) AS inProgress
    FROM (SELECT personID, standardID, earned, 0 AS inProgress FROM earned
          UNION ALL
          SELECT personID, standardID, 0, inProgress FROM prog) u
    GROUP BY u.personID, u.standardID
),
byArea AS (   -- every senior against every requirement
    SELECT a.personID, a.schoolID, a.schoolName, a.endYear, a.grade, rq.area, rq.required,
           ISNULL(SUM(CASE WHEN rq.pattern = '%' OR cs.name LIKE rq.pattern THEN bt.earned END), 0)     AS earned,
           ISNULL(SUM(CASE WHEN rq.pattern = '%' OR cs.name LIKE rq.pattern THEN bt.inProgress END), 0) AS inProgress
    FROM act a
    CROSS JOIN req rq
    LEFT JOIN byType bt             ON bt.personID   = a.personID
    LEFT JOIN CurriculumStandard cs ON cs.standardID = bt.standardID
    WHERE a.rn = 1
    GROUP BY a.personID, a.schoolID, a.schoolName, a.endYear, a.grade, rq.area, rq.required
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       b.schoolID AS [School ID], b.schoolName AS [School], b.endYear AS [School Year], b.grade AS [Grade],
       b.area AS [Credit Area],
       CAST(b.required   AS decimal(6,2)) AS [Required],
       CAST(b.earned     AS decimal(6,2)) AS [Earned],
       CAST(b.inProgress AS decimal(6,2)) AS [In Progress],
       CAST(b.required - b.earned - b.inProgress AS decimal(6,2)) AS [Shortfall]
FROM byArea b
JOIN Person p     ON p.personID   = b.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE b.earned + b.inProgress < b.required
ORDER BY b.schoolName, i.lastName, i.firstName, b.area;
