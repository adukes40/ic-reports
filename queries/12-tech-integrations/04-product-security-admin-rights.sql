/* ======================================================================================
   #132  Product security / admin rights
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 1 · Run Quarterly
   Purpose:   Every enabled account with All Tools, a product security role, or rights to
              the tools that manage user accounts, groups and rights, and whether each came
              directly or through a group.
   Output:    One row per account per way the rights were granted: username, name, current
              assignment school (blank if none), last login, granted through (direct or
              group name), the tools with R/W/A/D, issue
   Tables:    SchoolYear, UserAccount, Person, Identity, EmploymentAssignment, School,
              UserGroup, UserGroupMember, UserToolRights, UserGroupToolRights, CampusTool
   Params:    @endYear, @schoolID, @asOf, @adminToolPatterns  (change them in the
              PARAMETERS block below)
   Check:     The account administration tools are picked by name with the patterns in
              @adminToolPatterns (User Account..., User Group..., Product Security, Login
              As User, Tool Rights, Calendar Rights, Security Preferences): compare those
              patterns with your tool names and change the list. Product security roles
              are user groups flagged as security roles. Everyone listed is not a problem:
              the point is to confirm each person should still be on the list.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear           int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID          int  = NULL;   -- NULL = all accounts; a school ID = staff assigned there now
DECLARE @asOf              date = CONVERT(date, GETDATE());
DECLARE @adminToolPatterns varchar(500) = 'User Account%,User Group%,%Product Security%,Login As User%,%Tool Rights%,%Calendar Rights%,%Security Preferences%';
                                          -- names of the tools that manage accounts, groups and rights, comma-separated (% = any text)
-- ===========================================================================

WITH adminTools AS (   -- tools that manage accounts, groups and rights (names matching @adminToolPatterns)
    SELECT ct.toolID, ct.name
    FROM CampusTool ct
    WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(@adminToolPatterns, ',') p WHERE ct.name LIKE LTRIM(RTRIM(p.value)))
),
home AS (   -- each person's current school assignment (latest start)
    SELECT ea.personID, ea.schoolID, s.name AS schoolName,
           ROW_NUMBER() OVER (PARTITION BY ea.personID ORDER BY ea.startDate DESC, ea.assignmentID DESC) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
    WHERE ea.startDate <= @asOf AND (ea.endDate IS NULL OR ea.endDate >= @asOf)
),
toolGrants AS (   -- rights to those tools, direct and through groups
    SELECT r.userID, CAST('Direct' AS varchar(60)) AS grantedThrough, t.name,
           CONCAT(CASE WHEN r.[read] = 1 THEN 'R' END, CASE WHEN r.[write] = 1 THEN 'W' END,
                  CASE WHEN r.[add] = 1 THEN 'A' END, CASE WHEN r.[delete] = 1 THEN 'D' END) AS access
    FROM UserToolRights r
    JOIN adminTools t ON t.toolID = r.toolID
    UNION ALL
    SELECT m.userID, CAST('Group: ' + g.name AS varchar(60)), t.name,
           CONCAT(CASE WHEN r.[read] = 1 THEN 'R' END, CASE WHEN r.[write] = 1 THEN 'W' END,
                  CASE WHEN r.[add] = 1 THEN 'A' END, CASE WHEN r.[delete] = 1 THEN 'D' END)
    FROM UserGroupToolRights r
    JOIN adminTools t      ON t.toolID  = r.toolID
    JOIN UserGroup g       ON g.groupID = r.groupID
    JOIN UserGroupMember m ON m.groupID = r.groupID
),
grants AS (   -- one row per account per way admin rights were granted
    SELECT ua.userID, CAST('Direct' AS varchar(60)) AS grantedThrough, CAST(NULL AS varchar(max)) AS tools,
           CAST('All Tools is checked on the account (full rights)' AS varchar(80)) AS issue
    FROM UserAccount ua
    WHERE ua.allModules = 1
    UNION ALL
    SELECT m.userID, CAST('Group: ' + g.name AS varchar(60)), NULL, 'Member of a product security role'
    FROM UserGroupMember m
    JOIN UserGroup g ON g.groupID = m.groupID
    WHERE g.isSecurityRole = 1
    UNION ALL
    SELECT tg.userID, tg.grantedThrough,
           STRING_AGG(CAST(tg.name + ' (' + tg.access + ')' AS varchar(max)), ', ') WITHIN GROUP (ORDER BY tg.name),
           'Rights to account administration tools'
    FROM toolGrants tg
    WHERE tg.access <> ''
    GROUP BY tg.userID, tg.grantedThrough
)
SELECT ua.username AS [Username], i.lastName AS [Last Name], i.firstName AS [First Name],
       h.schoolID AS [School ID], h.schoolName AS [School], @endYear AS [School Year],
       CONVERT(date, ua.lastLoginTimestamp) AS [Last Login],
       gr.grantedThrough AS [Granted Through],
       gr.tools AS [Tools],
       gr.issue AS [Issue]
FROM grants gr
JOIN UserAccount ua    ON ua.userID    = gr.userID
LEFT JOIN Person p     ON p.personID   = ua.personID
LEFT JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN home h       ON h.personID   = ua.personID AND h.rn = 1
WHERE ua.disable = 0
  AND (ua.expiresDate IS NULL OR ua.expiresDate > @asOf)
  AND (@schoolID IS NULL OR h.schoolID = @schoolID)
ORDER BY i.lastName, i.firstName, ua.username, gr.issue, gr.grantedThrough;
