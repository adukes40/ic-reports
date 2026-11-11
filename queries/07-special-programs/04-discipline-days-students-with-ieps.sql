/* ======================================================================================
   #82  Discipline days for students with IEPs
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      List · Priority 1 · Run Weekly
   Purpose:   Per active student with a locked, current IEP: total days removed this year
              (out-of-school suspension and expulsion) from behavior resolutions, flagged
              at 8 or more and 10 or more days.
   Output:    One row per student with at least one removal: school, grade, number of
              removals, removal days, latest removal date, flag
   Tables:    SchoolYear, Enrollment, Calendar, School, Plan, PlanType,
              BehaviorResolution, BehaviorResType, Day, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @ossPattern, @expulsionPattern,
              @planNameLike, @ossCodePattern, @warnDays, @flagDays  (change them in the
              PARAMETERS block below)
   Check:     Removals are resolutions whose type name matches @ossPattern,
              @ossCodePattern or @expulsionPattern; compare with your resolution type names
              (BehaviorResType). Days are the resolution's school days duration when it is
              filled in, otherwise the instructional days from its start through its end
              date (a missing end date counts the start day only). Days at every school in
              the district this year are added together. IEPs are locked plans in the
              special ed module; set @planNameLike if that module holds other plan types.
              After 10 school days of removal in one school year, services must be
              provided for any further removal (14 DE Admin. Code 926, 30.2.1).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear          int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID         int  = NULL;   -- NULL = all schools
DECLARE @asOf             date = CONVERT(date, GETDATE());
DECLARE @ossPattern       varchar(50) = '%out%school%';   -- resolution type names for out-of-school suspension
DECLARE @expulsionPattern varchar(50) = '%expul%';        -- resolution type names for expulsion
DECLARE @planNameLike     varchar(50) = '%';   -- plan type name filter, e.g. '%IEP%'; '%' = all special ed plan types
DECLARE @ossCodePattern   varchar(50) = 'OSS%';           -- second pattern for out-of-school suspension resolution type names
DECLARE @warnDays         int  = 8;      -- removal days at which a student gets the lower flag
DECLARE @flagDays         int  = 10;     -- removal days at which a student gets the higher flag
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
iep AS (   -- students with a locked special ed plan current on @asOf
    SELECT DISTINCT pl.personID
    FROM [Plan] pl
    JOIN PlanType pt ON pt.typeID = pl.typeID
    WHERE pt.module = 'specialEd' AND pt.name LIKE @planNameLike
      AND pl.locked = 1
      AND pl.startDate <= @asOf AND (pl.endDate IS NULL OR pl.endDate >= @asOf)
),
removal AS (   -- this year's out-of-school suspension and expulsion resolutions, with days removed
    SELECT r.personID, r.resolutionID, x.startDate,
           COALESCE(r.schoolDaysDuration, sd.days) AS days
    FROM BehaviorResolution r
    JOIN BehaviorResType rt ON rt.typeID = r.typeID
    JOIN Calendar c ON c.calendarID = r.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    CROSS APPLY (SELECT CONVERT(date, COALESCE(r.timestamp, r.discAssignDate)) AS startDate) x
    OUTER APPLY (SELECT COUNT(DISTINCT d.date) AS days
                 FROM Day d
                 WHERE d.calendarID = r.calendarID AND d.instruction = 1
                   AND d.date >= x.startDate
                   AND d.date <= CONVERT(date, COALESCE(r.endDate, x.startDate))) sd
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND x.startDate <= @asOf
      AND (rt.name LIKE @ossPattern OR rt.name LIKE @ossCodePattern OR rt.name LIKE @expulsionPattern)
),
perStudent AS (   -- removal totals per student
    SELECT personID, COUNT(*) AS removals, SUM(days) AS removalDays, MAX(startDate) AS lastRemoval
    FROM removal
    GROUP BY personID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       ps.removals AS [Removals],
       CAST(ps.removalDays AS decimal(9, 1)) AS [Removal Days],
       ps.lastRemoval AS [Latest Removal],
       CASE WHEN ps.removalDays >= @flagDays THEN CAST(@flagDays AS varchar(10)) + ' or more days'
            WHEN ps.removalDays >= @warnDays THEN CAST(@warnDays AS varchar(10)) + ' or more days'
            ELSE '' END AS [Flag]
FROM act a
JOIN iep ie        ON ie.personID  = a.personID
JOIN perStudent ps ON ps.personID  = a.personID
JOIN Person p      ON p.personID   = a.personID
JOIN [Identity] i  ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
ORDER BY ps.removalDays DESC, a.schoolName, i.lastName, i.firstName;
