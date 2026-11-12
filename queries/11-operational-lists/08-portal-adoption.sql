/* ======================================================================================
   #125  Portal adoption
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      KPI · Priority 2 · Run On request
   Purpose:   Per school, how many guardians of active students have a parent portal
              account and how many logged in during the last @days days. Used by principals
              and the tech office.
   Output:    One row per school: guardians, guardians with a portal account and %,
              guardians who logged in recently and %, days looked back
   Tables:    SchoolYear, Enrollment, Calendar, School, RelatedPair, UserAccount
   Params:    @endYear, @schoolID, @asOf, @days, @portalHomepage  (change them in the
              PARAMETERS block below)
   Check:     A portal account is an enabled user account whose homepage matches
              @portalHomepage ('%portal%'); look at UserAccount.homepage for a known parent
              account and adjust. A guardian with children in two schools counts once in
              each school, so do not add the school rows together for a district total.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int  = NULL;   -- NULL = all schools
DECLARE @asOf           date = CONVERT(date, GETDATE());
DECLARE @days           int  = 30;     -- a login counts if it was within this many days before @asOf
DECLARE @portalHomepage varchar(100) = '%portal%';   -- homepage of a portal account; % is a wildcard
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
grd AS (   -- one row per school per current guardian of an active student
    SELECT DISTINCT a.schoolID, a.schoolName, a.endYear, rp.personID2 AS guardianID
    FROM act a
    JOIN RelatedPair rp ON rp.personID1 = a.personID
                        AND rp.guardian = 1
                        AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
                        AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
    WHERE a.rn = 1
),
acct AS (   -- people with an enabled portal account, and their latest login
    SELECT ua.personID, MAX(ua.lastLoginTimestamp) AS lastLogin
    FROM UserAccount ua
    WHERE ISNULL(ua.disable, 0) = 0
      AND ua.homepage LIKE @portalHomepage
    GROUP BY ua.personID
)
SELECT g.schoolID AS [School ID], g.schoolName AS [School], g.endYear AS [School Year],
       COUNT(*) AS [Guardians],                                    -- denominator
       COUNT(ac.personID) AS [Guardians With Portal Account],
       CAST(100.0 * COUNT(ac.personID) / COUNT(*) AS decimal(5,1)) AS [Portal Account %],
       SUM(CASE WHEN ac.lastLogin >= DATEADD(day, -@days, @asOf) THEN 1 ELSE 0 END) AS [Guardians Logged In Recently],
       CAST(100.0 * SUM(CASE WHEN ac.lastLogin >= DATEADD(day, -@days, @asOf) THEN 1 ELSE 0 END)
            / COUNT(*) AS decimal(5,1)) AS [Logged In Recently %],
       @days AS [Days Looked Back]
FROM grd g
LEFT JOIN acct ac ON ac.personID = g.guardianID
GROUP BY g.schoolID, g.schoolName, g.endYear
ORDER BY g.schoolName;
