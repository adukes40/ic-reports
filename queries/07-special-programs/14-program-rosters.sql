/* ======================================================================================
   #92  Program rosters
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Special programs
   Type:      List · Priority 2 · Run Ongoing
   Purpose:   Active students in a program on @asOf, by school and grade, with the start
              date. Covers programs and flags (program participation) plus EL, homeless
              and foster care, which have their own records.
   Output:    One row per student per program record: school, grade, program ID, program,
              start date
   Tables:    SchoolYear, Enrollment, Calendar, School, ProgramParticipation, Program,
              Lep, Homeless, FosterCare, Person, Identity
   Params:    @endYear, @schoolID, @asOf, @programID  (change them in the PARAMETERS
              block below)
   Check:     Run once with @programID = NULL to see your program IDs. EL uses ID -1,
              homeless -2, foster care -3. EL means an EL record with no exit date whose
              status does not start with 'Exit', 'Not' or 'Pend' (IC's standard codes).
              Military-connected and gifted students appear only if they are kept as a
              program or flag; their own IC tables are not in use here.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear   int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID  int  = NULL;   -- NULL = all schools
DECLARE @asOf      date = CONVERT(date, GETDATE());
DECLARE @programID int  = NULL;   -- NULL = all programs; -1 = EL, -2 = homeless, -3 = foster care
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
member AS (   -- program records in effect on @asOf, from program participation and each program's own table
    SELECT pp.personID, pp.programID, CAST(pr.name AS varchar(60)) AS program, CONVERT(date, pp.startDate) AS startDate
    FROM ProgramParticipation pp
    JOIN Program pr ON pr.programID = pp.programID
    WHERE pp.startDate <= @asOf AND (pp.endDate IS NULL OR pp.endDate >= @asOf)
    UNION ALL
    SELECT l.personID, -1, 'EL', CONVERT(date, l.identifiedDate)
    FROM Lep l
    WHERE l.identifiedDate <= @asOf AND l.exitDate IS NULL
      AND l.programStatus NOT LIKE 'Exit%'     -- exited
      AND l.programStatus NOT LIKE 'Not%'      -- not EL
      AND l.programStatus NOT LIKE 'Pend%'     -- pending
    UNION ALL
    SELECT h.personID, -2, 'Homeless', CONVERT(date, h.startDate)
    FROM Homeless h
    WHERE h.startDate <= @asOf AND (h.endDate IS NULL OR h.endDate >= @asOf)
    UNION ALL
    SELECT f.personID, -3, 'Foster care', CONVERT(date, f.startDate)
    FROM FosterCare f
    WHERE f.startDate <= @asOf AND (f.endDate IS NULL OR f.endDate >= @asOf)
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       m.programID AS [Program ID], m.program AS [Program], m.startDate AS [Start Date]
FROM act a
JOIN member m     ON m.personID   = a.personID
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND (@programID IS NULL OR m.programID = @programID)
ORDER BY m.program, a.schoolName, a.grade, i.lastName, i.firstName;
