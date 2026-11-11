/* ======================================================================================
   #34  Active students with no guardian
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Demographics
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Active students with no current relationship flagged guardian.
   Output:    One row per student: age, count of current relationships of any kind, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, RelatedPair
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Students 18+ can legitimately have none; filter on the Age column if they're
              noise.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
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
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       DATEDIFF(year, i.birthdate, @asOf)
         - CASE WHEN DATEADD(year, DATEDIFF(year, i.birthdate, @asOf), i.birthdate) > @asOf
                THEN 1 ELSE 0 END AS [Age],
       (SELECT COUNT(*) FROM RelatedPair r2
         WHERE r2.personID1 = a.personID
           AND (r2.startDate IS NULL OR r2.startDate <= @asOf)
           AND (r2.endDate   IS NULL OR r2.endDate   >= @asOf)) AS [Current Relationships],
       'No current guardian relationship' AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND NOT EXISTS (SELECT 1 FROM RelatedPair rp
                  WHERE rp.personID1 = a.personID
                    AND rp.guardian = 1
                    AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
                    AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf))
ORDER BY a.schoolName, a.grade, i.lastName;
