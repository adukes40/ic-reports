/* ======================================================================================
   #24  Age out of range for grade
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 2 · Run BOY
   Purpose:   Age on Sept 1 outside the usual range for the grade, any student over 21, or a
              missing birthdate.
   Output:    One row per problem: grade, birthdate, age on Sept 1, issue
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @schoolID, @maxAge (21), @kGrades (K codes list), @kMinAge (4),
              @kMaxAge (7), @minGrade (1), @maxGrade (12), @youngestOverGrade (4),
              @oldestOverGrade (8)  (change them in the PARAMETERS block below)
   Check:     Edit @kGrades to your kindergarten grade codes. Non-numeric grades only get
              the over-21 check.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int = NULL;   -- NULL = all schools
DECLARE @maxAge   int = 21;
DECLARE @kGrades TABLE (grade varchar(5));
INSERT INTO @kGrades VALUES ('K'), ('KG'), ('KN'), ('00');   -- your kindergarten grade codes
DECLARE @kMinAge  int = 4;      -- youngest expected age in kindergarten
DECLARE @kMaxAge  int = 7;      -- oldest expected age in kindergarten
DECLARE @minGrade int = 1;      -- lowest grade number that gets the age-for-grade check
DECLARE @maxGrade int = 12;     -- highest grade number that gets the age-for-grade check
DECLARE @youngestOverGrade int = 4;   -- youngest expected age = grade number + this (grade 3: 7)
DECLARE @oldestOverGrade   int = 8;   -- oldest expected age = grade number + this (grade 3: 11)
-- ===========================================================================

WITH base AS (
    SELECT e.personID, e.grade, c.schoolID, s.name AS schoolName, c.endYear, i.birthdate,
           DATEDIFF(year, i.birthdate, DATEFROMPARTS(@endYear - 1, 9, 1))
             - CASE WHEN DATEADD(year, DATEDIFF(year, i.birthdate, DATEFROMPARTS(@endYear - 1, 9, 1)), i.birthdate)
                         > DATEFROMPARTS(@endYear - 1, 9, 1) THEN 1 ELSE 0 END AS ageSept1,
           CASE WHEN e.grade IN (SELECT grade FROM @kGrades) THEN 0 ELSE TRY_CAST(e.grade AS int) END AS g,
           p.studentNumber, i.lastName, i.firstName
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Person   p ON p.personID   = e.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND s.exclude = 0
      AND e.serviceType = 'P'
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
)
SELECT studentNumber AS [Student Number], lastName AS [Last Name], firstName AS [First Name], schoolID AS [School ID], schoolName AS [School], endYear AS [School Year], grade AS [Grade],
       CONVERT(date, birthdate) AS [Birth Date], ageSept1 AS [Age on Sept 1],
       CASE WHEN birthdate IS NULL THEN 'No birthdate'
            WHEN ageSept1 > @maxAge THEN 'Over ' + CAST(@maxAge AS varchar(3))
            WHEN g = 0 THEN 'Kindergarten age outside ' + CAST(@kMinAge AS varchar(3)) + '-' + CAST(@kMaxAge AS varchar(3))
            ELSE 'Age outside ' + CAST(g + @youngestOverGrade AS varchar(3)) + '-' + CAST(g + @oldestOverGrade AS varchar(3)) + ' for grade' END AS [Issue]
FROM base
WHERE birthdate IS NULL
   OR ageSept1 > @maxAge
   OR (g = 0 AND (ageSept1 < @kMinAge OR ageSept1 > @kMaxAge))
   OR (g BETWEEN @minGrade AND @maxGrade AND (ageSept1 < g + @youngestOverGrade OR ageSept1 > g + @oldestOverGrade))
ORDER BY [School], [Grade], [Last Name];
