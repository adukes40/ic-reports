/* ======================================================================================
   #80  SPED status vs. active plan mismatch
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Active students whose special ed status record is active but who have no
              locked, current IEP, and students with a locked, current IEP but no active
              special ed status record.
   Output:    One row per student: school, grade, special ed record start, latest locked
              IEP end, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Plan, PlanType, SpecialEDState,
              Person, Identity
   Params:    @endYear, @schoolID, @asOf, @planNameLike  (change them in the PARAMETERS
              block below)
   Check:     Special ed status is read from the state reporting record (SpecialEDState:
              eligible checked, started, not ended or exited on @asOf) because
              Enrollment.specialEdStatus is not filled in. IEPs are locked plans whose
              plan type is in the special ed module (PlanType.module = 'specialEd'); set
              @planNameLike if that module holds other plan types too.
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
plans AS (   -- per student: has a locked current IEP, has an unlocked current IEP, latest locked IEP end
    SELECT pl.personID,
           MAX(CASE WHEN pl.locked = 1
                     AND pl.startDate <= @asOf AND (pl.endDate IS NULL OR pl.endDate >= @asOf) THEN 1 ELSE 0 END) AS hasLockedCurrent,
           MAX(CASE WHEN ISNULL(pl.locked, 0) = 0
                     AND pl.startDate <= @asOf AND (pl.endDate IS NULL OR pl.endDate >= @asOf) THEN 1 ELSE 0 END) AS hasDraftCurrent,
           MAX(CASE WHEN pl.locked = 1 THEN pl.endDate END) AS lastLockedEnd
    FROM [Plan] pl
    JOIN PlanType pt ON pt.typeID = pl.typeID
    WHERE pt.module = 'specialEd' AND pt.name LIKE @planNameLike
    GROUP BY pl.personID
),
sped AS (   -- students with an active special ed status record on @asOf
    SELECT ss.personID, MIN(ss.startDate) AS startDate
    FROM SpecialEDState ss
    WHERE ss.eligible = 1
      AND (ss.startDate IS NULL OR ss.startDate <= @asOf)
      AND (ss.endDate   IS NULL OR ss.endDate   >= @asOf)
      AND (ss.exitDate  IS NULL OR ss.exitDate  >  @asOf)
    GROUP BY ss.personID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       sp.startDate AS [Special Ed Record Start],
       CONVERT(date, pl.lastLockedEnd) AS [Latest Locked IEP End],
       CASE WHEN sp.personID IS NULL    THEN 'Locked, current IEP but no active special ed status record'
            WHEN pl.personID IS NULL    THEN 'Special ed status is active but there is no IEP'
            WHEN pl.hasDraftCurrent = 1 THEN 'Special ed status is active but the current IEP is not locked'
            ELSE 'Special ed status is active but no locked IEP covers this date' END AS [Issue]
FROM act a
JOIN Person p      ON p.personID   = a.personID
JOIN [Identity] i  ON i.identityID = p.currentIdentityID
LEFT JOIN plans pl ON pl.personID  = a.personID
LEFT JOIN sped sp  ON sp.personID  = a.personID
WHERE a.rn = 1
  AND (   (sp.personID IS NOT NULL AND ISNULL(pl.hasLockedCurrent, 0) = 0)
       OR (sp.personID IS NULL     AND pl.hasLockedCurrent = 1))
ORDER BY a.schoolName, [Issue], a.grade, i.lastName, i.firstName;
