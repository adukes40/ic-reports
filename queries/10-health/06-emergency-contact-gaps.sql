/* ======================================================================================
   #117  Emergency contact gaps
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Health & compliance
   Type:      Validation · Priority 1 · Run BOY
   Purpose:   Active students with fewer than two current emergency contacts that have a
              phone number.
   Output:    One row per student: emergency contacts on file, how many have a phone,
              issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, RelatedPair,
              Contact
   Params:    @endYear, @schoolID, @asOf, @minWithPhone  (change them in the PARAMETERS
              block below)
   Check:     Emergency contact = a current relationship with an Emergency Priority
              (Seq) number. Phone = home, cell or work on the contact's own record; the
              household phone doesn't count.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID     int  = NULL;   -- NULL = all schools
DECLARE @asOf         date = CONVERT(date, GETDATE());
DECLARE @minWithPhone int  = 2;      -- emergency contacts with a phone each student should have
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
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       ec.contacts AS [Emergency Contacts], ec.withPhone AS [With Phone],
       CASE WHEN ec.contacts = 0  THEN 'No emergency contacts'
            WHEN ec.withPhone = 0 THEN 'No emergency contact has a phone'
            WHEN ec.withPhone = 1 THEN 'Only one emergency contact has a phone'
            ELSE 'Fewer than ' + CAST(@minWithPhone AS varchar(10)) + ' emergency contacts have a phone' END AS [Issue]
FROM act a
JOIN Person p     ON p.personID   = a.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (
    SELECT COUNT(DISTINCT rp.personID2) AS contacts,
           COUNT(DISTINCT CASE WHEN ph.hasPhone = 1 THEN rp.personID2 END) AS withPhone
    FROM RelatedPair rp
    OUTER APPLY (SELECT TOP 1 1 AS hasPhone
                 FROM Contact con
                 WHERE con.personID = rp.personID2
                   AND COALESCE(NULLIF(LTRIM(RTRIM(con.homePhone)), ''),
                                NULLIF(LTRIM(RTRIM(con.cellPhone)), ''),
                                NULLIF(LTRIM(RTRIM(con.workPhone)), '')) IS NOT NULL) ph
    WHERE rp.personID1 = a.personID
      AND rp.seq IS NOT NULL
      AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
      AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
) ec
WHERE a.rn = 1
  AND ec.withPhone < @minWithPhone
ORDER BY a.schoolName, a.grade, i.lastName, i.firstName;
