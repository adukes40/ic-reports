/* ======================================================================================
   #140  Chronic absence by school + student list
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  CampusView KPIs
   Type:      KPI · Run Monthly
   Purpose:   Per student per school, instructional days enrolled and full-day absences from
              Oct 1 to May 20, flagged chronic when absences are 10% or more of the
              student's own days. School and district totals ride along on every row.
   Output:    One row per student per school: grade, days enrolled, full-day absences, %
              absent, chronic flag, school chronic count / students / %, the student's
              district-wide days, absences and flag, district chronic count / students / %
   Tables:    SchoolYear, Calendar, School, Day, Enrollment, v_AttDayDetail_Exact, Person,
              Identity
   Params:    @endYear, @schoolID, @asOf, @winStart, @winEnd  (change them in the PARAMETERS
              block below)
   Check:     The district count is built per student across all their schools, so it will
              not equal the sum of the school counts; leave @schoolID NULL to get it. A
              full-day absence is absentDay = 1 in v_AttDayDetail_Exact. Before May 20 the
              window stops at @asOf. Students enrolled only a few days are included.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());            -- days after this are not counted
DECLARE @winStart date = DATEFROMPARTS(@endYear - 1, 10, 1);  -- window start: Oct 1
DECLARE @winEnd   date = DATEFROMPARTS(@endYear, 5, 20);      -- window end: May 20
-- ===========================================================================

WITH cal AS (   -- this year's calendars
    SELECT c.calendarID, c.schoolID, s.name AS schoolName, c.endYear
    FROM Calendar c
    JOIN School s ON s.schoolID = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
),
perSchool AS (   -- per student per school: in-window instructional days enrolled and full-day absences
    SELECT e.personID, cal.schoolID, cal.schoolName, cal.endYear,
           COUNT(DISTINCT d.date) AS daysEnrolled,
           COUNT(DISTINCT CASE WHEN a.absentDay >= 1 THEN d.date END) AS daysAbsent
    FROM cal
    JOIN Day d ON d.calendarID = cal.calendarID
              AND d.instruction = 1 AND d.attendance = 1
              AND d.date >= @winStart AND d.date <= @winEnd AND d.date <= @asOf
    JOIN Enrollment e ON e.calendarID = d.calendarID AND e.structureID = d.structureID
                     AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
                     AND e.startDate <= d.date
                     AND (e.endDate IS NULL OR e.endDate >= d.date)
    LEFT JOIN v_AttDayDetail_Exact a
           ON a.personID = e.personID AND a.calendarID = e.calendarID AND a.date = d.date
    GROUP BY e.personID, cal.schoolID, cal.schoolName, cal.endYear
),
withPerson AS (   -- adds each student's totals across all schools; firstRow marks one row per student
    SELECT ps.*,
           SUM(ps.daysEnrolled) OVER (PARTITION BY ps.personID) AS personDays,
           SUM(ps.daysAbsent)   OVER (PARTITION BY ps.personID) AS personAbsent,
           ROW_NUMBER() OVER (PARTITION BY ps.personID ORDER BY ps.schoolID) AS firstRow
    FROM perSchool ps
),
flagged AS (   -- chronic = absences are at least 10% of the student's own days
    SELECT w.*,
           CASE WHEN w.daysAbsent   * 10 >= w.daysEnrolled THEN 1 ELSE 0 END AS chronicSchool,
           CASE WHEN w.personAbsent * 10 >= w.personDays   THEN 1 ELSE 0 END AS chronicDistrict
    FROM withPerson w
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       f.schoolID AS [School ID], f.schoolName AS [School], f.endYear AS [School Year], g.grade AS [Grade],
       f.daysEnrolled AS [Days Enrolled], f.daysAbsent AS [Full-Day Absences],
       CAST(100.0 * f.daysAbsent / f.daysEnrolled AS decimal(5,1)) AS [Percent Absent],
       CASE f.chronicSchool WHEN 1 THEN 'Y' ELSE 'N' END AS [Chronic at This School],
       SUM(f.chronicSchool) OVER (PARTITION BY f.schoolID) AS [School Chronic Students],
       COUNT(*)             OVER (PARTITION BY f.schoolID) AS [School Students],
       CAST(100.0 * SUM(f.chronicSchool) OVER (PARTITION BY f.schoolID)
            / COUNT(*) OVER (PARTITION BY f.schoolID) AS decimal(5,1)) AS [School Chronic %],
       f.personDays AS [District Days Enrolled], f.personAbsent AS [District Full-Day Absences],
       CASE f.chronicDistrict WHEN 1 THEN 'Y' ELSE 'N' END AS [Chronic District-Wide],
       SUM(CASE WHEN f.firstRow = 1 THEN f.chronicDistrict ELSE 0 END) OVER () AS [District Chronic Students],
       SUM(CASE WHEN f.firstRow = 1 THEN 1 ELSE 0 END) OVER ()                 AS [District Students],
       CAST(100.0 * SUM(CASE WHEN f.firstRow = 1 THEN f.chronicDistrict ELSE 0 END) OVER ()
            / SUM(CASE WHEN f.firstRow = 1 THEN 1 ELSE 0 END) OVER () AS decimal(5,1)) AS [District Chronic %]
FROM flagged f
JOIN Person p     ON p.personID   = f.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 e.grade             -- latest primary enrollment at that school this year
             FROM Enrollment e
             JOIN Calendar ec ON ec.calendarID = e.calendarID
             WHERE e.personID = f.personID
               AND ec.schoolID = f.schoolID AND ec.endYear = f.endYear
               AND e.serviceType = 'P'
             ORDER BY e.startDate DESC) g
ORDER BY f.schoolName, f.chronicSchool DESC, [Percent Absent] DESC, i.lastName, i.firstName;
