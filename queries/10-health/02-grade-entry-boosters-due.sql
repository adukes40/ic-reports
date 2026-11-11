/* ======================================================================================
   #113  Grade-entry boosters due
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Health & compliance
   Type:      List · Priority 2 · Run Spring, BOY
   Purpose:   Students headed into a grade that requires a booster who have no dose of
              that vaccine on file.
   Output:    One row per student: current grade, booster grade, vaccine, exemption on
              file (if any)
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, Vaccine,
              VaccineShot, VaccineExemption
   Params:    @endYear, @schoolID, @asOf, @grade, @currentGrade, @vaccine  (change them in
              the PARAMETERS block below)
   Check:     Defaults assume a Tdap booster on entry to grade 9; set the grade and
              vaccine your requirement uses. @vaccine must match a Code or Abbreviation
              in the vaccine list exactly, or nothing is returned. Grade codes must match
              how your district writes them (08, 09). Students with an exemption are
              listed with the exemption shown.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int  = NULL;   -- NULL = all schools
DECLARE @asOf         date = CONVERT(date, GETDATE());
DECLARE @grade        varchar(4)  = '09';     -- grade that requires the booster
DECLARE @currentGrade varchar(4)  = '08';     -- grade those students are in today (at BOY use the same value as @grade)
DECLARE @vaccine      varchar(15) = 'Tdap';   -- vaccine Code or Abbreviation
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf, in @currentGrade
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
      AND e.grade = @currentGrade
),
vac AS (        -- the vaccine(s) matching @vaccine
    SELECT v.vaccineID
    FROM Vaccine v
    WHERE v.code = @vaccine OR v.abbreviation = @vaccine
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       @grade AS [Booster Grade], @vaccine AS [Vaccine],
       ex.name AS [Exemption]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (SELECT TOP 1 ve.name
             FROM VaccineShot vs
             JOIN VaccineExemption ve ON ve.code = vs.exempt
             WHERE vs.personID = a.personID
               AND vs.vaccineID IN (SELECT vaccineID FROM vac)
             ORDER BY vs.date DESC) ex
WHERE a.rn = 1
  AND EXISTS (SELECT 1 FROM vac)
  AND NOT EXISTS (SELECT 1 FROM VaccineShot vs
                  WHERE vs.personID = a.personID
                    AND vs.vaccineID IN (SELECT vaccineID FROM vac)
                    AND NULLIF(LTRIM(RTRIM(vs.exempt)), '') IS NULL)
ORDER BY a.schoolName, i.lastName, i.firstName;
