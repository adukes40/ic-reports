/* ======================================================================================
   #6  On Track in 9th Grade
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      KPI · Priority 1 · Run Semester, EOY
   Purpose:   Credits earned this year by first-time 9th graders across ELA, math, science,
              social studies and world languages, with an on-track flag and school rate.
   Output:    One row per student: credits per area, core total, areas with credit, status,
              school numerator / denominator / %
   Tables:    Calendar, School, Enrollment, TranscriptCourse, TranscriptCredit, Person,
              Identity
   Params:    @endYear, @schoolID, @minCredits (4), @minAreas (4), @asOf, @grade9,
              @elaArea, @mathArea, @scienceArea, @socStudiesArea, @worldLangArea  (change
              them in the PARAMETERS block below)
   Check:     On track = 4+ core credits AND credit in 4+ of the 5 areas; confirm against
              DDOE's definition. Only posted transcript credit counts.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int = NULL;   -- NULL = all schools
DECLARE @minCredits decimal(5,2) = 4;
DECLARE @minAreas   int = 4;
DECLARE @asOf       date = CONVERT(date, GETDATE());
DECLARE @grade9         varchar(5) = '09';   -- grade name of 9th grade
DECLARE @elaArea        varchar(5) = '01';   -- SCED subject area code for English language arts
DECLARE @mathArea       varchar(5) = '02';   -- SCED subject area code for math
DECLARE @scienceArea    varchar(5) = '03';   -- SCED subject area code for science
DECLARE @socStudiesArea varchar(5) = '04';   -- SCED subject area code for social studies
DECLARE @worldLangArea  varchar(5) = '24';   -- SCED subject area code for world languages
-- ===========================================================================

WITH g9 AS (   -- first-time 9th graders with a current primary enrollment
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P' AND e.stateExclude = 0
      AND e.grade = @grade9
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND NOT EXISTS (SELECT 1 FROM Enrollment ep
                      JOIN Calendar cp ON cp.calendarID = ep.calendarID
                      WHERE ep.personID = e.personID AND ep.grade = @grade9
                        AND cp.endYear < @endYear)
),
cred AS (
    SELECT tc.personID,
           CASE COALESCE(NULLIF(tc.scedSubjectArea, ''), LEFT(tc.scedCourseId, 2))
                WHEN @elaArea THEN 'ELA' WHEN @mathArea THEN 'Math' WHEN @scienceArea THEN 'Science'
                WHEN @socStudiesArea THEN 'SocialStudies' WHEN @worldLangArea THEN 'WorldLang' END AS area,
           SUM(ISNULL(cr.creditsEarned, 0)) AS credits
    FROM TranscriptCourse tc
    JOIN TranscriptCredit cr ON cr.transcriptID = tc.transcriptID
    WHERE tc.endYear = @endYear
      AND tc.personID IN (SELECT personID FROM g9 WHERE rn = 1)
    GROUP BY tc.personID,
             CASE COALESCE(NULLIF(tc.scedSubjectArea, ''), LEFT(tc.scedCourseId, 2))
                  WHEN @elaArea THEN 'ELA' WHEN @mathArea THEN 'Math' WHEN @scienceArea THEN 'Science'
                  WHEN @socStudiesArea THEN 'SocialStudies' WHEN @worldLangArea THEN 'WorldLang' END
),
stu AS (
    SELECT g.personID, g.schoolID, g.schoolName, g.endYear,
           SUM(CASE WHEN cr.area = 'ELA'           THEN cr.credits ELSE 0 END) AS elaCredits,
           SUM(CASE WHEN cr.area = 'Math'          THEN cr.credits ELSE 0 END) AS mathCredits,
           SUM(CASE WHEN cr.area = 'Science'       THEN cr.credits ELSE 0 END) AS scienceCredits,
           SUM(CASE WHEN cr.area = 'SocialStudies' THEN cr.credits ELSE 0 END) AS socStudiesCredits,
           SUM(CASE WHEN cr.area = 'WorldLang'     THEN cr.credits ELSE 0 END) AS worldLangCredits,
           SUM(CASE WHEN cr.area IS NOT NULL THEN cr.credits ELSE 0 END)       AS coreCredits,
           COUNT(DISTINCT CASE WHEN cr.area IS NOT NULL AND cr.credits > 0 THEN cr.area END) AS areasWithCredit
    FROM g9 g
    LEFT JOIN cred cr ON cr.personID = g.personID
    WHERE g.rn = 1
    GROUP BY g.personID, g.schoolID, g.schoolName, g.endYear
),
flag AS (
    SELECT stu.*,
           CASE WHEN coreCredits >= @minCredits AND areasWithCredit >= @minAreas THEN 1 ELSE 0 END AS onTrack
    FROM stu
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       f.schoolID AS [School ID], f.schoolName AS [School], f.endYear AS [School Year], @grade9 AS [Grade],
       f.elaCredits AS [ELA Credits], f.mathCredits AS [Math Credits], f.scienceCredits AS [Science Credits], f.socStudiesCredits AS [Social Studies Credits], f.worldLangCredits AS [World Language Credits],
       f.coreCredits AS [Core Credits], f.areasWithCredit AS [Areas With Credit],
       CASE f.onTrack WHEN 1 THEN 'On track' ELSE 'Not on track' END AS [Status],
       SUM(f.onTrack) OVER (PARTITION BY f.schoolID) AS [School On Track],      -- numerator
       COUNT(*)       OVER (PARTITION BY f.schoolID) AS [School Ninth Graders], -- denominator
       CAST(100.0 * SUM(f.onTrack) OVER (PARTITION BY f.schoolID)
            / COUNT(*) OVER (PARTITION BY f.schoolID) AS decimal(5,1)) AS [School On-Track %]
FROM flag f
JOIN Person p ON p.personID = f.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY f.schoolName, f.onTrack, i.lastName, i.firstName;
