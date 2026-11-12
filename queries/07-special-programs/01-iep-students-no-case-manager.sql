/* ======================================================================================
   #79  IEP students with no case manager
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Active students with a locked, current IEP and no current case manager on
              their team. Shows whether the plan itself still names one.
   Output:    One row per student: school, grade, plan type, IEP start and end, the case
              manager printed on the plan (if any), issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Plan, PlanType, PlanStudent,
              v_CurrentCaseManager, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @planNameLike  (change them in the PARAMETERS
              block below)
   Check:     IEPs are locked plans whose plan type is in the special ed module
              (PlanType.module = 'specialEd'); set @planNameLike if that module holds
              other plan types too. Team case managers come from IC's
              v_CurrentCaseManager view, which is always as of today and covers every
              module, so leave @asOf at today.
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
iep AS (   -- locked special ed plans current on @asOf, newest first per student
    SELECT pl.personID, pl.planID, pl.startDate, pl.endDate, pt.name AS planType,
           ROW_NUMBER() OVER (PARTITION BY pl.personID ORDER BY pl.startDate DESC, pl.planID DESC) AS rn
    FROM [Plan] pl
    JOIN PlanType pt ON pt.typeID = pl.typeID
    WHERE pt.module = 'specialEd' AND pt.name LIKE @planNameLike
      AND pl.locked = 1
      AND pl.startDate <= @asOf AND (pl.endDate IS NULL OR pl.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       ie.planType AS [Plan Type],
       CONVERT(date, ie.startDate) AS [IEP Start], CONVERT(date, ie.endDate) AS [IEP End],
       pcm.name AS [Case Manager On Plan],
       CASE WHEN pcm.name IS NULL THEN 'No case manager on the team or on the plan'
            ELSE 'No current case manager on the team (the plan still names one)' END AS [Issue]
FROM act a
JOIN iep ie       ON ie.personID  = a.personID AND ie.rn = 1
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 NULLIF(LTRIM(RTRIM(ISNULL(ps.caseManagerLastName, '') + ', ' + ISNULL(ps.caseManagerFirstName, ''))), ',') AS name
             FROM PlanStudent ps
             WHERE ps.planID = ie.planID) pcm
WHERE a.rn = 1
  AND NOT EXISTS (SELECT 1 FROM v_CurrentCaseManager cm WHERE cm.studentPersonID = a.personID)
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
