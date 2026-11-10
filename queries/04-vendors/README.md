# Vendors

Files we send to outside vendors, grouped by vendor. Each vendor gets its own folder, for example `queries/04-vendors/iready/students.sql`.

Each vendor query uses the same info header as the rest of the library, plus these fields:

| Field | What to put |
|---|---|
| `Vendor` | The vendor's name |
| `File` | The exact filename the vendor expects, such as `students.csv` |
| `Format` | Delimiter, header row, column order |
| `Schedule` | Nightly, start of year, on request |
| `Delivery` | How it gets there: SFTP, vendor portal upload, email |
| `Owner` | Who at the district sends it or fixes it |

Keep SFTP hostnames, usernames, keys and contract details out of these files. This repo is meant to be shareable.

[← Back to the library](../../README.md)
