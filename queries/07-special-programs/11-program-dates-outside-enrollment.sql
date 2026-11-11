/* ======================================================================================
   #89  Program dates outside enrollment
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Program participation records in effect this school year whose start or end
              date does not fall inside any enrollment the student has in the district.
   Output:    One row per problem: school, grade, program, program start and end, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, ProgramParticipation, Program,
              Person, Identity
   Params:    @endYear, @schoolID, @yearStart, @yearEnd  (change them in the PARAMETERS
              block below)
   Check:     The school year is taken as July 1 to June 30 (@yearStart, @yearEnd). Every
              enrollment in any year counts except no-shows, so a program dated in the
              summer between two enrollments will be listed. Programs have no grade range
              in IC, so a grade the program does not serve is not checked.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @yearStart date = DATEFROMPARTS(@endYear - 1, 7, 1);   -- first day of the school year
DECLARE @yearEnd   date = DATEFROMPARTS(@endYear, 6, 30);      -- last day of the school year
-- ===========================================================================

WITH stu AS (   -- latest primary enrollment per student this year, active or ended
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
part AS (   -- program participation records in effect at some point this school year
    SELECT pp.personID, pr.name AS program, pp.startDate, pp.endDate
    FROM ProgramParticipation pp
    JOIN Program pr ON pr.programID = pp.programID
    WHERE pp.startDate <= @yearEnd
      AND (pp.endDate IS NULL OR pp.endDate >= @yearStart)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year], st.grade AS [Grade],
       pt.program AS [Program],
       CONVERT(date, pt.startDate) AS [Program Start], CONVERT(date, pt.endDate) AS [Program End],
       x.issue AS [Issue]
FROM stu st
JOIN part pt      ON pt.personID  = st.personID
JOIN Person p     ON p.personID   = st.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NOT EXISTS (SELECT 1 FROM Enrollment e
                           WHERE e.personID = pt.personID AND ISNULL(e.noShow, 0) = 0
                             AND e.startDate <= pt.startDate
                             AND (e.endDate IS NULL OR e.endDate >= pt.startDate))
          THEN 'Program start date is outside every enrollment' END),
    (CASE WHEN pt.endDate IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM Enrollment e
                           WHERE e.personID = pt.personID AND ISNULL(e.noShow, 0) = 0
                             AND e.startDate <= pt.endDate
                             AND (e.endDate IS NULL OR e.endDate >= pt.endDate))
          THEN 'Program end date is outside every enrollment' END)
) x(issue)
WHERE st.rn = 1
  AND x.issue IS NOT NULL
ORDER BY st.schoolName, pt.program, st.grade, i.lastName, i.firstName;
