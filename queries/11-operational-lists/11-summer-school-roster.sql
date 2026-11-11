/* ======================================================================================
   #128  Summer school roster
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 3 · Run On request
   Purpose:   Students enrolled in a summer school calendar with grade, home school,
              guardian phone numbers and whether they have an active IEP, 504 plan or EL
              status. Used by summer school staff and nurses.
   Output:    One row per summer enrollment: calendar, grade, start and end date, home
              school, guardian phones, IEP / 504 / EL as Y or N
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, RelatedPair,
              Contact, Plan, PlanType, Section504, Lep
   Params:    @endYear, @schoolID, @calendarID, @asOf  (change them in the PARAMETERS block
              below)
   Check:     Summer calendars are those with the Summer School box checked. Home school is
              the student's most recent primary enrollment in a regular calendar. IEP = a
              locked special ed plan whose type name or abbreviation contains 'IEP', active
              on @asOf; 504 = a Section 504 record active on @asOf; EL = Lep program status
              'LEP' and not exited. Confirm those against two or three students.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear    int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID   int  = NULL;   -- NULL = all schools
DECLARE @calendarID int  = NULL;   -- one summer calendar; NULL = every summer calendar in @endYear
DECLARE @asOf       date = CONVERT(date, GETDATE());   -- plans and guardians current on this date
-- ===========================================================================

WITH ss AS (   -- enrollments in summer school calendars
    SELECT e.personID, e.grade, e.startDate, e.endDate,
           c.calendarID, c.name AS calendarName, c.schoolID, s.name AS schoolName, c.endYear
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.summerSchool = 1
      AND c.exclude = 0 AND s.exclude = 0
      AND (c.calendarID = @calendarID OR (@calendarID IS NULL AND c.endYear = @endYear))
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND ISNULL(e.noShow, 0) = 0
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       ss.schoolID AS [School ID], ss.schoolName AS [School], ss.endYear AS [School Year], ss.grade AS [Grade],
       ss.calendarName AS [Summer Calendar],
       CONVERT(date, ss.startDate) AS [Start Date], CONVERT(date, ss.endDate) AS [End Date],
       home.schoolName AS [Home School],
       g.phones AS [Guardian Phones],
       CASE WHEN EXISTS (SELECT 1 FROM [Plan] pl
                         JOIN PlanType pt ON pt.typeID = pl.typeID
                         WHERE pl.personID = ss.personID
                           AND pt.module = 'specialEd'
                           AND (pt.name LIKE '%IEP%' OR pt.abbreviation LIKE '%IEP%')
                           AND pl.locked = 1
                           AND pl.startDate <= @asOf AND (pl.endDate IS NULL OR pl.endDate >= @asOf))
            THEN 'Y' ELSE 'N' END AS [IEP],
       CASE WHEN EXISTS (SELECT 1 FROM Section504 sf
                         WHERE sf.personID = ss.personID
                           AND sf.startDate <= @asOf AND (sf.endDate IS NULL OR sf.endDate >= @asOf))
            THEN 'Y' ELSE 'N' END AS [504],
       CASE WHEN EXISTS (SELECT 1 FROM Lep l
                         WHERE l.personID = ss.personID AND l.programStatus = 'LEP'
                           AND l.identifiedDate <= @asOf AND (l.exitDate IS NULL OR l.exitDate > @asOf))
            THEN 'Y' ELSE 'N' END AS [EL]
FROM ss
JOIN Person p     ON p.personID   = ss.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
OUTER APPLY (
    SELECT TOP 1 hs.name AS schoolName
    FROM Enrollment he
    JOIN Calendar hc ON hc.calendarID = he.calendarID
    JOIN School   hs ON hs.schoolID   = hc.schoolID
    WHERE he.personID = ss.personID
      AND he.serviceType = 'P' AND ISNULL(he.noShow, 0) = 0
      AND hc.summerSchool = 0 AND hc.exclude = 0 AND hs.exclude = 0
      AND hc.endYear <= ss.endYear
    ORDER BY he.startDate DESC, he.enrollmentID DESC
) home
OUTER APPLY (
    SELECT STRING_AGG(CAST(gi.firstName + ' ' + gi.lastName + ': ' + ph.phone AS varchar(max)), '; ')
               WITHIN GROUP (ORDER BY gi.lastName, gi.firstName) AS phones
    FROM RelatedPair rp
    JOIN Person gp     ON gp.personID   = rp.personID2
    JOIN [Identity] gi ON gi.identityID = gp.currentIdentityID
    JOIN Contact con   ON con.personID  = rp.personID2
    CROSS APPLY (SELECT COALESCE(NULLIF(LTRIM(RTRIM(con.cellPhone)), ''),
                                 NULLIF(LTRIM(RTRIM(con.homePhone)), ''),
                                 NULLIF(LTRIM(RTRIM(con.workPhone)), '')) AS phone) ph
    WHERE rp.personID1 = ss.personID
      AND rp.guardian = 1
      AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
      AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
      AND ph.phone IS NOT NULL
) g
ORDER BY ss.schoolName, ss.calendarName, i.lastName, i.firstName;
