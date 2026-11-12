/* ======================================================================================
   #104  Restraint / seclusion incidents
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Behavior & discipline
   Type:      List · Priority 2 · Run Monthly
   Purpose:   This year's behavior responses (IC's record of a restraint or seclusion), with
              the student, grade, date, length and the staff involved, for Delaware's
              incident-level restraint reporting.
   Output:    One row per response: student, school, grade, incident ID, event type,
              response date, response type, type category, start, end, minutes, student
              injured, guardian contacted, staff involved
   Tables:    SchoolYear, BehaviorResponse, BehaviorResponseType, BehaviorResponseRole,
              BehaviorRole, BehaviorEvent, BehaviorType, Calendar, School, Enrollment,
              Person, Identity
   Params:    @endYear, @schoolID, @typePattern ('%')  (change them in the PARAMETERS block
              below)
   Check:     Every behavior response is listed. If your district also records other
              things as responses, set @typePattern to match the response type names you
              use for restraint and seclusion (for example '%restrain%'); the Response
              Type and Type Category columns show what is there. The code in brackets
              after each staff name is their role on the response as stored. Contains
              student names: share only with staff who handle restraint reporting.
              Delaware requires a written report to the Department of Education within 72
              hours of a restraint (14 DE Admin. Code 610, 6.1.2).
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear     int = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @schoolID    int = NULL;            -- NULL = all schools
DECLARE @typePattern varchar(50) = '%';     -- response type names to include; '%' = all
-- ===========================================================================

SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       c.schoolID AS [School ID], s.name AS [School], c.endYear AS [School Year],
       g.grade AS [Grade],
       be.incidentID AS [Incident ID], bt.name AS [Event Type],
       CONVERT(date, rsp.date) AS [Response Date],
       rty.name AS [Response Type], rty.responseType AS [Type Category],
       CONVERT(varchar(5), rsp.startTime, 108) AS [Start Time],
       CONVERT(varchar(5), rsp.endTime, 108)   AS [End Time],
       rsp.duration AS [Minutes],
       CASE WHEN rsp.studentInjured = 1    THEN 'Y' ELSE 'N' END AS [Student Injured],
       CASE WHEN rsp.guardianContacted = 1 THEN 'Y' ELSE 'N' END AS [Guardian Contacted],
       st.staff AS [Staff Involved]
FROM BehaviorResponse rsp
JOIN BehaviorResponseType rty ON rty.responseTypeID = rsp.responseTypeID
JOIN BehaviorRole br ON br.roleID = rsp.roleID
JOIN Calendar c ON c.calendarID = rsp.calendarID
JOIN School   s ON s.schoolID   = c.schoolID
JOIN Person   p ON p.personID   = br.personID
JOIN [Identity] i ON i.identityID = p.currentIdentityID
LEFT JOIN BehaviorEvent be ON be.eventID = br.eventID
LEFT JOIN BehaviorType  bt ON bt.typeID  = be.typeID
OUTER APPLY (SELECT TOP 1 e.grade FROM Enrollment e
             WHERE e.personID = br.personID AND e.calendarID = rsp.calendarID
             ORDER BY e.startDate DESC) g
OUTER APPLY (SELECT STRING_AGG(CAST(si.lastName + ', ' + si.firstName
                                    + ISNULL(' (' + rr.behRole + ')', '') AS varchar(max)), '; ')
                        WITHIN GROUP (ORDER BY si.lastName, si.firstName) AS staff
             FROM BehaviorResponseRole rr
             JOIN Person sp     ON sp.personID   = rr.personID
             JOIN [Identity] si ON si.identityID = sp.currentIdentityID
             WHERE rr.responseID = rsp.responseID) st
WHERE c.endYear = @endYear
  AND c.exclude = 0 AND c.summerSchool = 0 AND s.exclude = 0
  AND (@schoolID IS NULL OR c.schoolID = @schoolID)
  AND rty.name LIKE @typePattern
ORDER BY s.name, rsp.date, i.lastName, i.firstName;
