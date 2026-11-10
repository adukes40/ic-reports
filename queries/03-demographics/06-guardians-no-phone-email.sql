/* ======================================================================================
   #35  Guardians with no phone or email
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      Validation · Priority 1 · Run BOY, ongoing
   Purpose:   Current guardians of active students with no phone (home, cell, work) or no
              email (primary, secondary) on their contact record.
   Output:    One row per student-guardian pair: guardian name, relationship, which is
              missing
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, RelatedPair,
              Contact
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     The household phone doesn't count as the guardian's phone.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
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
SELECT sp.studentNumber AS [Student Number], si.lastName AS [Last Name], si.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       gi.lastName AS [Guardian Last Name], gi.firstName AS [Guardian First Name],
       rp.name AS [Relationship],
       CASE WHEN ct.contactRows = 0              THEN 'No contact record'
            WHEN ct.hasPhone = 0 AND ct.hasEmail = 0 THEN 'No phone and no email'
            WHEN ct.hasPhone = 0                 THEN 'No phone'
            ELSE 'No email' END AS [Issue]
FROM act a
JOIN RelatedPair rp ON rp.personID1 = a.personID
                    AND rp.guardian = 1
                    AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
                    AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
JOIN Person sp     ON sp.personID   = a.personID
JOIN [Identity] si ON si.identityID = sp.currentIdentityID
JOIN Person gp     ON gp.personID   = rp.personID2
JOIN [Identity] gi ON gi.identityID = gp.currentIdentityID
CROSS APPLY (
    SELECT COUNT(*) AS contactRows,
           ISNULL(MAX(CASE WHEN COALESCE(NULLIF(LTRIM(RTRIM(con.homePhone)), ''),
                                         NULLIF(LTRIM(RTRIM(con.cellPhone)), ''),
                                         NULLIF(LTRIM(RTRIM(con.workPhone)), '')) IS NOT NULL
                           THEN 1 ELSE 0 END), 0) AS hasPhone,
           ISNULL(MAX(CASE WHEN COALESCE(NULLIF(LTRIM(RTRIM(con.email)), ''),
                                         NULLIF(LTRIM(RTRIM(con.secondaryEmail)), '')) IS NOT NULL
                           THEN 1 ELSE 0 END), 0) AS hasEmail
    FROM Contact con
    WHERE con.personID = rp.personID2
) ct
WHERE a.rn = 1
  AND (ct.hasPhone = 0 OR ct.hasEmail = 0)
ORDER BY a.schoolName, a.grade, si.lastName, gi.lastName;
