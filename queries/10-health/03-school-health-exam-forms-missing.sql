/* ======================================================================================
   #114  School health exam forms missing
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Health & compliance
   Type:      List · Priority 2 · Run BOY
   Purpose:   Active students in the chosen grades with no health exam (physical) on file
              dated on or after @examSince.
   Output:    One row per student: grade, date of the last exam on file (blank if none)
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HealthScreening,
              HealthScreeningPhysical
   Params:    @endYear, @schoolID, @asOf, @grades, @examSince  (change them in the
              PARAMETERS block below)
   Check:     Assumes exams are entered as Physical health screenings. Delaware requires
              one exam within the 2 years before a student first enrolls in a Delaware
              public school and a second within the 2 years before grade 9, with 30
              calendar days to comply (14 DE Admin. Code 815, 3.1). The defaults cover
              kindergarten and grade 9; students new to Delaware in other grades need the
              first exam too, so add their grades to @grades. Make sure the grade codes
              match how your district writes them (KG, 09).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @asOf      date = CONVERT(date, GETDATE());
DECLARE @grades    varchar(200) = 'KG,09';                              -- comma-separated grades; NULL = all grades
DECLARE @examSince date = DATEADD(year, -2, (SELECT MIN(startDate) FROM Calendar WHERE endYear = @endYear AND exclude = 0 AND summerSchool = 0));   -- exams dated on or after this count (2 years before the school year began)
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
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       CONVERT(date, ex.lastExam) AS [Last Exam On File]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (SELECT MAX(hs.date) AS lastExam
             FROM HealthScreening hs
             JOIN HealthScreeningPhysical hp ON hp.screeningID = hs.screeningID
             WHERE hs.personID = a.personID) ex
WHERE a.rn = 1
  AND (ex.lastExam IS NULL OR ex.lastExam < @examSince)
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
