/* ======================================================================================
   #102  Exclusionary discipline days
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      KPI · Priority 2 · Run Monthly
   Purpose:   Per school and subgroup, the out-of-school suspension and expulsion days
              assigned this year and the number of students affected.
   Output:    One row per school per group: group type, group, students enrolled, students
              with OSS, OSS days, students expelled, expulsion days, total days, days per
              100 students
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, Lep,
              SpecialEDState, BehaviorResolution, BehaviorResType, BehaviorRole, Day
   Params:    @endYear, @schoolID, @asOf, @ossPattern ('%out%susp%'), @expPattern
              ('%expul%')  (change them in the PARAMETERS block below)
   Check:     OSS and expulsion are found by resolution type name matching the two
              patterns; confirm against your resolution type list (a type named only 'OSS'
              needs @ossPattern changed). Days = the resolution's School Days Duration when
              filled, otherwise the instructional days in the calendar from its start date
              to its end date; a resolution with no end date counts 0 days. Enrolled = every
              student with a primary enrollment at the school this year up to @asOf. Race
              uses IC's federal codes 1-7. EL = Lep record with status 'LEP' on @asOf;
              special education = eligible SpecialEDState record open on @asOf. Small
              groups can identify students: suppress before sharing.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int  = NULL;   -- NULL = all schools
DECLARE @asOf       date = CONVERT(date, GETDATE());   -- EL and special ed status are taken on this date
DECLARE @ossPattern varchar(30) = '%out%susp%';        -- resolution type names counted as out-of-school suspension
DECLARE @expPattern varchar(30) = '%expul%';           -- resolution type names counted as expulsion
-- ===========================================================================

WITH enr AS (   -- primary enrollments this year, latest per student per school numbered 1
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID, c.schoolID
                              ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf
),
res AS (   -- one row per OSS or expulsion resolution this year with its length in school days
    SELECT br.personID, c.schoolID,
           CASE WHEN rt.name LIKE @expPattern THEN 'EXP' ELSE 'OSS' END AS kind,
           COALESCE(r.schoolDaysDuration, d.days, 0) AS days
    FROM BehaviorResolution r
    JOIN BehaviorResType rt ON rt.typeID = r.typeID
    JOIN BehaviorRole br    ON br.roleID = r.roleID
    JOIN Calendar c ON c.calendarID = r.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    OUTER APPLY (SELECT COUNT(DISTINCT dy.date) AS days
                 FROM Day dy
                 WHERE dy.calendarID = r.calendarID AND dy.instruction = 1
                   AND dy.date >= CONVERT(date, r.timestamp)
                   AND dy.date <= CONVERT(date, r.endDate)) d
    WHERE (rt.name LIKE @ossPattern OR rt.name LIKE @expPattern)
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
stu AS (   -- one row per enrolled student per school with subgroup values and days removed
    SELECT e.personID, e.schoolID, e.schoolName, e.endYear,
           COALESCE(NULLIF(LTRIM(RTRIM(e.grade)), ''), '(blank)') AS grade,
           COALESCE(NULLIF(LTRIM(RTRIM(i.gender)), ''), '(blank)') AS gender,
           CASE LTRIM(RTRIM(i.raceEthnicityFed))
                WHEN '1' THEN 'Hispanic/Latino'
                WHEN '2' THEN 'American Indian or Alaska Native'
                WHEN '3' THEN 'Asian'
                WHEN '4' THEN 'Black or African American'
                WHEN '5' THEN 'Native Hawaiian or Other Pacific Islander'
                WHEN '6' THEN 'White'
                WHEN '7' THEN 'Two or more races'
                ELSE COALESCE(NULLIF(LTRIM(RTRIM(i.raceEthnicityFed)), ''), '(blank)') END AS race,
           COALESCE(NULLIF(LTRIM(RTRIM(i.hispanicEthnicity)), ''), '(blank)') AS hispanic,
           CASE WHEN EXISTS (SELECT 1 FROM Lep l
                             WHERE l.personID = e.personID AND l.programStatus = 'LEP'
                               AND l.identifiedDate <= @asOf
                               AND (l.exitDate IS NULL OR l.exitDate >= @asOf))
                THEN 'Y' ELSE 'N' END AS el,
           CASE WHEN EXISTS (SELECT 1 FROM SpecialEDState se
                             WHERE se.personID = e.personID AND se.eligible = 1
                               AND (se.startDate IS NULL OR se.startDate <= @asOf)
                               AND (se.endDate  IS NULL OR se.endDate  >= @asOf)
                               AND (se.exitDate IS NULL OR se.exitDate >= @asOf))
                THEN 'Y' ELSE 'N' END AS sped,
           ISNULL(x.ossCount, 0) AS ossCount, ISNULL(x.ossDays, 0) AS ossDays,
           ISNULL(x.expCount, 0) AS expCount, ISNULL(x.expDays, 0) AS expDays
    FROM enr e
    JOIN Person p     ON p.personID   = e.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    OUTER APPLY (SELECT SUM(CASE WHEN r.kind = 'OSS' THEN 1 ELSE 0 END)      AS ossCount,
                        SUM(CASE WHEN r.kind = 'OSS' THEN r.days ELSE 0 END) AS ossDays,
                        SUM(CASE WHEN r.kind = 'EXP' THEN 1 ELSE 0 END)      AS expCount,
                        SUM(CASE WHEN r.kind = 'EXP' THEN r.days ELSE 0 END) AS expDays
                 FROM res r
                 WHERE r.personID = e.personID AND r.schoolID = e.schoolID) x
    WHERE e.rn = 1
),
grp AS (   -- each student listed once under every group they belong to
    SELECT st.schoolID, st.schoolName, st.endYear, x.sortOrder, x.groupType, x.groupValue,
           st.ossCount, st.ossDays, st.expCount, st.expDays
    FROM stu st
    CROSS APPLY (VALUES
        (1, 'All students',      'All students'),
        (2, 'Race/ethnicity',    st.race),
        (3, 'Hispanic/Latino',   st.hispanic),
        (4, 'Gender',            st.gender),
        (5, 'Grade',             st.grade),
        (6, 'English learner',   st.el),
        (7, 'Special education', st.sped)
    ) x(sortOrder, groupType, groupValue)
)
SELECT g.schoolID AS [School ID], g.schoolName AS [School], g.endYear AS [School Year],
       g.groupType AS [Group Type], g.groupValue AS [Group],
       COUNT(*) AS [Students Enrolled],
       SUM(CASE WHEN g.ossCount > 0 THEN 1 ELSE 0 END) AS [Students With OSS],
       CAST(SUM(g.ossDays) AS decimal(9,1)) AS [OSS Days],
       SUM(CASE WHEN g.expCount > 0 THEN 1 ELSE 0 END) AS [Students Expelled],
       CAST(SUM(g.expDays) AS decimal(9,1)) AS [Expulsion Days],
       CAST(SUM(g.ossDays + g.expDays) AS decimal(9,1)) AS [Total Days],
       CAST(100.0 * SUM(g.ossDays + g.expDays) / NULLIF(COUNT(*), 0) AS decimal(9,1)) AS [Days per 100 Students]
FROM grp g
GROUP BY g.schoolID, g.schoolName, g.endYear, g.sortOrder, g.groupType, g.groupValue
ORDER BY g.schoolName, g.sortOrder, g.groupValue;
