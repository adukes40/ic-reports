/* ======================================================================================
   #126  Fees owed
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Operational lists
   Type:      List · Priority 3 · Run On request
   Purpose:   Active students with an open fee balance, with the fee name, amount owed and
              the date the fee was assigned. Fees from earlier years that are still unpaid
              are included. Used by school offices and bookkeepers.
   Output:    One row per unpaid fee: grade, fee year, fee, fee amount, amount owed,
              assigned date, due date
   Tables:    SchoolYear, Enrollment, Calendar, School, Person, Identity, v_FeeDetail
   Params:    @endYear, @schoolID, @asOf  (change them in the PARAMETERS block below)
   Check:     Balances come from IC's own fee view (v_FeeDetail), so they should match the
              student's Fees tab; compare two or three students. Voided and exempted fees
              are left out. School is where the student is enrolled now, not where the fee
              was assigned.
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
SELECT p.studentNumber AS [Student Number], i.lastName AS [Last Name], i.firstName AS [First Name],
       a.schoolID AS [School ID], a.schoolName AS [School], a.endYear AS [School Year], a.grade AS [Grade],
       fd.endYear AS [Fee Year], fd.feeName AS [Fee],
       CAST(fd.feeDebit AS decimal(10,2)) AS [Fee Amount],
       CAST(fd.balance  AS decimal(10,2)) AS [Amount Owed],
       CONVERT(date, fd.createdDate) AS [Assigned Date], CONVERT(date, fd.dueDate) AS [Due Date]
FROM act a
JOIN v_FeeDetail fd ON fd.personID  = a.personID
JOIN Person p       ON p.personID   = a.personID
JOIN [Identity] i   ON i.identityID = p.currentIdentityID
WHERE a.rn = 1
  AND fd.voidID IS NULL
  AND ISNULL(fd.exempt, 0) = 0
  AND fd.balance > 0
ORDER BY a.schoolName, i.lastName, i.firstName, fd.createdDate;
