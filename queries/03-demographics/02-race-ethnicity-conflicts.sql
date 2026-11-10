/* ======================================================================================
   #31  Race / ethnicity conflicts
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Demographics
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Blank Hispanic answer, Hispanic = N with no race, a race not in the race list,
              or a blank federal rollup.
   Output:    One row per problem: Hispanic flag, federal rollup code and name, race codes
              and names on file, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity,
              IdentityRaceEthnicity, RaceEthnicity
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Assumes hispanicEthnicity is stored as Y / N.
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
       i.hispanicEthnicity AS [Hispanic/Latino],
       i.raceEthnicityFed AS [Federal Race Code],
       CASE CONVERT(varchar(20), i.raceEthnicityFed)   -- standard federal rollup codes
            WHEN '1' THEN 'Hispanic/Latino'
            WHEN '2' THEN 'American Indian or Alaska Native'
            WHEN '3' THEN 'Asian'
            WHEN '4' THEN 'Black or African American'
            WHEN '5' THEN 'Native Hawaiian or Other Pacific Islander'
            WHEN '6' THEN 'White'
            WHEN '7' THEN 'Two or more races' END AS [Federal Race],
       (SELECT STRING_AGG(COALESCE(r.code, 'raceID ' + CONVERT(varchar(12), ire.raceID)), ', ')
          FROM IdentityRaceEthnicity ire
          LEFT JOIN RaceEthnicity r ON r.raceID = ire.raceID
         WHERE ire.identityID = i.identityID) AS [Race Codes on File],
       (SELECT STRING_AGG(COALESCE(r.name, 'Unknown (raceID ' + CONVERT(varchar(12), ire.raceID) + ')'), ', ')
          FROM IdentityRaceEthnicity ire
          LEFT JOIN RaceEthnicity r ON r.raceID = ire.raceID
         WHERE ire.identityID = i.identityID) AS [Races on File],
       x.issue AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN NULLIF(LTRIM(RTRIM(i.hispanicEthnicity)), '') IS NULL
          THEN 'Hispanic/Latino answer is blank' END),
    (CASE WHEN i.hispanicEthnicity = 'N'
           AND NOT EXISTS (SELECT 1 FROM IdentityRaceEthnicity ire WHERE ire.identityID = i.identityID)
          THEN 'Not Hispanic/Latino and no race selected' END),
    (CASE WHEN EXISTS (SELECT 1 FROM IdentityRaceEthnicity ire
                       LEFT JOIN RaceEthnicity r ON r.raceID = ire.raceID
                       WHERE ire.identityID = i.identityID AND r.raceID IS NULL)
          THEN 'Race on file is not in the race list' END),
    (CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(varchar(20), i.raceEthnicityFed))), '') IS NULL
          THEN 'Federal race rollup is blank' END)
) x(issue)
WHERE a.rn = 1 AND x.issue IS NOT NULL
ORDER BY a.schoolName, a.grade, i.lastName;
