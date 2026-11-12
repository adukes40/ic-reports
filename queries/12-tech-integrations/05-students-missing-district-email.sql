/* ======================================================================================
   #133  Students missing district email
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 1 · Run BOY, weekly
   Purpose:   Active students with no email on their contact record, an email outside the
              district's student domain, or an email that another person also has.
   Output:    One row per student with a problem: student number, name, school, grade,
              email, how many people share it, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, Contact
   Params:    @endYear, @schoolID, @asOf, @emailDomain  (change them in the PARAMETERS block
              below)
   Check:     Set @emailDomain to your student domain (for example students.district.org);
              left as '' the domain test is skipped. The student email is read from the
              primary email on the contact record (Contact.email), not the secondary
              email. Shared addresses are counted across everyone's primary email, so a
              student using a parent's address is caught.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear     int          = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID    int          = NULL;   -- NULL = all schools
DECLARE @asOf        date         = CONVERT(date, GETDATE());
DECLARE @emailDomain varchar(100) = '';     -- student email domain, e.g. 'students.district.org'; '' = skip the domain test
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
em AS (   -- one primary email per person, trimmed and lower-cased
    SELECT con.personID, MIN(LOWER(LTRIM(RTRIM(con.email)))) AS email
    FROM Contact con
    WHERE NULLIF(LTRIM(RTRIM(con.email)), '') IS NOT NULL
    GROUP BY con.personID
),
shared AS (   -- how many people have each email
    SELECT em.email, COUNT(*) AS people
    FROM em
    GROUP BY em.email
),
chk AS (   -- each active student's email and the three tests
    SELECT a.personID, a.schoolID, a.schoolName, a.endYear, a.grade, em.email, sh.people,
           CASE WHEN em.email IS NULL THEN 1 ELSE 0 END AS noEmail,
           CASE WHEN @emailDomain <> '' AND em.email NOT LIKE '%@' + REPLACE(@emailDomain, '@', '')
                THEN 1 ELSE 0 END AS wrongDomain,
           CASE WHEN sh.people > 1 THEN 1 ELSE 0 END AS isShared
    FROM act a
    LEFT JOIN em        ON em.personID = a.personID
    LEFT JOIN shared sh ON sh.email    = em.email
    WHERE a.rn = 1
)
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       k.schoolID AS [School ID], k.schoolName AS [School], k.endYear AS [School Year], k.grade AS [Grade],
       k.email AS [Email], k.people AS [People With This Email],
       CASE WHEN k.noEmail = 1 THEN 'No email'
            ELSE CONCAT_WS('; ',
                     CASE WHEN k.wrongDomain = 1 THEN 'Email is not in the district student domain' END,
                     CASE WHEN k.isShared = 1 THEN 'Email is shared with another person' END) END AS [Issue]
FROM chk k
JOIN Person p     ON p.personID   = k.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
WHERE k.noEmail = 1 OR k.wrongDomain = 1 OR k.isShared = 1
ORDER BY k.schoolName, k.grade, i.lastName, i.firstName;
