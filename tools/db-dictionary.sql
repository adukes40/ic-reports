/* ======================================================================================
   Database inventory: code values (the dictionary)
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Type:      Tool (not part of the query library; it is not published on the site)
   Purpose:   Lists the code values the district uses: the Campus dictionary, the setup
              lists (attendance excuses, behavior types and resolutions, grade levels,
              grading tasks, marks, plan types, flags, vaccines, enrollment statuses), and
              which codes are actually in use on a few key fields. Queries that test for a
              code (absent, offender, suspension and so on) are checked against this.
   Output:    One row per code: where it comes from, the field, the code, its name, extra
              detail, and for in-use values how many rows carry it. Codes, names and counts
              only: no student, staff or contact values are returned.
   Tables:    CampusAttribute, CampusDictionary, AttendanceExcuse, BehaviorType,
              BehaviorResType, BehaviorResponseType, GradeLevel, GradingTask, Term,
              ScoreListItem, PlanType, Program, Vaccine, CurriculumStandard,
              EnrollmentStartStatusType, EnrollmentEndStatusType, SchoolYear, Calendar,
              BehaviorRole, BehaviorIncident, Attendance, Enrollment, Lep,
              SectionStaffHistory, Request, AuditAttendance, Section504, UserAccount
   Params:    none
   Check:     The in-use counts read this year's attendance and enrollment rows, so run it
              outside the school day. A user home page is listed only when 10 or more
              accounts share it.
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file, paste it into IC's data extract tool, and save the
   result as CSV.
   ====================================================================================== */

DECLARE @endYear int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);

WITH cal AS (   -- this year's calendars, to keep the in-use counts quick
    SELECT calendarID FROM Calendar WHERE endYear = @endYear
),
codes AS (
    -- 1. Campus dictionary: every pick list in the product
    SELECT 'Dictionary' AS source, CAST(ca.object + '.' + ca.element AS nvarchar(200)) AS field,
           CAST(cd.code AS nvarchar(400)) AS code, CAST(cd.name AS nvarchar(400)) AS name,
           CAST(CASE WHEN cd.active = 1 THEN 'active' ELSE 'inactive' END
                + COALESCE(', standard code ' + NULLIF(cd.standardCode, ''), '') AS nvarchar(400)) AS extra,
           CAST(NULL AS bigint) AS rowsUsing
    FROM CampusDictionary cd
    JOIN CampusAttribute ca ON ca.attributeID = cd.attributeID

    -- 2. Setup lists the district maintains
    UNION ALL SELECT DISTINCT 'Setup list', 'AttendanceExcuse', code, description,
           'status ' + COALESCE(status, '(blank)') + ', excuse ' + COALESCE(excuse, '(blank)'), NULL FROM AttendanceExcuse
    UNION ALL SELECT DISTINCT 'Setup list', 'BehaviorType', code, name, 'state code ' + COALESCE(NULLIF(stateEventCode, ''), '(none)'), NULL FROM BehaviorType
    UNION ALL SELECT DISTINCT 'Setup list', 'BehaviorResType', code, name, 'state code ' + COALESCE(NULLIF(stateResCode, ''), '(none)'), NULL FROM BehaviorResType
    UNION ALL SELECT DISTINCT 'Setup list', 'BehaviorResponseType', code, name, 'response type ' + COALESCE(responseType, '(blank)'), NULL FROM BehaviorResponseType
    UNION ALL SELECT DISTINCT 'Setup list', 'GradeLevel', name, name, 'state grade ' + COALESCE(stateGrade, '(blank)'), NULL FROM GradeLevel
    UNION ALL SELECT DISTINCT 'Setup list', 'GradingTask', CAST(abbreviation AS nvarchar(400)), CAST(name AS nvarchar(400)), NULL, NULL FROM GradingTask
    UNION ALL SELECT DISTINCT 'Setup list', 'Term', name, name, NULL, NULL FROM Term
    UNION ALL SELECT DISTINCT 'Setup list', 'ScoreListItem (marks)', score, name, CASE WHEN passingScore = 1 THEN 'passing' ELSE 'not passing' END, NULL FROM ScoreListItem
    UNION ALL SELECT DISTINCT 'Setup list', 'PlanType', abbreviation, name, 'module ' + COALESCE(module, '(blank)'), NULL FROM PlanType
    UNION ALL SELECT DISTINCT 'Setup list', 'Program (flags and programs)', code, name, CASE WHEN flagged = 1 THEN 'flag' ELSE 'program' END, NULL FROM Program
    UNION ALL SELECT DISTINCT 'Setup list', 'Vaccine', code, description, 'abbreviation ' + COALESCE(abbreviation, '(blank)'), NULL FROM Vaccine
    UNION ALL SELECT DISTINCT 'Setup list', 'CurriculumStandard (credit types and standards)', NULL, CAST(name AS nvarchar(400)), CASE WHEN creditGroupInd = 1 THEN 'credit group' ELSE NULL END, NULL FROM CurriculumStandard
    UNION ALL SELECT DISTINCT 'Setup list', 'EnrollmentStartStatusType', code, name, 'state code ' + COALESCE(NULLIF(stateCode, ''), '(none)'), NULL FROM EnrollmentStartStatusType
    UNION ALL SELECT DISTINCT 'Setup list', 'EnrollmentEndStatusType', code, name, 'state code ' + COALESCE(NULLIF(stateCode, ''), '(none)'), NULL FROM EnrollmentEndStatusType

    -- 3. Codes actually in use on key fields, with how many rows carry each
    UNION ALL SELECT 'In use', 'BehaviorRole.role', role, NULL, NULL, COUNT_BIG(*) FROM BehaviorRole GROUP BY role
    UNION ALL SELECT 'In use', 'BehaviorIncident.status', status, NULL, NULL, COUNT_BIG(*) FROM BehaviorIncident GROUP BY status
    UNION ALL SELECT 'In use', 'Lep.programStatus', programStatus, NULL, NULL, COUNT_BIG(*) FROM Lep GROUP BY programStatus
    UNION ALL SELECT 'In use', 'Section504.programStatus', programStatus, NULL, NULL, COUNT_BIG(*) FROM Section504 GROUP BY programStatus
    UNION ALL SELECT 'In use', 'SectionStaffHistory.staffType', staffType, NULL, NULL, COUNT_BIG(*) FROM SectionStaffHistory GROUP BY staffType
    UNION ALL SELECT 'In use', 'Request.type', type, NULL, NULL, COUNT_BIG(*) FROM Request GROUP BY type
    UNION ALL SELECT 'In use', 'AuditAttendance.actionType', actionType, NULL, NULL, COUNT_BIG(*) FROM AuditAttendance GROUP BY actionType
    UNION ALL SELECT 'In use', 'Attendance.status + excuse (this year)', COALESCE(a.status, '(blank)') + ' / ' + COALESCE(a.excuse, '(blank)'), NULL, NULL, COUNT_BIG(*)
              FROM Attendance a JOIN cal ON cal.calendarID = a.calendarID GROUP BY a.status, a.excuse
    UNION ALL SELECT 'In use', 'Enrollment.serviceType (this year)', e.serviceType, NULL, NULL, COUNT_BIG(*)
              FROM Enrollment e JOIN cal ON cal.calendarID = e.calendarID GROUP BY e.serviceType
    UNION ALL SELECT 'In use', 'Enrollment.grade (this year)', e.grade, NULL, NULL, COUNT_BIG(*)
              FROM Enrollment e JOIN cal ON cal.calendarID = e.calendarID GROUP BY e.grade
    UNION ALL SELECT 'In use', 'Enrollment.startStatus (this year)', e.startStatus, NULL, NULL, COUNT_BIG(*)
              FROM Enrollment e JOIN cal ON cal.calendarID = e.calendarID GROUP BY e.startStatus
    UNION ALL SELECT 'In use', 'Enrollment.endStatus (this year)', e.endStatus, NULL, NULL, COUNT_BIG(*)
              FROM Enrollment e JOIN cal ON cal.calendarID = e.calendarID GROUP BY e.endStatus
    UNION ALL SELECT 'In use', 'UserAccount.homepage', homepage, NULL, NULL, COUNT_BIG(*) FROM UserAccount GROUP BY homepage HAVING COUNT_BIG(*) >= 10
)
SELECT source AS [Source], field AS [Field], code AS [Code], name AS [Name], extra AS [Extra], rowsUsing AS [Rows Using It]
FROM codes
ORDER BY source, field, code, name;
