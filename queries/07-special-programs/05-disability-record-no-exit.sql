/* ======================================================================================
   #83  Disability record with no exit
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 2 · Run EOY
   Purpose:   Students enrolled this year who have a primary disability on a locked IEP
              and whose special ed has ended (status record ended, or last IEP expired)
              but who have no special ed exit date.
   Output:    One row per student: school, grade, last IEP start and end, special ed
              record start and end, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Plan, PlanType, PlanState,
              SpecialEDState, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @planNameLike  (change them in the PARAMETERS
              block below)
   Check:     The primary disability is read from the IEP (PlanState.disability1) and the
              exit date from the state reporting record (SpecialEDState.exitDate); the
              enrollment disability and exit fields are not filled in. Only each
              student's newest IEP and newest status record are compared. Students whose
              IEP ended before state reporting records were kept will show as having no
              status record. Includes students who left during the year.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int  = NULL;   -- NULL = all schools
DECLARE @asOf         date = CONVERT(date, GETDATE());
DECLARE @planNameLike varchar(50) = '%';   -- plan type name filter, e.g. '%IEP%'; '%' = all special ed plan types
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
      AND e.startDate <= @asOf
),
lastPlan AS (   -- locked special ed plans carrying a primary disability, newest first per student
    SELECT pl.personID, pl.startDate, pl.endDate,
           ROW_NUMBER() OVER (PARTITION BY pl.personID ORDER BY pl.startDate DESC, pl.planID DESC) AS rn
    FROM [Plan] pl
    JOIN PlanType pt   ON pt.typeID  = pl.typeID
    JOIN PlanState pst ON pst.planID = pl.planID
    WHERE pt.module = 'specialEd' AND pt.name LIKE @planNameLike
      AND pl.locked = 1
      AND pl.startDate <= @asOf
      AND NULLIF(LTRIM(RTRIM(pst.disability1)), '') IS NOT NULL
),
spedState AS (   -- special ed status records, newest first per student
    SELECT ss.personID, ss.startDate, ss.endDate, ss.exitDate,
           ROW_NUMBER() OVER (PARTITION BY ss.personID ORDER BY ss.startDate DESC, ss.specialEDStateID DESC) AS rn
    FROM SpecialEDState ss
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year], st.grade AS [Grade],
       CONVERT(date, lp.startDate) AS [Last IEP Start], CONVERT(date, lp.endDate) AS [Last IEP End],
       ss.startDate AS [Special Ed Record Start], ss.endDate AS [Special Ed Record End],
       CASE WHEN ss.personID IS NULL THEN 'Primary disability on an expired IEP but no special ed status record'
            WHEN ss.endDate <= @asOf THEN 'Special ed status record ended with no exit date'
            ELSE 'IEP expired but the special ed status record is still open with no exit date' END AS [Issue]
FROM stu st
JOIN lastPlan lp       ON lp.personID  = st.personID AND lp.rn = 1
JOIN Person p          ON p.personID   = st.personID
JOIN [Identity] i      ON i.identityID = p.currentIdentityID
LEFT JOIN spedState ss ON ss.personID  = st.personID AND ss.rn = 1
WHERE st.rn = 1
  AND ss.exitDate IS NULL
  AND (ss.endDate <= @asOf OR lp.endDate < @asOf)
ORDER BY st.schoolName, [Issue], st.grade, i.lastName, i.firstName;
