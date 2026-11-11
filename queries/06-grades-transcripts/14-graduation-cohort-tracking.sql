/* ======================================================================================
   #78  Graduation cohort tracking
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Grades, transcripts & graduation
   Type:      KPI · Priority 2 · Run Ongoing
   Purpose:   Every student in the chosen graduation cohorts with a status (graduated in
              4, 5 or 6 years, still enrolled, left) and the counts and 4-year rate for
              their cohort and school.
   Output:    One row per student: cohort year, status, diploma date and type, last
              enrollment end date and end status, cohort counts by status, 4-year rate %
   Tables:    SchoolYear, Graduation, Enrollment, Calendar, School,
              EnrollmentEndStatusType, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @cohortYears, @lastGradMonth  (change them in
              the PARAMETERS block below)
   Check:     Cohort year is taken from the Graduation tab (Cohort Year NCLB, else Cohort
              Year NGA) and is read as the year the student is due to graduate; students
              with neither are left out. Graduated = a diploma date on the Graduation
              tab; a diploma dated through @lastGradMonth (August) counts in that school
              year. Students
              are counted at the school of their latest enrollment. "Left" includes
              transfers out, which the state removes from the cohort: use Last End
              Status to separate them, so this rate will not equal the published DDOE
              rate. Run it during the school year; over the summer unfinished students
              show as Left.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int          = NULL;   -- NULL = all schools
DECLARE @asOf          date         = CONVERT(date, GETDATE());
DECLARE @cohortYears   varchar(100) = NULL;   -- cohort years, e.g. '2024,2025'; NULL = this year and the two before
DECLARE @lastGradMonth int          = 8;      -- last month a summer diploma still counts in the school year just ended (8 = August)
-- ===========================================================================

WITH grad AS (   -- one graduation record per student in the chosen cohorts
    SELECT g.personID, x.cohortYear, g.diplomaDate, g.diplomaType,
           YEAR(DATEADD(month, 12 - @lastGradMonth, g.diplomaDate)) AS diplomaYear,   -- school year ending after the diploma date
           ROW_NUMBER() OVER (PARTITION BY g.personID ORDER BY g.graduationID DESC) AS rn
    FROM Graduation g
    CROSS APPLY (SELECT TRY_CONVERT(int, COALESCE(NULLIF(LTRIM(RTRIM(g.cohortYearNCLB)), ''),
                                                  NULLIF(LTRIM(RTRIM(g.cohortYearNGA)), ''))) AS cohortYear) x
    WHERE (@cohortYears IS NULL AND x.cohortYear BETWEEN @endYear - 2 AND @endYear)
       OR CHARINDEX(',' + CAST(x.cohortYear AS varchar(10)) + ',', ',' + REPLACE(@cohortYears, ' ', '') + ',') > 0
),
enr AS (   -- latest primary enrollment per cohort student, any year
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade, e.endDate,
           e.endStatus, est.name AS endStatusName,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    LEFT JOIN EnrollmentEndStatusType est ON est.typeID = e.localEndStatusTypeID
    WHERE e.personID IN (SELECT personID FROM grad)
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
),
st AS (   -- one row per cohort student with a status
    SELECT g.personID, g.cohortYear, g.diplomaDate, g.diplomaType,
           en.schoolID, en.schoolName, en.endYear, en.grade, en.endDate, en.endStatus, en.endStatusName,
           CASE WHEN g.diplomaDate IS NOT NULL AND g.diplomaYear <= g.cohortYear     THEN 'Graduated in 4 years'
                WHEN g.diplomaDate IS NOT NULL AND g.diplomaYear  = g.cohortYear + 1 THEN 'Graduated in 5 years'
                WHEN g.diplomaDate IS NOT NULL AND g.diplomaYear  = g.cohortYear + 2 THEN 'Graduated in 6 years'
                WHEN g.diplomaDate IS NOT NULL                                       THEN 'Graduated after 6 years'
                WHEN en.endDate IS NULL OR en.endDate >= @asOf                       THEN 'Still enrolled'
                ELSE 'Left' END AS status
    FROM grad g
    JOIN enr en ON en.personID = g.personID AND en.rn = 1
    WHERE g.rn = 1
      AND (@schoolID IS NULL OR en.schoolID = @schoolID)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year], st.grade AS [Grade],
       st.cohortYear AS [Cohort Year], st.status AS [Status],
       CONVERT(date, st.diplomaDate) AS [Diploma Date], st.diplomaType AS [Diploma Type],
       CONVERT(date, st.endDate) AS [Last Enrollment End], st.endStatus AS [Last End Status],
       st.endStatusName AS [Last End Status Name],
       COUNT(*) OVER (PARTITION BY st.cohortYear, st.schoolID) AS [Cohort Students],   -- denominator
       SUM(CASE WHEN st.status = 'Graduated in 4 years' THEN 1 ELSE 0 END) OVER (PARTITION BY st.cohortYear, st.schoolID) AS [Graduated In 4],   -- numerator
       SUM(CASE WHEN st.status = 'Graduated in 5 years' THEN 1 ELSE 0 END) OVER (PARTITION BY st.cohortYear, st.schoolID) AS [Graduated In 5],
       SUM(CASE WHEN st.status = 'Graduated in 6 years' THEN 1 ELSE 0 END) OVER (PARTITION BY st.cohortYear, st.schoolID) AS [Graduated In 6],
       SUM(CASE WHEN st.status = 'Still enrolled'       THEN 1 ELSE 0 END) OVER (PARTITION BY st.cohortYear, st.schoolID) AS [Still Enrolled],
       SUM(CASE WHEN st.status = 'Left'                 THEN 1 ELSE 0 END) OVER (PARTITION BY st.cohortYear, st.schoolID) AS [Left],
       CAST(100.0 * SUM(CASE WHEN st.status = 'Graduated in 4 years' THEN 1 ELSE 0 END) OVER (PARTITION BY st.cohortYear, st.schoolID)
            / COUNT(*) OVER (PARTITION BY st.cohortYear, st.schoolID) AS decimal(5,1)) AS [4-Year Rate %]
FROM st
JOIN Person p     ON p.personID   = st.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
ORDER BY st.cohortYear, st.schoolName, st.status, i.lastName, i.firstName;
