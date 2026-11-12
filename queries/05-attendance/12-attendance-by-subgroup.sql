/* ======================================================================================
   #64  Attendance by subgroup
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Attendance
   Type:      KPI · Priority 2 · Run Monthly
   Purpose:   Attendance rate by school and grade, for all students and broken out by
              race/ethnicity, gender, special ed and EL.
   Output:    One row per school, grade and subgroup: students, days enrolled, days
              present, attendance rate
   Tables:    SchoolYear, Enrollment, Calendar, School, Day, v_AttDayDetail_Exact, Person,
              Identity, SpecialEDState, Lep
   Params:    @endYear, @schoolID, @startDate, @endDate, @elStatus  (change them in the
              PARAMETERS block below)
   Check:     Low income is not included: POSEligibility is empty in this district and no
              other low-income source was found. The rate is days present / days enrolled,
              where each absence counts as the share of the day missed (absentDay in
              v_AttDayDetail_Exact); it is not built from AttDayAggregation minutes
              because scheduledMinutes is filled on few rows here. Special ed = a
              SpecialEDState record open on @endDate (Enrollment.specialEdStatus is
              blank here); EL = Lep programStatus equal to @elStatus, not exited by
              @endDate. Race uses the federal code on the current identity. Small groups
              can identify students, so mind who sees the output.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @startDate date = (SELECT MIN(startDate) FROM Calendar WHERE endYear = @endYear AND exclude = 0 AND summerSchool = 0);   -- first day to count (earliest calendar start)
DECLARE @endDate   date = CONVERT(date, GETDATE());            -- last day to count
DECLARE @elStatus  varchar(15) = 'LEP';                        -- program status code that means the student is an English learner
-- ===========================================================================

WITH enrDays AS (   -- per primary enrollment: instructional days enrolled in the range and days absent (partial days as fractions)
    SELECT e.enrollmentID, e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           COUNT(*) AS daysEnrolled,
           SUM(ISNULL(a.absentDay, 0)) AS daysAbsent
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Day d      ON d.calendarID = e.calendarID AND d.structureID = e.structureID
                   AND d.instruction = 1 AND d.attendance = 1
                   AND d.date >= e.startDate AND (e.endDate IS NULL OR d.date <= e.endDate)
                   AND d.date >= @startDate AND d.date <= @endDate
    LEFT JOIN v_AttDayDetail_Exact a
           ON a.personID = e.personID AND a.calendarID = e.calendarID AND a.date = d.date
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
    GROUP BY e.enrollmentID, e.personID, c.schoolID, s.name, c.endYear, e.grade
),
stu AS (   -- adds each student's subgroup values
    SELECT ed.personID, ed.schoolID, ed.schoolName, ed.endYear, ed.grade, ed.daysEnrolled, ed.daysAbsent,
           CASE CONVERT(varchar(20), i.raceEthnicityFed)
                WHEN '1' THEN 'Hispanic/Latino'
                WHEN '2' THEN 'American Indian or Alaska Native'
                WHEN '3' THEN 'Asian'
                WHEN '4' THEN 'Black or African American'
                WHEN '5' THEN 'Native Hawaiian or Other Pacific Islander'
                WHEN '6' THEN 'White'
                WHEN '7' THEN 'Two or more races'
                ELSE 'Not reported' END AS race,
           COALESCE(NULLIF(LTRIM(RTRIM(i.gender)), ''), 'Not reported') AS gender,
           CASE WHEN EXISTS (SELECT 1 FROM SpecialEDState se
                             WHERE se.personID = ed.personID
                               AND (se.startDate IS NULL OR se.startDate <= @endDate)
                               AND (se.endDate   IS NULL OR se.endDate   >= @endDate)
                               AND (se.exitDate  IS NULL OR se.exitDate  >= @endDate))
                THEN 'Yes' ELSE 'No' END AS sped,
           CASE WHEN EXISTS (SELECT 1 FROM Lep l
                             WHERE l.personID = ed.personID AND l.programStatus = @elStatus
                               AND (l.exitDate IS NULL OR l.exitDate >= @endDate))
                THEN 'Yes' ELSE 'No' END AS el
    FROM enrDays ed
    JOIN Person p     ON p.personID   = ed.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
)
SELECT st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year],
       st.grade AS [Grade],
       g.subgroupType AS [Subgroup Type], g.subgroup AS [Subgroup],
       COUNT(DISTINCT st.personID) AS [Students],
       SUM(st.daysEnrolled) AS [Days Enrolled],
       CAST(SUM(st.daysEnrolled) - SUM(st.daysAbsent) AS decimal(12,1)) AS [Days Present],
       CAST(100.0 * (SUM(st.daysEnrolled) - SUM(st.daysAbsent))
            / SUM(st.daysEnrolled) AS decimal(5,1)) AS [Attendance Rate %]
FROM stu st
CROSS APPLY (VALUES ('All students',   'All'),
                    ('Race/Ethnicity', st.race),
                    ('Gender',         st.gender),
                    ('Special Ed',     st.sped),
                    ('EL',             st.el)) g(subgroupType, subgroup)
GROUP BY st.schoolID, st.schoolName, st.endYear, st.grade, g.subgroupType, g.subgroup
ORDER BY st.schoolName, st.grade, g.subgroupType, g.subgroup;
