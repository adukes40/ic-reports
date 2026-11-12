/* ======================================================================================
   #138  Data export inventory
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      List · Priority 3 · Run Annual
   Purpose:   Every Data Extract Utility job with where it sends its file, how often it
              runs, when it last ran and who owns it, for privacy reviews.
   Output:    One row per extract job: name, owner username and name, owner's current
              assignment school (blank if none), source, ad hoc filter, delivery mode,
              server, path, file name, schedule, stopped or not, last run and result
   Tables:    SchoolYear, DataExtractUtility, DataExtractUtilityHistory, CampusJobTrigger,
              AdHocFilter, UserAccount, Person, Identity, EmploymentAssignment, School
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Passwords, keys and the destination login are never returned, and neither is
              the query text: open the job in IC to see which fields it sends. The owner
              is the user who created the job, or who last changed it when no creator is
              stored. The schedule comes from the job's trigger and is shown as stored
              (frequency word, hour:minute, day numbers): confirm a couple of jobs against
              the Data Extract Utility screen. Deleted jobs are left out.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all jobs; a school ID = owners assigned there now
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

WITH home AS (   -- each person's current school assignment (latest start)
    SELECT ea.personID, ea.schoolID, s.name AS schoolName,
           ROW_NUMBER() OVER (PARTITION BY ea.personID ORDER BY ea.startDate DESC, ea.assignmentID DESC) AS rn
    FROM EmploymentAssignment ea
    JOIN School s ON s.schoolID = ea.schoolID
    WHERE ea.startDate <= @asOf AND (ea.endDate IS NULL OR ea.endDate >= @asOf)
)
SELECT d.instanceName AS [Extract Name],
       ua.username AS [Owner Username], i.lastName AS [Last Name], i.firstName AS [First Name],
       h.schoolID AS [School ID], h.schoolName AS [School], @endYear AS [School Year],
       d.extractMode AS [Source], f.name AS [Ad Hoc Filter],
       d.deliveryMode AS [Delivery Mode], d.serverName AS [Destination Server],
       d.pathname AS [Destination Path],
       CONCAT(d.extractFilename, d.fileExtension) AS [File Name],
       tr.recurringFrequency AS [Frequency],
       RIGHT('0' + CAST(tr.frequencyHour AS varchar(2)), 2) + ':'
           + RIGHT('0' + CAST(tr.frequencyMinute AS varchar(2)), 2) AS [Run Time],
       d.freqDayOfWeek AS [Day Of Week], d.freqDayOfMonth AS [Day Of Month],
       CASE WHEN d.stopFlag = 1 THEN 'Yes' ELSE 'No' END AS [Stopped],
       lr.startTimestamp AS [Last Run],
       CASE WHEN lr.startTimestamp IS NULL THEN 'Never run'
            WHEN lr.error = 1 THEN 'Error' ELSE 'OK' END AS [Last Run Result],
       lr.ranBy AS [Last Run By],
       mu.username AS [Last Changed By]
FROM DataExtractUtility d
LEFT JOIN UserAccount ua      ON ua.userID    = COALESCE(d.createdByID, d.modifiedByUserID)
LEFT JOIN Person p            ON p.personID   = ua.personID
LEFT JOIN [Identity] i        ON i.identityID = p.currentIdentityID
LEFT JOIN home h              ON h.personID   = ua.personID AND h.rn = 1
LEFT JOIN UserAccount mu      ON mu.userID    = d.modifiedByUserID
LEFT JOIN AdHocFilter f       ON f.filterID   = d.filterID
LEFT JOIN CampusJobTrigger tr ON tr.triggerID = d.triggerID
OUTER APPLY (SELECT TOP 1 hi.startTimestamp, hi.error, hi.ranBy
             FROM DataExtractUtilityHistory hi
             WHERE hi.dataExtractID = d.dataExtractID
             ORDER BY hi.startTimestamp DESC) lr
WHERE d.isDeleted = 0
  AND (@schoolID IS NULL OR h.schoolID = @schoolID)
ORDER BY d.instanceName;
