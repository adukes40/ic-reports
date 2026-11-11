/* ======================================================================================
   #36  Duplicate contacts
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Demographics
   Type:      Validation · Priority 2 · Run Ongoing
   Purpose:   Pairs of guardian records with the same first and last name and a shared
              phone number, linked to the same student or to students in the same
              household. Usually one parent entered twice.
   Output:    One row per student per duplicate pair: both guardian person IDs and names,
              the shared phone, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HouseholdMember,
              RelatedPair, Contact
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Phones compared are home, cell and work on the contact record, ignoring
              punctuation; the household phone is not used. Confirm the two records are
              the same person before combining them.
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
),
fam AS (   -- each active student with the current guardians of everyone in the student's current households
    SELECT DISTINCT a.personID, rp.personID2 AS guardianID
    FROM act a
    CROSS APPLY (
        SELECT a.personID AS memberID
        UNION
        SELECT m2.personID
        FROM HouseholdMember m1
        JOIN HouseholdMember m2 ON m2.householdID = m1.householdID
        WHERE m1.personID = a.personID
          AND (m1.startDate IS NULL OR m1.startDate <= @asOf) AND (m1.endDate IS NULL OR m1.endDate >= @asOf)
          AND (m2.startDate IS NULL OR m2.startDate <= @asOf) AND (m2.endDate IS NULL OR m2.endDate >= @asOf)
    ) mem
    JOIN RelatedPair rp ON rp.personID1 = mem.memberID
                        AND rp.guardian = 1
                        AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
                        AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
    WHERE a.rn = 1
),
ph AS (   -- every phone number on a contact record, punctuation removed
    SELECT DISTINCT con.personID, d.digits
    FROM Contact con
    CROSS APPLY (VALUES (con.homePhone), (con.cellPhone), (con.workPhone)) v(phone)
    CROSS APPLY (SELECT REPLACE(TRANSLATE(v.phone, '()-.+', '     '), ' ', '') AS digits) d
    WHERE LEN(d.digits) >= 7
)
SELECT sp.studentNumber AS [Student Number], si.lastName AS [Last Name], si.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       f1.guardianID AS [Guardian 1 Person ID], i1.lastName AS [Guardian 1 Last Name], i1.firstName AS [Guardian 1 First Name],
       f2.guardianID AS [Guardian 2 Person ID], i2.lastName AS [Guardian 2 Last Name], i2.firstName AS [Guardian 2 First Name],
       shared.phone AS [Shared Phone],
       'Two guardian records share a name and phone number' AS [Issue]
FROM fam f1
JOIN fam f2        ON f2.personID = f1.personID AND f2.guardianID > f1.guardianID
JOIN act a         ON a.personID   = f1.personID AND a.rn = 1
JOIN Person sp     ON sp.personID  = f1.personID
JOIN [Identity] si ON si.identityID = sp.currentIdentityID
JOIN Person p1     ON p1.personID  = f1.guardianID
JOIN [Identity] i1 ON i1.identityID = p1.currentIdentityID
JOIN Person p2     ON p2.personID  = f2.guardianID
JOIN [Identity] i2 ON i2.identityID = p2.currentIdentityID
CROSS APPLY (
    SELECT MIN(ph1.digits) AS phone
    FROM ph ph1
    JOIN ph ph2 ON ph2.digits = ph1.digits
    WHERE ph1.personID = f1.guardianID
      AND ph2.personID = f2.guardianID
) shared
WHERE UPPER(LTRIM(RTRIM(i1.lastName)))  = UPPER(LTRIM(RTRIM(i2.lastName)))
  AND UPPER(LTRIM(RTRIM(i1.firstName))) = UPPER(LTRIM(RTRIM(i2.firstName)))
  AND shared.phone IS NOT NULL
ORDER BY a.schoolName, a.grade, si.lastName, si.firstName, i1.lastName;
