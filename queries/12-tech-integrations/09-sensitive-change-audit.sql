/* ======================================================================================
   #137  Sensitive-change audit
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      List · Priority 2 · Run Monthly
   Purpose:   Who changed attendance, transcript grades and student identity records
              between @startDate and @endDate, and when.
   Output:    One row per change: date and time, username and name of the user, table,
              field, action, the student, school, year, the attendance date changed
   Tables:    SchoolYear, AuditAttendance, TranscriptCourse, Identity, AuditLogEntry,
              AuditLogEntryDetail, UserAccount, Person, Enrollment, Calendar, School
   Params:    @endYear, @schoolID, @startDate, @endDate, @attLagDays  (change them in the
              PARAMETERS block below)
   Check:     Old and new values are left out on purpose. Attendance comes from
              AuditAttendance and only shows changes made @attLagDays or more days after
              the attendance date (set it to 0 for every entry, which is a very long
              list); its action codes are assumed to be I, U and D. Grades: the posted
              grade table does not store who changed a score, so grade rows are transcript
              entries added or edited by hand (TranscriptCourse) plus anything the general
              audit log holds. Identity rows show that a student's identity record was
              saved, not which field. The general audit log (AuditLogEntry) is included
              for tables named like Grad, Transcript, Attend, Identity or Person: check
              what your log holds, it has no school so it only shows when @schoolID is
              NULL. The modified-by ID is taken to be the user account ID.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int  = NULL;   -- NULL = all schools
DECLARE @endDate    date = CONVERT(date, GETDATE());       -- last day of changes to list
DECLARE @startDate  date = DATEADD(day, -30, @endDate);    -- first day of changes to list
DECLARE @attLagDays int  = 7;      -- attendance: only changes made this many days or more after the attendance date
-- ===========================================================================

WITH enr AS (   -- each student's latest enrollment this year, for the school of identity changes
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
),
chg AS (   -- one row per change from each source
    SELECT CAST(aa.modifiedDate AS datetime) AS changedOn, aa.modifiedByID AS userID,
           CAST('Attendance' AS varchar(100)) AS tableName,
           CAST('Attendance mark' AS varchar(100)) AS fieldName,
           CAST(CASE aa.actionType WHEN 'I' THEN 'Insert' WHEN 'U' THEN 'Update' WHEN 'D' THEN 'Delete'
                                   ELSE aa.actionType END AS varchar(20)) AS actionName,
           aa.personID, c.schoolID, CAST(s.name AS varchar(60)) AS schoolName, CAST(c.endYear AS int) AS endYear,
           CONVERT(date, aa.date) AS recordDate
    FROM AuditAttendance aa
    JOIN Calendar c ON c.calendarID = aa.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE aa.modifiedDate >= @startDate AND aa.modifiedDate < DATEADD(day, 1, @endDate)
      AND DATEDIFF(day, aa.date, aa.modifiedDate) >= @attLagDays
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
    UNION ALL
    SELECT tc.modifiedDate, tc.modifiedByID, 'TranscriptCourse',
           'Transcript grade: ' + tc.courseNumber + ' ' + tc.courseName, 'Add or update',
           tc.personID, ts.schoolID, tc.schoolName, tc.endYear, NULL
    FROM TranscriptCourse tc
    OUTER APPLY (SELECT TOP 1 s.schoolID FROM School s WHERE s.number = tc.schoolNumber ORDER BY s.schoolID) ts
    WHERE tc.modifiedDate >= @startDate AND tc.modifiedDate < DATEADD(day, 1, @endDate)
      AND tc.modifiedByID IS NOT NULL
      AND (@schoolID IS NULL OR ts.schoolID = @schoolID)
    UNION ALL
    SELECT idn.modifiedDate, idn.modifiedByID, 'Identity',
           'Identity record (name, birth date, gender, race/ethnicity)', 'Add or update',
           idn.personID, en.schoolID, en.schoolName, en.endYear, NULL
    FROM [Identity] idn
    JOIN enr en ON en.personID = idn.personID AND en.rn = 1
    WHERE idn.modifiedDate >= @startDate AND idn.modifiedDate < DATEADD(day, 1, @endDate)
      AND idn.modifiedByID IS NOT NULL
      AND (@schoolID IS NULL OR en.schoolID = @schoolID)
    UNION ALL
    SELECT ale.[timestamp], ale.userID, ale.[table], d.propertyName, ale.action,
           NULL, NULL, NULL, NULL, NULL
    FROM AuditLogEntry ale
    LEFT JOIN AuditLogEntryDetail d ON d.auditLogEntryID = ale.auditLogEntryID
    WHERE ale.[timestamp] >= @startDate AND ale.[timestamp] < DATEADD(day, 1, @endDate)
      AND @schoolID IS NULL
      AND (ale.[table] LIKE '%Grad%' OR ale.[table] LIKE '%Transcript%' OR ale.[table] LIKE '%Attend%'
           OR ale.[table] LIKE '%Identity%' OR ale.[table] LIKE '%Person%')   -- audit-log tables to include
)
SELECT ch.changedOn AS [Changed On],
       ua.username AS [Username], ui.lastName AS [User Last Name], ui.firstName AS [User First Name],
       ch.tableName AS [Table], ch.fieldName AS [Field], ch.actionName AS [Action],
       sp.studentNumber AS [Student Number], si.lastName AS [Last Name], si.firstName AS [First Name],
       ch.schoolID AS [School ID], ch.schoolName AS [School], ch.endYear AS [School Year],
       ch.recordDate AS [Attendance Date]
FROM chg ch
LEFT JOIN UserAccount ua ON ua.userID     = ch.userID
LEFT JOIN Person up      ON up.personID   = ua.personID
LEFT JOIN [Identity] ui  ON ui.identityID = up.currentIdentityID
LEFT JOIN Person sp      ON sp.personID   = ch.personID
LEFT JOIN [Identity] si  ON si.identityID = sp.currentIdentityID
ORDER BY ch.changedOn DESC, ua.username, ch.tableName;
