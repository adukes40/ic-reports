/* ======================================================================================
   #134  Roster sync readiness
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Tech, integrations & security
   Type:      Validation · Priority 1 · Run BOY, weekly
   Purpose:   What a OneRoster, Google or ClassLink roster sync will trip over: sections
              with students but no primary teacher or no teacher email, and active students
              with no email, no usable grade, or no class.
   Output:    One row per problem: record type (Section or Student), student or teacher
              name, student number, school, grade, course and section, issue
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, Contact, Trial,
              Section, Course, Roster, SectionStaffHistory, GradeLevel
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     The primary teacher is the section staff history row with staffType 'P' that
              is current on @asOf, or else the teacher stored on the section: confirm 'P'
              is your primary teacher code. Email is the primary email on the contact
              record. Only sections with at least one student rostered on @asOf are
              checked. A grade counts as usable when it exists in the calendar's grade
              levels with a state grade.
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
    SELECT e.personID, e.calendarID, e.structureID, c.schoolID, s.name AS schoolName, c.endYear, e.grade,
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
em AS (   -- people who have a primary email
    SELECT DISTINCT con.personID
    FROM Contact con
    WHERE NULLIF(LTRIM(RTRIM(con.email)), '') IS NOT NULL
),
sec AS (   -- active-trial sections with at least one student rostered on @asOf
    SELECT se.sectionID, se.number AS sectionNumber, se.teacherPersonID,
           co.number AS courseNumber, co.name AS courseName,
           c.schoolID, s.name AS schoolName, c.endYear
    FROM Trial t
    JOIN Calendar c ON c.calendarID = t.calendarID
    JOIN School   s ON s.schoolID   = c.schoolID
    JOIN Section se ON se.trialID   = t.trialID
    JOIN Course  co ON co.courseID  = se.courseID
    WHERE t.active = 1
      AND c.endYear = @endYear
      AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
      AND (@schoolID IS NULL OR c.schoolID = @schoolID)
      AND EXISTS (SELECT 1 FROM Roster r
                  WHERE r.sectionID = se.sectionID AND r.trialID = t.trialID
                    AND (r.startDate IS NULL OR r.startDate <= @asOf)
                    AND (r.endDate IS NULL OR r.endDate >= @asOf))
),
secTeacher AS (   -- each of those sections with its primary teacher, if any
    SELECT sec.*, COALESCE(pt.personID, sec.teacherPersonID) AS teacherID
    FROM sec
    OUTER APPLY (SELECT TOP 1 h.personID
                 FROM SectionStaffHistory h
                 WHERE h.sectionID = sec.sectionID
                   AND h.staffType = 'P'   -- primary teacher
                   AND (h.startDate IS NULL OR h.startDate <= @asOf)
                   AND (h.endDate IS NULL OR h.endDate >= @asOf)
                 ORDER BY h.historyID DESC) pt
),
stu AS (   -- each active student with the three readiness tests
    SELECT a.personID, a.schoolID, a.schoolName, a.endYear, a.grade,
           CASE WHEN em.personID IS NULL THEN 1 ELSE 0 END AS noEmail,
           CASE WHEN NULLIF(LTRIM(RTRIM(a.grade)), '') IS NULL
                  OR NOT EXISTS (SELECT 1 FROM GradeLevel gl
                                 WHERE gl.calendarID = a.calendarID AND gl.structureID = a.structureID
                                   AND gl.name = a.grade
                                   AND NULLIF(LTRIM(RTRIM(gl.stateGrade)), '') IS NOT NULL)
                THEN 1 ELSE 0 END AS noGrade,
           CASE WHEN NOT EXISTS (SELECT 1
                                 FROM Trial t
                                 JOIN Section se ON se.trialID = t.trialID
                                 JOIN Roster r   ON r.sectionID = se.sectionID AND r.trialID = t.trialID
                                 WHERE t.calendarID = a.calendarID AND t.active = 1
                                   AND r.personID = a.personID
                                   AND (r.startDate IS NULL OR r.startDate <= @asOf)
                                   AND (r.endDate IS NULL OR r.endDate >= @asOf))
                THEN 1 ELSE 0 END AS noRoster
    FROM act a
    LEFT JOIN em ON em.personID = a.personID
    WHERE a.rn = 1
)
SELECT 'Section' AS [Record Type], ti.lastName AS [Last Name], ti.firstName AS [First Name],
       CAST(NULL AS varchar(15)) AS [Student Number],
       st.schoolID AS [School ID], st.schoolName AS [School], st.endYear AS [School Year],
       CAST(NULL AS varchar(4)) AS [Grade],
       st.courseNumber AS [Course Number], st.courseName AS [Course Name], st.sectionNumber AS [Section Number],
       CASE WHEN st.teacherID IS NULL THEN 'Section has no primary teacher'
            ELSE 'Primary teacher has no email' END AS [Issue]
FROM secTeacher st
LEFT JOIN Person tp     ON tp.personID   = st.teacherID
LEFT JOIN [Identity] ti ON ti.identityID = tp.currentIdentityID
WHERE st.teacherID IS NULL
   OR NOT EXISTS (SELECT 1 FROM em WHERE em.personID = st.teacherID)
UNION ALL
SELECT 'Student', i.lastName, i.firstName, p.studentNumber,
       k.schoolID, k.schoolName, k.endYear, k.grade,
       NULL, NULL, NULL,
       v.issue
FROM stu k
JOIN Person p     ON p.personID   = k.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
CROSS APPLY (VALUES (k.noEmail,  'Student has no email'),
                    (k.noGrade,  'Grade is blank or has no state grade mapping in the calendar'),
                    (k.noRoster, 'Student is not rostered in any section')) v(flag, issue)
WHERE v.flag = 1
ORDER BY [School], [Record Type], [Course Number], [Section Number], [Last Name], [First Name];
