/* ======================================================================================
   #32  Bad name characters
   --------------------------------------------------------------------------------------
   Status:    Confirmed good
   Category:  Demographics
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Student and guardian first/last names with odd characters, one character long,
              a leading apostrophe, or a suffix in the name.
   Output:    One row per name per problem: person type, relationship, field, value, issue
              (guardian rows carry the student's school and grade)
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, RelatedPair
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Letters means A–Z, so accented names (José) are flagged. Suffix check covers
              Jr, Sr, II, III, IV only.
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
ppl AS (
    SELECT a.personID AS studentPersonID, a.personID, 'Student' AS personType,
           CAST(NULL AS varchar(50)) AS relationship
    FROM act a
    WHERE a.rn = 1
    UNION ALL
    SELECT a.personID, rp.personID2, 'Guardian', rp.name
    FROM act a
    JOIN RelatedPair rp ON rp.personID1 = a.personID
                    AND rp.guardian = 1
                    AND (rp.startDate IS NULL OR rp.startDate <= @asOf)
                    AND (rp.endDate   IS NULL OR rp.endDate   >= @asOf)
    WHERE a.rn = 1
),
nm AS (
    SELECT pp.studentPersonID, pp.personType, pp.relationship,
           i.lastName, i.firstName, f.fieldName, f.val
    FROM ppl pp
    JOIN Person p     ON p.personID   = pp.personID
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    CROSS APPLY (VALUES ('First name', i.firstName), ('Last name', i.lastName)) f(fieldName, val)
    WHERE NULLIF(LTRIM(RTRIM(f.val)), '') IS NOT NULL
)
SELECT sp.studentNumber AS [Student Number], si.lastName AS [Last Name], si.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       nm.personType AS [Person Type], nm.relationship AS [Relationship],
       nm.lastName AS [Person Last Name], nm.firstName AS [Person First Name],
       nm.fieldName AS [Name Field], nm.val AS [Name Value],
       x.issue AS [Issue]
FROM nm
JOIN act a        ON a.personID    = nm.studentPersonID AND a.rn = 1
JOIN Person sp    ON sp.personID   = nm.studentPersonID
JOIN [Identity] si ON si.identityID = sp.currentIdentityID
CROSS APPLY (VALUES
    (CASE WHEN PATINDEX('%[^A-Za-z ''.-]%', nm.val COLLATE Latin1_General_BIN) > 0
          THEN 'Has a character other than a letter, space, hyphen, apostrophe or period' END),
    (CASE WHEN LEN(LTRIM(RTRIM(nm.val))) = 1 THEN 'Only one character long' END),
    (CASE WHEN LTRIM(nm.val) LIKE '''%' THEN 'Starts with an apostrophe' END),
    -- shortcut: only these five suffixes; add others your district sees
    (CASE WHEN UPPER(REPLACE(RTRIM(nm.val), '.', '')) LIKE '%[ ,]JR'
            OR UPPER(REPLACE(RTRIM(nm.val), '.', '')) LIKE '%[ ,]SR'
            OR UPPER(REPLACE(RTRIM(nm.val), '.', '')) LIKE '%[ ,]II'
            OR UPPER(REPLACE(RTRIM(nm.val), '.', '')) LIKE '%[ ,]III'
            OR UPPER(REPLACE(RTRIM(nm.val), '.', '')) LIKE '%[ ,]IV'
          THEN 'Ends in a suffix (belongs in the suffix field)' END)
) x(issue)
WHERE x.issue IS NOT NULL
ORDER BY a.schoolName, a.grade, si.lastName, nm.personType DESC;
