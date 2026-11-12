/* ======================================================================================
   #81  IEP / evaluation due dates
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      List · Priority 1 · Run Weekly
   Purpose:   Active students whose latest locked IEP ends, or whose re-evaluation falls
              due, within @days days or has already passed, with their case manager.
   Output:    One row per student: school, grade, IEP start and end, days until IEP end,
              last evaluation, re-evaluation due, days until re-evaluation, case manager,
              what is due (negative days = overdue)
   Tables:    SchoolYear, Enrollment, Calendar, School, Plan, PlanType, Evaluation,
              SpecialEDState, v_CurrentCaseManager, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @days, @reevalYears, @planNameLike  (change
              them in the PARAMETERS block below)
   Check:     The IEP end date is used as the annual review date. Re-evaluation due is
              @reevalYears years after the student's latest locked evaluation of any
              type (Evaluation.date); confirm that is how your district dates them.
              Students whose latest special ed status record has ended or exited are
              left out. IEPs are locked plans in the special ed module; set
              @planNameLike if that module holds other plan types. Case managers come
              from IC's v_CurrentCaseManager view (as of today).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int  = NULL;   -- NULL = all schools
DECLARE @asOf         date = CONVERT(date, GETDATE());
DECLARE @days         int  = 60;     -- look-ahead window in days (30 or 60); overdue is always listed
DECLARE @reevalYears  int  = 3;      -- years between evaluations
DECLARE @planNameLike varchar(50) = '%';   -- plan type name filter, e.g. '%IEP%'; '%' = all special ed plan types
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
iep AS (   -- locked special ed plans started by @asOf, newest first per student (current or expired)
    SELECT pl.personID, pl.startDate, pl.endDate,
           ROW_NUMBER() OVER (PARTITION BY pl.personID ORDER BY pl.startDate DESC, pl.planID DESC) AS rn
    FROM [Plan] pl
    JOIN PlanType pt ON pt.typeID = pl.typeID
    WHERE pt.module = 'specialEd' AND pt.name LIKE @planNameLike
      AND pl.locked = 1
      AND pl.startDate <= @asOf
),
lastEval AS (   -- latest locked evaluation per student, and when the next one is due
    SELECT ev.personID, MAX(ev.date) AS evalDate, DATEADD(year, @reevalYears, MAX(ev.date)) AS reevalDue
    FROM Evaluation ev
    WHERE ev.locked = 1 AND ev.date <= @asOf
    GROUP BY ev.personID
),
spedState AS (   -- special ed status records, newest first per student
    SELECT ss.personID, ss.endDate, ss.exitDate,
           ROW_NUMBER() OVER (PARTITION BY ss.personID ORDER BY ss.startDate DESC, ss.specialEDStateID DESC) AS rn
    FROM SpecialEDState ss
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       CONVERT(date, ie.startDate) AS [IEP Start], CONVERT(date, ie.endDate) AS [IEP End],
       DATEDIFF(day, @asOf, ie.endDate) AS [Days Until IEP End],
       CONVERT(date, le.evalDate) AS [Last Evaluation], CONVERT(date, le.reevalDue) AS [Re-evaluation Due],
       DATEDIFF(day, @asOf, le.reevalDue) AS [Days Until Re-evaluation],
       cm.names AS [Case Manager],
       CONCAT_WS('; ',
           CASE WHEN ie.endDate < @asOf                       THEN 'IEP overdue'
                WHEN ie.endDate <= DATEADD(day, @days, @asOf) THEN 'IEP due' END,
           CASE WHEN le.reevalDue < @asOf                       THEN 'Re-evaluation overdue'
                WHEN le.reevalDue <= DATEADD(day, @days, @asOf) THEN 'Re-evaluation due' END) AS [What Is Due]
FROM act a
JOIN iep ie           ON ie.personID  = a.personID AND ie.rn = 1
JOIN Person p         ON p.personID   = a.personID
JOIN [Identity] i     ON i.identityID = p.currentIdentityID
LEFT JOIN lastEval le ON le.personID  = a.personID
OUTER APPLY (SELECT STRING_AGG(c.lastName + ', ' + c.firstName, '; ') AS names
             FROM v_CurrentCaseManager c
             WHERE c.studentPersonID = a.personID) cm
WHERE a.rn = 1
  AND (ie.endDate <= DATEADD(day, @days, @asOf) OR le.reevalDue <= DATEADD(day, @days, @asOf))
  AND NOT EXISTS (SELECT 1 FROM spedState st
                  WHERE st.personID = a.personID AND st.rn = 1
                    AND (st.exitDate <= @asOf OR st.endDate < @asOf))
ORDER BY a.schoolName,
         CASE WHEN ie.endDate < le.reevalDue OR le.reevalDue IS NULL THEN ie.endDate ELSE le.reevalDue END,
         i.lastName, i.firstName;
