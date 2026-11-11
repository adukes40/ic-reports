/* ======================================================================================
   #72  Transcripts with no GPA
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      Validation · Priority 2 · Run EOY
   Purpose:   This year's transcript rows that should count toward GPA but cannot, and
              grade 9-12 students who have transcript rows but no cumulative GPA.
   Output:    One row per problem: transcript year, course, mark, GPA weight, GPA value,
              issue (course columns are blank on the student-level rows)
   Tables:    SchoolYear, Enrollment, Calendar, School, TranscriptCourse, Course, Person,
              Identity
   Params:    @endYear, @schoolID  (change them in the PARAMETERS block below)
   Check:     Covers students enrolled at any time in @endYear. The row checks look only
              at @endYear transcript rows; the student check looks at every year. A row
              "should carry GPA weight" when a course with the same number in @endYear has
              a GPA weight above 0. Cumulative GPA is not stored in a table here, so "no
              cumulative GPA" means no transcript row has both a GPA weight and a GPA
              value.
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
probs AS (   -- one row per problem
    SELECT st.personID, tc.endYear AS transcriptYear, tc.courseNumber, tc.courseName, tc.score,
           tc.gpaWeight, tc.gpaValue,
           CASE WHEN tc.gpaWeight > 0 THEN 'Has GPA weight but no GPA value'
                ELSE 'Course has GPA weight but this transcript row has none' END AS issue
    FROM stu st
    JOIN TranscriptCourse tc ON tc.personID = st.personID AND tc.endYear = @endYear
    WHERE st.rn = 1
      AND NULLIF(LTRIM(RTRIM(tc.score)), '') IS NOT NULL
      AND (   (tc.gpaWeight > 0 AND tc.gpaValue IS NULL)
           OR (ISNULL(tc.gpaWeight, 0) = 0
               AND EXISTS (SELECT 1 FROM Course co
                           JOIN Calendar cc ON cc.calendarID = co.calendarID
                           WHERE cc.endYear = tc.endYear AND co.number = tc.courseNumber
                             AND co.gpaWeight > 0)))
    UNION ALL
    SELECT st.personID, NULL, NULL, NULL, NULL, NULL, NULL,
           'Student has transcript rows but no cumulative GPA'
    FROM stu st
    WHERE st.rn = 1
      AND st.grade IN ('09', '10', '11', '12')
      AND EXISTS (SELECT 1 FROM TranscriptCourse tc WHERE tc.personID = st.personID)
      AND NOT EXISTS (SELECT 1 FROM TranscriptCourse tc
                      WHERE tc.personID = st.personID AND tc.gpaWeight > 0 AND tc.gpaValue IS NOT NULL)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year], st.grade AS [Grade],
       pr.transcriptYear AS [Transcript Year], pr.courseNumber AS [Course Number], pr.courseName AS [Course],
       pr.score AS [Mark], pr.gpaWeight AS [GPA Weight], pr.gpaValue AS [GPA Value],
       pr.issue AS [Issue]
FROM probs pr
JOIN stu st       ON st.personID  = pr.personID AND st.rn = 1
JOIN Person p     ON p.personID   = pr.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY st.schoolName, st.grade, i.lastName, i.firstName, pr.courseNumber;
