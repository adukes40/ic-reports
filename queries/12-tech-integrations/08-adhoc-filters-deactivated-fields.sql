/* ======================================================================================
   #136  Ad hoc filters broken by deactivated fields
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 3 · Run After updates
   Purpose:   Saved ad hoc filters that Infinite Campus has marked as using a deactivated
              field, with who owns them and when they last ran.
   Output:    One row per filter: owner username and name, owner's current assignment
              school (blank if none), filter name, folder, type, group it is saved to,
              last run, last modified, issue
   Tables:    SchoolYear, AdHocFilter, AdHocFilterFolder, UserAccount, UserGroup, Person,
              Identity, EmploymentAssignment, School
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Relies on IC's own flag on the filter (filterContainsDeprecatedField); it
              does not read the filter definition, so it cannot say which field is the
              problem. Compare a few rows with IC's Deactivated Elements Impact Report
              after an update. The owner is the filter's user, or its creator when the
              filter is saved to a group.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all filters; a school ID = owners assigned there now
DECLARE @asOf     date = CONVERT(date, GETDATE());
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
       f.name AS [Filter Name], fo.name AS [Folder], f.filterType AS [Filter Type],
       g.name AS [Saved To Group],
       CONVERT(date, f.lastRunTimestamp) AS [Last Run],
       CONVERT(date, f.modifiedDate) AS [Last Modified],
       CASE WHEN ua.disable = 1 THEN 'Filter uses a deactivated field; owner account is disabled'
            ELSE 'Filter uses a deactivated field' END AS [Issue]
FROM AdHocFilter f
LEFT JOIN UserAccount ua       ON ua.userID    = COALESCE(f.userID, f.createdByID)
LEFT JOIN Person p             ON p.personID   = ua.personID
LEFT JOIN [Identity] i         ON i.identityID = p.currentIdentityID
LEFT JOIN home h               ON h.personID   = ua.personID AND h.rn = 1
LEFT JOIN UserGroup g          ON g.groupID    = f.groupID
LEFT JOIN AdHocFilterFolder fo ON fo.folderID  = f.folderID
WHERE f.filterContainsDeprecatedField = 1
  AND (@schoolID IS NULL OR h.schoolID = @schoolID)
ORDER BY i.lastName, i.firstName, ua.username, f.name;
