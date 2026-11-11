/* ======================================================================================
   #85  EL status gaps
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Active students whose EL record has no program status, current ELs with no
              first-US-school date, exited ELs with no exit date, and exit dates on
              records that are not marked exited.
   Output:    One row per problem: school, grade, EL status, identified date, exit date,
              issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Lep, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @elExitedLike, @elNotLike, @elPendingLike  (change
              them in the PARAMETERS block below)
   Check:     Status codes are assumed to be IC's standard ones: exited starts with
              'Exit' (@elExitedLike), and statuses starting with 'Not' (@elNotLike) or
              'Pend' (@elPendingLike) are not EL. The EL Status column shows the real
              codes; change the parameters if yours differ.
              The EL program type and EL services are not filled in here, so a missing
              EL program is not checked. First-US-school date is
              Identity.dateEnteredUSSchool.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear       int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID      int  = NULL;   -- NULL = all schools
DECLARE @asOf          date = CONVERT(date, GETDATE());
DECLARE @elExitedLike    varchar(20) = 'Exit%';   -- EL program status code(s) that mean exited / reclassified
DECLARE @elNotLike     varchar(20) = 'Not%';    -- EL program status code(s) that mean not an English learner
DECLARE @elPendingLike varchar(20) = 'Pend%';   -- EL program status code(s) that mean pending
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
el AS (   -- EL records with the status sorted into blank / exited / current EL
    SELECT l.personID, l.programStatus, l.identifiedDate, l.exitDate,
           CASE WHEN NULLIF(LTRIM(RTRIM(l.programStatus)), '') IS NULL THEN 1 ELSE 0 END AS noStatus,
           CASE WHEN l.programStatus LIKE @elExitedLike THEN 1 ELSE 0 END AS isExited,
           CASE WHEN l.programStatus NOT LIKE @elExitedLike
                 AND l.programStatus NOT LIKE @elNotLike     -- not EL
                 AND l.programStatus NOT LIKE @elPendingLike    -- pending
                 AND NULLIF(LTRIM(RTRIM(l.programStatus)), '') IS NOT NULL
                 AND l.exitDate IS NULL THEN 1 ELSE 0 END AS isCurrentEL
    FROM Lep l
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       el.programStatus AS [EL Status],
       CONVERT(date, el.identifiedDate) AS [Identified Date], CONVERT(date, el.exitDate) AS [Exit Date],
       x.issue AS [Issue]
FROM act a
JOIN el           ON el.personID  = a.personID
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN el.noStatus = 1 THEN 'EL record has no program status' END),
    (CASE WHEN el.isCurrentEL = 1 AND i.dateEnteredUSSchool IS NULL THEN 'EL with no first-US-school date' END),
    (CASE WHEN el.isExited = 1 AND el.exitDate IS NULL THEN 'Exited EL with no exit date' END),
    (CASE WHEN el.isExited = 0 AND el.noStatus = 0 AND el.exitDate IS NOT NULL
          THEN 'Exit date is set but the program status is not exited' END)
) x(issue)
WHERE a.rn = 1
  AND x.issue IS NOT NULL
ORDER BY a.schoolName, x.issue, a.grade, i.lastName, i.firstName;
