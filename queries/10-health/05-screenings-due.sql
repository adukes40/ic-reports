/* ======================================================================================
   #116  Screenings due
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Health & compliance
   Type:      List · Priority 3 · Run Annual
   Purpose:   Active students in the chosen grades with no screening of the chosen type
              recorded this school year.
   Output:    One row per student: grade, screening type, date of the last screening of
              that type on file (blank if none)
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HealthScreening,
              HealthScreeningVision, HealthScreeningHearing, HealthScreeningDental,
              HealthScreeningScoliosis, HealthScreeningGrowth
   Params:    @endYear, @schoolID, @asOf, @grades, @screeningType, @since  (change them in
              the PARAMETERS block below)
   Check:     @screeningType must be Vision, Hearing, Dental, Scoliosis or Growth; any
              other value returns nothing. Default grades are Delaware's vision and
              hearing grades (K, 2, 4, 7, 9); make sure the grade codes match how your
              district writes them. "This school year" starts July 1 unless you change
              @since.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int  = NULL;   -- NULL = all schools
DECLARE @asOf          date = CONVERT(date, GETDATE());
DECLARE @grades        varchar(200) = 'KG,02,04,07,09';                 -- comma-separated grades; NULL = all grades
DECLARE @screeningType varchar(15)  = 'Vision';                         -- Vision, Hearing, Dental, Scoliosis or Growth
DECLARE @since         date = DATEFROMPARTS(@endYear - 1, 7, 1);        -- screenings dated on or after this count
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf, in @grades
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
      AND (@grades IS NULL
           OR e.grade IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@grades, ',')))
),
scr AS (        -- each student's latest screening of @screeningType
    SELECT hs.personID, MAX(hs.date) AS lastScreening
    FROM HealthScreening hs
    WHERE (@screeningType = 'Vision'    AND EXISTS (SELECT 1 FROM HealthScreeningVision    x WHERE x.screeningID = hs.screeningID))
       OR (@screeningType = 'Hearing'   AND EXISTS (SELECT 1 FROM HealthScreeningHearing   x WHERE x.screeningID = hs.screeningID))
       OR (@screeningType = 'Dental'    AND EXISTS (SELECT 1 FROM HealthScreeningDental    x WHERE x.screeningID = hs.screeningID))
       OR (@screeningType = 'Scoliosis' AND EXISTS (SELECT 1 FROM HealthScreeningScoliosis x WHERE x.screeningID = hs.screeningID))
       OR (@screeningType = 'Growth'    AND EXISTS (SELECT 1 FROM HealthScreeningGrowth    x WHERE x.screeningID = hs.screeningID))
    GROUP BY hs.personID
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       @screeningType AS [Screening],
       CONVERT(date, sc.lastScreening) AS [Last Screening On File]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN scr sc  ON sc.personID  = a.personID
WHERE a.rn = 1
  AND @screeningType IN ('Vision', 'Hearing', 'Dental', 'Scoliosis', 'Growth')
  AND (sc.lastScreening IS NULL OR sc.lastScreening < @since)
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
