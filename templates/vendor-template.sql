/* ======================================================================================
   #00  Vendor name: what this file is (for example "i-Ready: students")
   --------------------------------------------------------------------------------------
   Status:    Not run yet
   Category:  Vendors
   Type:      Vendor pull
   Purpose:   What the vendor uses this file for.
   Output:    One row per ...
   Tables:    Enrollment, Calendar, School, Person, Identity
   Params:    @endYear, @asOf  (change them in the PARAMETERS block below)
   Vendor:    Vendor name
   File:      students.csv
   Format:    CSV, comma-delimited, header row, columns in the order selected below
   Schedule:  Nightly
   Delivery:  SFTP to the vendor (no hostnames or credentials in this file)
   Owner:     Who at the district sends or fixes it
   --------------------------------------------------------------------------------------
   HOW TO USE: copy this whole file and paste it into IC's data extract tool.
   This header is a SQL comment, so it is ignored when the query runs.
   ====================================================================================== */

-- ===== PARAMETERS ==========================================================
DECLARE @endYear  int  = (SELECT TOP 1 endYear FROM SchoolYear WHERE active = 1);
DECLARE @asOf     date = CONVERT(date, GETDATE());
-- ===========================================================================

SELECT ...;
