/* ======================================================================================
   #73  Duplicate / invalid stored grades
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      Validation · Priority 2 · Run EOY
   Purpose:   Transcript rows posted more than once for the same student, course, term and
              year, and transcript rows with a blank or unrecognised mark.
   Output:    One row per transcript row and problem: transcript year, term, school on the
              transcript, course, mark, credits earned, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, TranscriptCourse, TranscriptCredit,
              ScoreListItem, Person, Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Covers students enrolled at any time in @endYear, all transcript years.
              Term is TranscriptCourse.actualTerm. A mark is "unrecognised" when it is
              not a number and is not in any of your score groups, so marks brought in
              from other districts can show up. A repeated course in a different term or
              year is not a duplicate.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
-- ===========================================================================

WITH stu AS (   -- latest primary enrollment in @endYear per student
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
),
rws AS (   -- these students' transcript rows, with how many share the same course, term and year
    SELECT tc.transcriptID, tc.personID, tc.endYear, tc.actualTerm, tc.schoolName AS transcriptSchool,
           tc.courseNumber, tc.courseName, NULLIF(LTRIM(RTRIM(tc.score)), '') AS mark,
           COUNT(*) OVER (PARTITION BY tc.personID, tc.courseNumber, tc.endYear, tc.actualTerm) AS copies
    FROM TranscriptCourse tc
    WHERE tc.personID IN (SELECT personID FROM stu WHERE rn = 1)
),
probs AS (   -- one row per transcript row and problem
    SELECT r.*, 'Posted ' + CAST(r.copies AS varchar(10)) + ' times for the same course, term and year' AS issue
    FROM rws r
    WHERE r.copies > 1
    UNION ALL
    SELECT r.*, 'Blank mark'
    FROM rws r
    WHERE r.mark IS NULL
    UNION ALL
    SELECT r.*, 'Mark is not a number and not in any score group'
    FROM rws r
    WHERE r.mark IS NOT NULL
      AND TRY_CONVERT(decimal(9,2), r.mark) IS NULL
      AND NOT EXISTS (SELECT 1 FROM ScoreListItem sli WHERE sli.score = r.mark)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year], st.grade AS [Grade],
       pr.endYear AS [Transcript Year], pr.actualTerm AS [Transcript Term], pr.transcriptSchool AS [Transcript School],
       pr.courseNumber AS [Course Number], pr.courseName AS [Course], pr.mark AS [Mark],
       (SELECT SUM(tcr.creditsEarned) FROM TranscriptCredit tcr
        WHERE tcr.transcriptID = pr.transcriptID) AS [Credits Earned],
       pr.issue AS [Issue]
FROM probs pr
JOIN stu st       ON st.personID  = pr.personID AND st.rn = 1
JOIN Person p     ON p.personID   = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY st.schoolName, i.lastName, i.firstName, pr.endYear, pr.courseNumber, pr.actualTerm;
