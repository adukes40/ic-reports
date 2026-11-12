/* ======================================================================================
   #130  Stale accounts
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 2 · Run Quarterly
   Purpose:   Enabled staff user accounts with no login in the last @days days, or that
              have never logged in.
   Output:    One row per account: username, name, current assignment school (blank if
              none), last login, days since login, account creation date, issue
   Tables:    SchoolYear, UserAccount, Person, Identity, EmploymentAssignment, School
   Params:    @endYear, @schoolID, @asOf, @days, @portalHomepage  (change them in the
              PARAMETERS block below)
   Check:     Staff accounts are taken to be those whose homepage is blank or does not
              contain 'portal'. Last login comes from UserAccount.lastLoginTimestamp, which
              is blank for accounts that have not logged in since IC began recording it, so
              look at Account Created before acting on 'Never logged in'.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int  = NULL;   -- NULL = all accounts; a school ID = staff assigned there now
DECLARE @asOf           date = CONVERT(date, GETDATE());
DECLARE @days           int  = 90;     -- days without a login before an account counts as stale
DECLARE @portalHomepage varchar(100) = '%portal%';   -- homepage of a portal account (these are left out); % is a wildcard
-- ===========================================================================

WITH home AS (   -- each person's current school assignment (latest start)
    SELECT ea.personID, ea.schoolID, s.name AS schoolName,
           ROW_NUMBER() OVER (PARTITION BY ea.personID ORDER BY ea.startDate DESC, ea.assignmentID DESC) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
    WHERE ea.startDate <= @asOf AND (ea.endDate IS NULL OR ea.endDate >= @asOf)
)
SELECT ua.username AS [Username], i.lastName AS [Last Name], i.firstName AS [First Name],
       h.schoolID AS [School ID], h.schoolName AS [School], @endYear AS [School Year],
       CONVERT(date, ua.lastLoginTimestamp) AS [Last Login],
       DATEDIFF(day, ua.lastLoginTimestamp, @asOf) AS [Days Since Login],
       CONVERT(date, ua.createdDate) AS [Account Created],
       CASE WHEN ua.lastLoginTimestamp IS NULL THEN 'Never logged in'
            ELSE 'No login in ' + CAST(@days AS varchar(10)) + ' days or more' END AS [Issue]
FROM UserAccount ua
LEFT JOIN Person p     ON p.personID   = ua.personID
LEFT JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN home h       ON h.personID   = ua.personID AND h.rn = 1
WHERE ua.disable = 0
  AND (ua.expiresDate IS NULL OR ua.expiresDate > @asOf)
  AND (ua.homepage IS NULL OR ua.homepage NOT LIKE @portalHomepage)   -- staff accounts only
  AND (ua.lastLoginTimestamp IS NULL OR ua.lastLoginTimestamp < DATEADD(day, -@days, @asOf))
  AND (@schoolID IS NULL OR h.schoolID = @schoolID)
ORDER BY h.schoolName, ua.lastLoginTimestamp, i.lastName, i.firstName;
