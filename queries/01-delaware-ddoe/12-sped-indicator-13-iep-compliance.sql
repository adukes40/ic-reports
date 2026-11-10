/* ======================================================================================
   #12  SPED Indicator 13 / IEP compliance
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Delaware DOE
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Currently enrolled students whose latest locked IEP is past its end date, or
              who are transition age with no post-high-school goals.
   Output:    One row per problem: student, school, grade, age, SPED status, plan type, IEP
              start and end, issue
   Tables:    Calendar, School, Enrollment, Plan, PlanType,
              v_LearningPlanDetailPostHighSchoolDE, Person, Identity
   Params:    @endYear, @schoolID, @transitionAge (14), @asOf  (change them in the
              PARAMETERS block below)
   Check:     IEPs are found as specialEd plan types with type or name IEP. DE uses age 14
              for transition (federal is 16).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int = NULL;   -- NULL = all schools
DECLARE @transitionAge int = 14;
DECLARE @asOf          date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH stu AS (   -- current primary enrollments
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade, e.specialEdStatus,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P' AND e.stateExclude = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
iep AS (        -- latest locked IEP per student
    SELECT pl.personID, pl.planID, pl.startDate, pl.endDate, pt.name AS planType,
           ROW_NUMBER() OVER (PARTITION BY pl.personID ORDER BY pl.startDate DESC, pl.planID DESC) AS rn
    FROM [Plan] pl
    JOIN PlanType pt ON pt.typeID = pl.typeID
    WHERE pt.module = 'specialEd'
      AND (pt.type = 'IEP' OR pt.name LIKE '%IEP%')
      AND pl.locked = 1
      AND ISNULL(pl.archive, 0) = 0
),
cur AS (
    SELECT st.*, ie.planID, ie.startDate AS iepStart, ie.endDate AS iepEnd, ie.planType,
           DATEDIFF(year, i.birthdate, @asOf)
             - CASE WHEN DATEADD(year, DATEDIFF(year, i.birthdate, @asOf), i.birthdate) > @asOf THEN 1 ELSE 0 END AS age
    FROM stu st
    JOIN Person p ON p.personID = st.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    JOIN iep ie ON ie.personID = st.personID AND ie.rn = 1
    WHERE st.rn = 1
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       cur.schoolID AS [School ID], cur.schoolName AS [School], cur.endYear AS [School Year], cur.grade AS [Grade],
       cur.age AS [Age], cur.specialEdStatus AS [Special Ed Status], cur.planType AS [Plan Type],
       CONVERT(date, cur.iepStart) AS [IEP Start],
       CONVERT(date, cur.iepEnd)   AS [IEP End],
       x.issue AS [Issue]
FROM cur
JOIN Person p ON p.personID = cur.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN cur.iepEnd < @asOf THEN 'Latest IEP is past its end date' END),
    (CASE WHEN cur.age >= @transitionAge
           AND NOT EXISTS (SELECT 1 FROM v_LearningPlanDetailPostHighSchoolDE ph
                           WHERE ph.planID = cur.planID
                             AND (NULLIF(LTRIM(RTRIM(ph.postSchoolEmploymentGoal)), '') IS NOT NULL
                               OR NULLIF(LTRIM(RTRIM(ph.postSchoolEducationTrainingGoal)), '') IS NOT NULL))
          THEN 'Transition-age student with no post-high-school goals on IEP' END)
) x(issue)
WHERE x.issue IS NOT NULL
ORDER BY cur.schoolName, x.issue, i.lastName;
