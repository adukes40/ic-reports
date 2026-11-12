/* ======================================================================================
   #127  Mailing labels / mail merge
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 3 · Run On request
   Purpose:   One mailing label per household for active students in the chosen school and
              grades: guardians, students and mailing address. Used by school offices for
              letters and mail merges.
   Output:    One row per household per school: household ID, addressee (guardians),
              students, address line 1, apartment, city, state, zip
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, HouseholdMember,
              RelatedPair, HouseholdLocation, Address
   Params:    @endYear, @schoolID, @asOf, @grades  (change them in the PARAMETERS block
              below)
   Check:     @grades must use your grade codes exactly, for example '09,10' or 'KN,01'.
              The addressee is every current guardian who lives in the student's primary
              household; with none, it reads 'Parent/Guardian of' the students. The address
              is the household's current address marked Mailing, otherwise any current one.
              Households with no current address come out with a blank address.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID int  = NULL;   -- NULL = all schools
DECLARE @asOf     date = CONVERT(date, GETDATE());
DECLARE @grades   varchar(200) = NULL;   -- comma-separated grades, e.g. '09,10'; NULL = all grades
-- ===========================================================================

WITH act AS (   -- one active primary enrollment per student on @asOf, in the chosen grades
    SELECT e.personID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
           ROW_NUMBER() OVER (PARTITION BY e.personID ORDER BY e.startDate DESC, e.enrollmentID DESC) AS rn
    FROM Enrollment e
    JOIN Calendar c ON c.calendarID = e.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    WHERE c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND (@grades IS NULL OR e.grade IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@grades, ',')))
      AND e.serviceType = 'P' AND ISNULL(e.noShow, 0) = 0
      AND e.startDate <= @asOf AND (e.endDate IS NULL OR e.endDate >= @asOf)
),
stuHH AS (   -- each active student's current primary household
    SELECT DISTINCT a.personID, a.schoolID, a.schoolName, a.endYear, hm.householdID
    FROM act a
    JOIN HouseholdMember hm ON hm.personID = a.personID
    WHERE a.rn = 1
      AND ISNULL(hm.secondary, 0) = 0
      AND (hm.startDate IS NULL OR hm.startDate <= @asOf)
      AND (hm.endDate   IS NULL OR hm.endDate   >= @asOf)
),
stu AS (   -- student names per household per school
    SELECT sh.householdID, sh.schoolID, sh.schoolName, sh.endYear,
           STRING_AGG(CAST(i.firstName + ' ' + i.lastName AS varchar(max)), ', ')
               WITHIN GROUP (ORDER BY i.lastName, i.firstName) AS students
    FROM stuHH sh
    JOIN Person p     ON p.personID   = sh.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    GROUP BY sh.householdID, sh.schoolID, sh.schoolName, sh.endYear
),
grd AS (   -- current guardians of those students who live in the same household
    SELECT DISTINCT sh.householdID, sh.schoolID, rp.personID2 AS guardianID
    FROM stuHH sh
    JOIN RelatedPair rp ON rp.personID1 = sh.personID
                        AND rp.guardian = 1
                        AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
                        AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
    JOIN HouseholdMember gm ON gm.householdID = sh.householdID
                            AND gm.personID = rp.personID2
                            AND (gm.startDate IS NULL OR gm.startDate <= @asOf)
                            AND (gm.endDate   IS NULL OR gm.endDate   >= @asOf)
),
grdNames AS (   -- guardian names per household per school
    SELECT g.householdID, g.schoolID,
           STRING_AGG(CAST(gi.firstName + ' ' + gi.lastName AS varchar(max)), ' and ')
               WITHIN GROUP (ORDER BY gi.lastName, gi.firstName) AS guardians
    FROM grd g
    JOIN Person gp     ON gp.personID   = g.guardianID
    JOIN [Identity] gi ON gi.identityID = gp.currentIdentityID
    GROUP BY g.householdID, g.schoolID
)
SELECT st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year],
       st.householdID AS [Household ID],
       COALESCE(gn.guardians, 'Parent/Guardian of ' + st.students) AS [Addressee],
       st.students AS [Students],
       CASE WHEN ad.postOfficeBox = 1 THEN 'PO Box ' + ad.number
            ELSE CONCAT_WS(' ', NULLIF(ad.number, ''), NULLIF(ad.prefix, ''), NULLIF(ad.street, ''),
                           NULLIF(ad.tag, ''), NULLIF(ad.dir, '')) END AS [Address Line 1],
       ad.apt AS [Apartment], ad.city AS [City], ad.state AS [State], ad.zip AS [Zip]
FROM stu st
LEFT JOIN grdNames gn ON gn.householdID = st.householdID AND gn.schoolID = st.schoolID
OUTER APPLY (
    SELECT TOP 1 adr.postOfficeBox, adr.number, adr.prefix, adr.street, adr.tag, adr.dir, adr.apt,
                 adr.city, adr.state, adr.zip
    FROM HouseholdLocation hl
    JOIN [Address] adr ON adr.addressID = hl.addressID
    WHERE hl.householdID = st.householdID
      AND (hl.startDate IS NULL OR hl.startDate <= @asOf)
      AND (hl.endDate   IS NULL OR hl.endDate   >= @asOf)
    ORDER BY ISNULL(hl.mailing, 0) DESC, ISNULL(hl.secondary, 0), adr.addressID DESC
) ad
ORDER BY st.schoolName, ad.zip, [Addressee];
