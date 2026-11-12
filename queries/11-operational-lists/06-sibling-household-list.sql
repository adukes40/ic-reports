/* ======================================================================================
   #123  Sibling / household list
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 3 · Run On request
   Purpose:   Households with active students in more than one school, with each student's
              school and grade. Used by offices planning mailings, events and conferences.
   Output:    One row per student per household: household ID and name, schools in the
              household, student, school, grade
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HouseholdMember,
              Household
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     @schoolID keeps households that have at least one student in that school and
              still lists the siblings in other schools. A student who is a current member
              of two households shows under both.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf, in any school
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
hh AS (   -- active students in each household, with the household's lowest and highest school ID
    SELECT DISTINCT hm.householdID, a.personID, a.schoolID, a.schoolName, a.endYear, a.grade,
           MIN(a.schoolID) OVER (PARTITION BY hm.householdID) AS minSchoolID,
           MAX(a.schoolID) OVER (PARTITION BY hm.householdID) AS maxSchoolID,
           MAX(CASE WHEN @schoolID IS NULL OR a.schoolID = @schoolID THEN 1 ELSE 0 END)
               OVER (PARTITION BY hm.householdID) AS inSchool
    FROM act a
    JOIN HouseholdMember hm ON hm.personID = a.personID
    WHERE a.rn = 1
      AND (hm.startDate IS NULL OR hm.startDate <= @asOf)
      AND (hm.endDate   IS NULL OR hm.endDate   >= @asOf)
)
SELECT hh.householdID AS [Household ID], h.name AS [Household Name],
       p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       hh.schoolID AS [School ID], hh.schoolName AS [School], hh.endYear AS [School Year], hh.grade AS [Grade]
FROM hh
JOIN Household h  ON h.householdID = hh.householdID
JOIN Person p     ON p.personID    = hh.personID
JOIN [Identity] i ON i.identityID  = p.currentIdentityID
WHERE hh.minSchoolID <> hh.maxSchoolID
  AND hh.inSchool = 1
ORDER BY h.name, hh.householdID, hh.schoolName, hh.grade, i.lastName, i.firstName;
