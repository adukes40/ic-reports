/* ======================================================================================
   #129  Active accounts for staff who left
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 1 · Run Monthly, EOY
   Purpose:   Enabled staff user accounts whose person has no current school assignment and
              no active enrollment, so their access can be ended.
   Output:    One row per account: username, name, school of the last assignment, when that
              assignment ended, district employment status, last login, issue
   Tables:    SchoolYear, UserAccount, Person, Identity, EmploymentAssignment, Employment,
              School, Enrollment, Calendar
   Params:    @endYear, @schoolID, @asOf, @portalHomepage  (change them in the PARAMETERS
              block below)
   Check:     Staff accounts are taken to be those whose homepage is blank or does not
              contain 'portal' (parent and student portal accounts are left out). District
              office staff with an employment record but no school assignment are listed
              too: see the District Employment column. School is the last assignment's
              school. Last login is blank if the account has never logged in.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear        int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID       int  = NULL;   -- NULL = all schools (matches the last assignment's school)
DECLARE @asOf           date = CONVERT(date, GETDATE());
DECLARE @portalHomepage varchar(100) = '%portal%';   -- homepage of a portal account (these are left out); % is a wildcard
-- ===========================================================================

WITH lastAssign AS (   -- each person's latest school assignment, open ones first
    SELECT ea.personID, ea.schoolID, s.name AS schoolName, ea.endDate,
           ROW_NUMBER() OVER (PARTITION BY ea.personID
                              ORDER BY CASE WHEN ea.endDate IS NULL THEN 1 ELSE 0 END DESC,
                                       ea.endDate DESC, ea.assignmentID DESC) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
),
emp AS (   -- each person's district employment: open on @asOf or latest end date
    SELECT em.personID,
           MAX(CASE WHEN em.endDate IS NULL OR em.endDate >= @asOf THEN 1 ELSE 0 END) AS isOpen,
           MAX(em.endDate) AS lastEnd
    FROM Employment em
    GROUP BY em.personID
)
SELECT ua.username AS [Username], i.lastName AS [Last Name], i.firstName AS [First Name],
       la.schoolID AS [School ID], la.schoolName AS [School], @endYear AS [School Year],
       CONVERT(date, la.endDate) AS [Last Assignment End],
       CASE WHEN em.personID IS NULL THEN 'No employment record'
            WHEN em.isOpen = 1       THEN 'Open'
            ELSE 'Ended ' + CONVERT(varchar(10), em.lastEnd, 23) END AS [District Employment],
       CONVERT(date, ua.lastLoginTimestamp) AS [Last Login],
       CONVERT(date, ua.createdDate) AS [Account Created],
       CASE WHEN la.personID IS NULL THEN 'Enabled account, person never had a school assignment'
            ELSE 'Enabled account, last school assignment ended' END AS [Issue]
FROM UserAccount ua
LEFT JOIN Person p     ON p.personID   = ua.personID
LEFT JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN lastAssign la ON la.personID = ua.personID AND la.rn = 1
LEFT JOIN emp em        ON em.personID = ua.personID
WHERE ua.disable = 0
  AND (ua.expiresDate IS NULL OR ua.expiresDate > @asOf)
  AND (ua.homepage IS NULL OR ua.homepage NOT LIKE @portalHomepage)   -- staff accounts only
  AND (la.personID IS NULL OR la.endDate < @asOf)
  AND (@schoolID IS NULL OR la.schoolID = @schoolID)
  AND NOT EXISTS (
      SELECT 1
      FROM Enrollment e
      JOIN Calendar c ON c.calendarID = e.calendarID
      JOIN School  es ON es.schoolID  = c.schoolID
      WHERE e.personID = ua.personID
        AND c.endYear = @endYear
        AND c.exclude = 0 AND c.summerSchool = 0 AND es.exclude = 0
        AND ISNULL(e.noShow, 0) = 0
        AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf))
ORDER BY la.schoolName, i.lastName, i.firstName, ua.username;
