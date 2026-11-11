/* ======================================================================================
   #121  Custody and no-contact flags
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 1 · Run On request
   Purpose:   Active students with a current court order, custody, restricted pickup or
              no-contact flag, by school, showing the flag type only. Used by front offices.
   Output:    One row per student per flag: grade, flag type
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity,
              ProgramParticipation, Program
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     There is no custody table; this reads student Flags (Program /
              ProgramParticipation) whose name matches a word in the kw list at the top of
              the query. Compare that list with your district's flag names and edit it.
              Custody notes kept only in comments or custom fields are not found.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH kw AS (   -- words in a flag name that mark custody, court order, pickup or no contact
    SELECT v.pattern
    FROM (VALUES ('%custod%'), ('%court%'), ('%pick%up%'), ('%no%contact%'),
                 ('%restrain%'), ('%protect%'), ('%PFA%')) v(pattern)
),
act AS (   -- one active primary enrollment per student on @asOf
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
flags AS (   -- current matching flags per student
    SELECT DISTINCT pp.personID, pr.name AS flagType
    FROM ProgramParticipation pp
    JOIN Program pr ON pr.programID = pp.programID
    WHERE EXISTS (SELECT 1 FROM kw WHERE pr.name LIKE kw.pattern)
      AND pp.startDate <= @asOf AND (pp.endDate IS NULL OR pp.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       f.flagType AS [Flag Type]
FROM act a
JOIN flags f      ON f.personID   = a.personID
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
ORDER BY a.schoolName, i.lastName, i.firstName, f.flagType;
