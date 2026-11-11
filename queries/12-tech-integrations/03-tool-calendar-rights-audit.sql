/* ======================================================================================
   #131  Tool and calendar rights audit
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Enabled accounts holding tool rights or calendar rights granted directly to
              the user instead of through a user group, and accounts whose calendar rights
              reach all schools or a school where the person has no current assignment.
   Output:    One row per account per problem: username, name, current assignment school
              (blank if none), the school the rights reach, how they were granted (direct
              or group name), issue
   Tables:    SchoolYear, UserAccount, Person, Identity, EmploymentAssignment, School,
              UserToolRights, UserSchoolYearRights, UserGroupSchoolYearRights, UserGroup,
              UserGroupMember, Calendar
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Calendar rights are read for @endYear and for rights set to all years. A
              blank school on a rights row means all schools, which is normal for district
              office staff: expect them here and skim past. Whether a tool right fits a
              person's role cannot be judged in SQL, so direct tool rights are only
              counted; open the account to review them. Excluded schools are not filtered
              out, so rights to them show too.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all; a school ID = staff assigned there or rights reaching it
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH acct AS (   -- enabled user accounts
    SELECT ua.userID, ua.personID, ua.username, ua.allCalendars
    FROM UserAccount ua
    WHERE ua.disable = 0
      AND (ua.expiresDate IS NULL OR ua.expiresDate > @asOf)
),
assign AS (   -- school assignments current on @asOf
    SELECT ea.personID, ea.schoolID, s.name AS schoolName,
           ROW_NUMBER() OVER (PARTITION BY ea.personID ORDER BY ea.startDate DESC, ea.assignmentID DESC) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
    WHERE ea.startDate <= @asOf AND (ea.endDate IS NULL OR ea.endDate >= @asOf)
),
calRights AS (   -- this year's calendar rights, direct and through groups
    SELECT r.userID, CAST('Direct' AS varchar(60)) AS grantedThrough, 1 AS isDirect, r.schoolID, r.calendarID
    FROM UserSchoolYearRights r
    WHERE r.endYear IS NULL OR r.endYear = @endYear
    UNION ALL
    SELECT m.userID, CAST('Group: ' + g.name AS varchar(60)), 0, r.schoolID, r.calendarID
    FROM UserGroupSchoolYearRights r
    JOIN UserGroup g       ON g.groupID = r.groupID
    JOIN UserGroupMember m ON m.groupID = r.groupID
    WHERE r.endYear IS NULL OR r.endYear = @endYear
),
calScope AS (   -- those rights by school reached; NULL school = all schools
    SELECT DISTINCT cr.userID, cr.grantedThrough, cr.isDirect,
           COALESCE(cr.schoolID, c.schoolID) AS schoolID
    FROM calRights cr
    LEFT JOIN Calendar c ON c.calendarID = cr.calendarID
),
problems AS (   -- one row per account per problem
    SELECT t.userID, CAST(NULL AS int) AS rightsSchoolID, 0 AS allSchools,
           CAST('Direct' AS varchar(60)) AS grantedThrough,
           CAST('Tool rights granted directly to the user (' + CAST(COUNT(*) AS varchar(10)) + ' tools)'
                AS varchar(120)) AS issue
    FROM UserToolRights t
    GROUP BY t.userID
    UNION ALL
    SELECT a.userID, NULL, 1, 'Direct', 'All Calendars is checked on the account'
    FROM acct a
    WHERE a.allCalendars = 1
    UNION ALL
    SELECT cs.userID, cs.schoolID, CASE WHEN cs.schoolID IS NULL THEN 1 ELSE 0 END, cs.grantedThrough,
           CONCAT_WS('; ',
               CASE WHEN cs.isDirect = 1 THEN 'Calendar rights granted directly to the user' END,
               CASE WHEN cs.schoolID IS NULL THEN 'Calendar rights to all schools'
                    WHEN x.hasAssignment = 0 THEN 'Calendar rights to a school with no current assignment' END)
    FROM calScope cs
    JOIN acct a ON a.userID = cs.userID
    CROSS APPLY (SELECT CASE WHEN EXISTS (SELECT 1 FROM assign g
                                          WHERE g.personID = a.personID AND g.schoolID = cs.schoolID)
                             THEN 1 ELSE 0 END AS hasAssignment) x
    WHERE cs.isDirect = 1 OR cs.schoolID IS NULL OR x.hasAssignment = 0
)
SELECT a.username AS [Username], i.lastName AS [Last Name], i.firstName AS [First Name],
       h.schoolID AS [School ID], h.schoolName AS [School], @endYear AS [School Year],
       CASE WHEN pr.allSchools = 1 THEN 'All schools' ELSE rs.name END AS [Rights School],
       pr.grantedThrough AS [Granted Through],
       pr.issue AS [Issue]
FROM problems pr
JOIN acct a            ON a.userID     = pr.userID
LEFT JOIN Person p     ON p.personID   = a.personID
LEFT JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN assign h     ON h.personID   = a.personID AND h.rn = 1
LEFT JOIN School rs    ON rs.schoolID  = pr.rightsSchoolID
WHERE @schoolID IS NULL OR h.schoolID = @schoolID OR pr.rightsSchoolID = @schoolID
ORDER BY i.lastName, i.firstName, a.username, pr.issue, rs.name;
