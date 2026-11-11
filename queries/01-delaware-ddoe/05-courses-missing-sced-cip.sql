/* ======================================================================================
   #5  Courses missing SCED or CIP codes
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      Validation · Priority 1 · Run BOY, semester
   Purpose:   Active courses with students rostered today but no SCED code, and CTE courses
              with no CIP code.
   Output:    One row per problem course: school, course number and name, students rostered,
              current codes, issue
   Tables:    Calendar, School, Course, Section, Trial, Roster
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     A course counts as CTE when its SCED subject area is 10 to 21 (the career
              and technical areas); change the list in the query if your CTE courses are
              coded differently. A blank SCED passes if Course.stateCode is filled.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH crs AS (
    SELECT co.courseID, co.number AS courseNumber, co.name AS courseName,
           co.stateCode, co.scedSubjectArea, co.scedCourseId, co.cipCode,
           c.schoolID, s.name AS schoolName, c.endYear,
           (SELECT COUNT(DISTINCT r.personID)
              FROM Section se
              JOIN Trial t  ON t.trialID = se.trialID AND t.active = 1
              JOIN Roster r ON r.sectionID = se.sectionID AND r.trialID = t.trialID
             WHERE se.courseID = co.courseID
               AND (r.startDate IS NULL OR r.startDate <= @asOf)
               AND (r.endDate IS NULL OR r.endDate >= @asOf)) AS studentCount
    FROM Course co
    JOIN Calendar c ON c.calendarID = co.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE co.active = 1
      AND co.stateReportExclude = 0
      AND c.endYear = @endYear
      AND c.exclude = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT crs.schoolID AS [School ID], crs.schoolName AS [School], crs.endYear AS [School Year],
       crs.courseNumber AS [Course Number], crs.courseName AS [Course Name], crs.studentCount AS [Student Count],
       crs.stateCode AS [State Code], crs.scedSubjectArea AS [SCED Subject Area], crs.scedCourseId AS [SCED Course ID], crs.cipCode AS [CIP Code],
       x.issue AS [Issue]
FROM crs
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(crs.scedCourseId)), '') IS NULL
           AND NULLIF(LTRIM(RTRIM(crs.stateCode)), '') IS NULL
          THEN 'No SCED course code' END),
    (CASE WHEN crs.scedSubjectArea IN ('10','11','12','13','14','15','16','17','18','19','20','21')   -- CTE subject areas
           AND NULLIF(LTRIM(RTRIM(crs.cipCode)), '') IS NULL
          THEN 'CTE course with no CIP code' END)
) x(issue)
WHERE x.issue IS NOT NULL
  AND crs.studentCount > 0
ORDER BY crs.schoolName, x.issue, crs.courseNumber;
