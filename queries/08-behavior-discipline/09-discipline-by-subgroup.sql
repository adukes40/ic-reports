/* ======================================================================================
   #101  Discipline by subgroup
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      KPI · Priority 1 · Run Monthly
   Purpose:   Per school, referrals and suspensions this year by race/ethnicity, Hispanic
              ethnicity, gender, grade, English learner, special education and incident
              type, with the students enrolled in each group as the denominator.
   Output:    One row per school per group: group type, group, students enrolled, students
              referred, referrals, referral rate, students suspended, suspensions,
              suspension rate
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, Lep,
              SpecialEDState, BehaviorEvent, BehaviorRole, BehaviorType, BehaviorResolution,
              BehaviorResType
   Params:    @endYear, @schoolID, @asOf, @suspPattern ('%susp%')  (change them in the
              PARAMETERS block below)
   Check:     A referral is an incident where the student's role is exactly 'Offender'.
              Suspensions are resolutions whose type name matches @suspPattern (in-school
              and out-of-school together); confirm against your resolution type list.
              Enrolled = every student with a primary enrollment at the school this year up
              to @asOf, so rates are per student ever enrolled. Race uses IC's federal codes
              1-7. EL = Lep record with status 'LEP' on @asOf; special education = eligible
              SpecialEDState record open on @asOf. Incident type rows use the whole school
              as the denominator. Small groups can identify students: suppress before
              sharing.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear     int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID    int  = NULL;   -- NULL = all schools
DECLARE @asOf        date = CONVERT(date, GETDATE());   -- EL and special ed status are taken on this date
DECLARE @suspPattern varchar(30) = '%susp%';            -- resolution type names counted as a suspension
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
refs AS (   -- one row per offender per event this year, with the suspensions given for it
    SELECT br.personID, c.schoolID, be.incidentID, be.eventID,
           COALESCE(bt.name, '(no event type)') AS eventType,
           (SELECT COUNT(*)
            FROM BehaviorResolution r
            JOIN BehaviorResType rt ON rt.typeID = r.typeID
            WHERE r.roleID = br.roleID AND rt.name LIKE @suspPattern) AS suspensions
    FROM BehaviorEvent be
    JOIN BehaviorRole br ON br.eventID = be.eventID
    JOIN Calendar c ON c.calendarID = be.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    LEFT JOIN BehaviorType bt ON bt.typeID = be.typeID
    WHERE br.role = 'Offender'   -- role counted as a referral
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
stu AS (   -- one row per enrolled student per school with subgroup values and discipline counts
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
           ISNULL(o.referrals, 0) AS referrals, ISNULL(o.suspensions, 0) AS suspensions
    FROM enr e
    JOIN Person p     ON p.personID   = e.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    OUTER APPLY (SELECT COUNT(DISTINCT f.incidentID) AS referrals, SUM(f.suspensions) AS suspensions
                 FROM refs f
                 WHERE f.personID = e.personID AND f.schoolID = e.schoolID) o
    WHERE e.rn = 1
),
grp AS (   -- each student listed once under every group they belong to
    SELECT st.schoolID, st.schoolName, st.endYear, x.sortOrder, x.groupType, x.groupValue,
           st.referrals, st.suspensions
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
),
result AS (   -- counts per school and group, then per school and incident type
    SELECT g.schoolID, g.schoolName, g.endYear, g.sortOrder, g.groupType, g.groupValue,
           COUNT(*) AS enrolled,
           SUM(CASE WHEN g.referrals   > 0 THEN 1 ELSE 0 END) AS studentsReferred,
           SUM(g.referrals) AS referrals,
           SUM(CASE WHEN g.suspensions > 0 THEN 1 ELSE 0 END) AS studentsSuspended,
           SUM(g.suspensions) AS suspensions
    FROM grp g
    GROUP BY g.schoolID, g.schoolName, g.endYear, g.sortOrder, g.groupType, g.groupValue

    UNION ALL

    SELECT st.schoolID, st.schoolName, st.endYear, 8, 'Incident type', f.eventType,
           (SELECT COUNT(*) FROM stu a WHERE a.schoolID = st.schoolID),
           COUNT(DISTINCT f.personID),
           COUNT(DISTINCT CAST(f.personID AS varchar(12)) + '-' + CAST(f.incidentID AS varchar(12))),
           COUNT(DISTINCT CASE WHEN f.suspensions > 0 THEN f.personID END),
           SUM(f.suspensions)
    FROM refs f
    JOIN stu st ON st.personID = f.personID AND st.schoolID = f.schoolID
    GROUP BY st.schoolID, st.schoolName, st.endYear, f.eventType
)
SELECT r.schoolID AS [School ID], r.schoolName AS [School], r.endYear AS [School Year],
       r.groupType AS [Group Type], r.groupValue AS [Group],
       r.enrolled AS [Students Enrolled],
       r.studentsReferred AS [Students Referred], r.referrals AS [Referrals],
       CAST(100.0 * r.studentsReferred / NULLIF(r.enrolled, 0) AS decimal(5,1)) AS [Referral Rate %],
       r.studentsSuspended AS [Students Suspended], r.suspensions AS [Suspensions],
       CAST(100.0 * r.studentsSuspended / NULLIF(r.enrolled, 0) AS decimal(5,1)) AS [Suspension Rate %]
FROM result r
ORDER BY r.schoolName, r.sortOrder, r.groupValue;
