/* ======================================================================================
   #19  Duplicate people / duplicate IDs
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Enrollment & census
   Type:      Validation · Priority 1 · Run Ongoing
   Purpose:   Same first name, last name and birthdate, plus any studentNumber or stateID
              shared by two or more people.
   Output:    One row per person in a match group: match_type, match_key, people in group,
              latest school and grade
   Tables:    Calendar, School, Enrollment, Person, Identity
   Params:    @endYear, @studentsOnly (1)  (change them in the PARAMETERS block below)
   Check:     Name matching is exact after trimming and upper-casing; nicknames and typos
              won't match.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear      int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @studentsOnly bit = 1;   -- 1 = only people with any enrollment
-- ===========================================================================

WITH ppl AS (
    SELECT p.personID, p.studentNumber, p.stateID, i.lastName, i.firstName, i.birthdate,
           UPPER(LTRIM(RTRIM(i.firstName))) + '|' + UPPER(LTRIM(RTRIM(i.lastName))) + '|'
             + CONVERT(varchar(10), i.birthdate, 23) AS nameKey
    FROM Person p
    JOIN [Identity] i ON i.identityID = p.currentIdentityID
    WHERE @studentsOnly = 0 OR EXISTS (SELECT 1 FROM Enrollment e WHERE e.personID = p.personID)
),
m AS (
    SELECT personID, 'Same name + birthdate' AS match_type, nameKey AS match_key
    FROM ppl
    WHERE birthdate IS NOT NULL
      AND nameKey IN (SELECT nameKey FROM ppl WHERE birthdate IS NOT NULL
                      GROUP BY nameKey HAVING COUNT(*) > 1)
    UNION ALL
    SELECT personID, 'Shared studentNumber', LTRIM(RTRIM(studentNumber))
    FROM ppl
    WHERE NULLIF(LTRIM(RTRIM(studentNumber)), '') IS NOT NULL
      AND LTRIM(RTRIM(studentNumber)) IN (SELECT LTRIM(RTRIM(studentNumber)) FROM ppl
                                          WHERE NULLIF(LTRIM(RTRIM(studentNumber)), '') IS NOT NULL
                                          GROUP BY LTRIM(RTRIM(studentNumber)) HAVING COUNT(*) > 1)
    UNION ALL
    SELECT personID, 'Shared stateID', LTRIM(RTRIM(stateID))
    FROM ppl
    WHERE NULLIF(LTRIM(RTRIM(stateID)), '') IS NOT NULL
      AND LTRIM(RTRIM(stateID)) IN (SELECT LTRIM(RTRIM(stateID)) FROM ppl
                                    WHERE NULLIF(LTRIM(RTRIM(stateID)), '') IS NOT NULL
                                    GROUP BY LTRIM(RTRIM(stateID)) HAVING COUNT(*) > 1)
)
SELECT pp.studentNumber AS [Student Number], pp.lastName AS [Last Name], pp.firstName AS [First Name],
       le.schoolID AS [School ID], le.schoolName AS [School], le.endYear AS [School Year], le.grade AS [Grade],
       pp.personID AS [Person ID], pp.stateID AS [State ID], CONVERT(date, pp.birthdate) AS [Birth Date],
       m.match_type AS [Match Type], m.match_key AS [Match Key],
       COUNT(*) OVER (PARTITION BY m.match_type, m.match_key) AS [People In Group],
       'Possible duplicate person' AS [Issue]
FROM m
JOIN ppl pp ON pp.personID = m.personID
OUTER APPLY (SELECT TOP 1 c.schoolID, s.name AS schoolName, c.endYear, e.grade
             FROM Enrollment e
             JOIN Calendar c ON c.calendarID = e.calendarID
             JOIN School   s ON s.schoolID   = c.schoolID
             WHERE e.personID = pp.personID
             ORDER BY c.endYear DESC, e.startDate DESC) le
ORDER BY m.match_type, m.match_key, pp.personID;
