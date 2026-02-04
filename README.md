# SP Helper

A PowerShell-based automation tool for managing and monitoring Safer Payments System (SPS) operations.

## Features

- User activity logging and monitoring
- Automated email notifications
- KeePass database integration for secure credential management
- End-of-Day (EOD) log processing
- Job submission tracking
- Index fill monitoring
- Purge log management
- WEFX log analysis
- Real-time statistics and alerts

## Prerequisites

- Windows operating system
- **PowerShell 7.x or higher** (the latest version) - [Download here](https://github.com/PowerShell/PowerShell/releases/latest)
  - **Note:** Windows PowerShell 5.1 is NOT compatible. You must install PowerShell 7+
- KeePass (for credential management)
- Access to the Safer Payments System

## Installation

### 1. Unblock PowerShell Scripts

Before running any scripts, you need to unblock them:

1. Right-click on each `.ps1` file in the project
2. Select **Properties**
3. Click **Unblock** at the bottom of the General tab
4. Click **OK**
5. Repeat for all PowerShell scripts in the project

### 2. Configure Environment Variables

1. Copy the example environment file:
   ```powershell
   Copy-Item .env.example .env
   ```

2. Edit `.env` with your actual configuration values:
   ```
   KEEPASS_PATH=C:\Users\YourUsername\YourDatabase.kdbx
   KEEPASS_EXE_PATH=C:\Program Files\KeePass Password Safe 2\KeePass.exe
   KEEPASS_POWERSHELL_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
   KEEPASS_ENTRY_NAME=YourEntryName
   EMAIL_MAP={"username1":"New","username2":"Classic"}
   USER_MAP={"username1":"John Doe","username2":"Jane Smith"}
   EMAIL_RECIPIENTS={"username1":"John Doe <user1@company.com>","username2":"Jane Smith <user2@company.com>"}
   USERLIST=[1,2,3]
   CHECK_USERLIST=[1,2,3]
   INSTANCES=[801,802,803,804]
   QUERY_UID=9869
   MANDATOR_ID=1057
   URL=https://your-actual-url.com
   ```

   **Configuration Details:**
   - `KEEPASS_PATH`: Full path to your KeePass database file
   - `KEEPASS_EXE_PATH`: Full path to KeePass.exe installation
   - `KEEPASS_POWERSHELL_EXE`: PowerShell executable for KeePass (use PS 5.1 for compatibility)
   - `KEEPASS_ENTRY_NAME`: Name of the entry containing credentials
   - `EMAIL_MAP`: JSON mapping of usernames to email template types ("New" or "Classic")
   - `USER_MAP`: JSON mapping of usernames to display names
   - `EMAIL_RECIPIENTS`: JSON mapping of usernames to full names and email addresses
   - `USERLIST`: Array of user IDs to monitor in daily stats
   - `CHECK_USERLIST`: Array of user IDs for audit reports
   - `INSTANCES`: Array of system instance IDs to query
   - `QUERY_UID`: Query identifier for User audit reports
   - `MANDATOR_ID`: Organization identifier for data selection
   - `URL`: Base URL for the Safer Payments System

### 3. Run the Script

1. Open PowerShell
2. Set execution policy for the current session:
   ```powershell
   Set-ExecutionPolicy Unrestricted -Scope Process
   ```

3. Navigate to the project directory:
   ```powershell
   cd C:\Users\YourUsername\Downloads\SP-helper
   ```

## Usage

### Running the Main Script

To start the SP Helper tool:

```powershell
.\splog.ps1
```

### Workflow

The script follows this workflow:

1. **Credential Selection** - Choose between:
   - KeePass (secure, recommended) - retrieves credentials from encrypted database
   - Manual input - type username and password directly

2. **Authentication** - Logs into Safer Payments System with retry logic

3. **Mode Selection** - Choose one of 4 operational modes:
   - **Mode 1: Last Night Stats** - Generates comprehensive overnight report (2 AM - 6 AM)
     - Collects Errors, Fatal errors, Emergencies, Warnings
     - Monitors Index fill levels
     - Tracks Job submissions
     - Analyzes EOD processes
     - Reviews Purge operations
     - Creates HTML email draft with all statistics

   - **Mode 2: Weekend Stats** - Runs Mode 1 for multiple consecutive days
     - Useful after weekends or holidays
     - Prompts for number of days to process
     - Generates separate report for each day
     - Sends individual emails with dated subjects

   - **Mode 3: Last 5 Minutes** - Real-time troubleshooting tool
     - Shows recent System and Audit logs
     - Opens in browser immediately
     - No email generation

   - **Mode 4: User Audit** - Monthly compliance report
     - Extracts all user queries for the previous month
     - Masks sensitive PAN data
     - Exports to CSV file (format: MMMMyyyy_UserQueries.csv)
     - Shows processing progress and performance metrics
     - No email generation

4. **Report Generation** - Executes selected modules and compiles results

5. **Email Creation** - Opens draft email with report (Modes 1 & 2 only)

6. **Repeat or Exit** - Choose to run another mode or exit

7. **Cleanup** - Logs out and removes environment variables

### Available Modules

The tool includes several specialized modules located in the `SPS` directory:

- **user_logs.ps1** - User Audit Report Generator
  - Extracts user query logs for specified time periods
  - Executes queries to retrieve index search data (PAN, Merchant ID, TIN)
  - Automatically masks sensitive PAN data (shows only first 6 and last 4 digits)
  - Exports results to CSV with detailed query information and timestamps
  - Tracks performance metrics (processing time per record)

- **EOD_log.ps1** - End-of-Day Log Processor
  - Monitors EOD processes between 2 AM and 6 AM
  - Tracks start/end times and duration of EOD operations
  - Generates HTML-formatted reports with instance-specific timing data
  - Identifies slow or problematic EOD executions

- **index_fill.ps1** - Index Fill Level Monitor
  - Retrieves current fill levels for all system indexes
  - Color-codes warnings: yellow (>90%), red (>95%)
  - Generates HTML table with visual indicators for quick assessment
  - Helps prevent index overflow issues

- **job_submission_log.ps1** - Job Submission Tracker
  - Monitors batch job submissions from midnight to 7 AM
  - Highlights jobs that "found nothing to do"
  - Counts total job submissions
  - Returns formatted HTML list with numbered entries

- **last_5_minutes.ps1** - Real-Time Log Viewer
  - Shows system and audit logs from the last 5 minutes
  - Displays both System Log and Audit Log tables
  - Opens automatically in browser with formatted HTML
  - Useful for immediate troubleshooting and monitoring

- **purge_log.ps1** - Purge Process Analyzer
  - Tracks data purge operations between 2 AM and 7 AM
  - Shows which indexes were purged and entry counts
  - Calculates time elapsed per index and total purge duration
  - Groups purge operations by instance for detailed analysis

- **safer_payments_stats.ps1** - Comprehensive Statistics Generator (Main Module)
  - Orchestrates execution of all other SPS modules
  - Generates complete daily report with table of contents
  - Includes: Errors, Fatal errors, Emergencies, Warnings, Index status, Job info, EOD info, Purge info
  - Creates navigable HTML report with hyperlinks
  - Shows progress bars during execution

- **WEFX_log.ps1** - System Log Analyzer
  - Filters system logs by severity (Error, Fatal, Emergency, Warning)
  - Groups repeated errors and shows occurrence counts
  - Displays time ranges for recurring issues
  - Generates HTML tables with detailed log entries (Instance, Timestamp, Log Level, ID, User, Message, Comment)

## Project Structure

```
SP-helper/
├── General/              # Core utility scripts
│   ├── access_keepass.ps1      # KeePass database integration (retrieves credentials)
│   ├── functions.ps1           # Shared utility functions (display, email, env loading)
│   ├── login_safer.ps1         # Authenticates with Safer Payments System
│   ├── logout_safer.ps1        # Logs out from Safer Payments System
│   ├── send_email_new.ps1      # Creates .eml draft file (modern format)
│   └── send_email_old.ps1      # Opens Outlook COM object (classic method)
├── SPS/                  # SPS-specific modules
│   ├── user_logs.ps1           # User audit report (CSV export)
│   ├── EOD_log.ps1             # End-of-Day process monitoring
│   ├── index_fill.ps1          # Index fill level alerts
│   ├── job_submission_log.ps1  # Batch job tracking
│   ├── last_5_minutes.ps1      # Real-time log viewer
│   ├── purge_log.ps1           # Data purge analyzer
│   ├── safer_payments_stats.ps1 # Main stats orchestrator
│   └── WEFX_log.ps1            # System error/warning log analyzer
├── .env                  # Your configuration (DO NOT commit!)
├── .env.example          # Example configuration template
├── splog.ps1            # Main entry point (interactive menu)
└── README.md            # This file
```

### Script Descriptions

#### Main Script
- **splog.ps1** - Interactive command-line interface
  - Prompts for credential source (KeePass or manual input)
  - Logs into Safer Payments System
  - Presents menu with 4 modes:
    1. Last night stats (runs safer_payments_stats.ps1)
    2. Weekend stats (runs stats for multiple days)
    3. Last 5 minutes activity (opens browser with recent logs)
    4. User Audit (generates monthly CSV report)
  - Automatically sends email reports after stats generation
  - Handles logout and cleanup

#### General Utilities
- **access_keepass.ps1** - KeePass Integration
  - Loads KeePass.exe assembly
  - Prompts for master password (3 attempts max)
  - Searches database for specified entry name
  - Returns credentials as JSON for secure password handling
  - Automatically closes database after retrieval

- **functions.ps1** - Utility Functions Library
  - `getUserName()` - Maps usernames to display names
  - `Logo()` - Displays banner with cyan/yellow formatting
  - `Login()` - Shows welcome message with user's full name
  - `Execution()` - Displays "Executing..." status
  - `Logout()` - Shows goodbye message
  - `sendMail()` - Routes email to appropriate sender (new/classic)
  - `Load-DotEnv()` - Loads environment variables from .env file
  - `Remove-DotEnvVars()` - Cleans up environment variables on exit

- **login_safer.ps1** - Authentication Handler
  - Accepts username, password, URL, and headers
  - Attempts login up to 3 times on failure
  - Allows password retry and username correction
  - Returns session info (websession, CSRF token) on success
  - Displays Logo and Login banner after successful authentication

- **logout_safer.ps1** - Session Termination
  - Sends logout request to Safer Payments System
  - Uses existing websession and headers
  - Displays Logout banner with goodbye message

- **send_email_new.ps1** - Email Draft Creator (.eml format)
  - Creates email draft as .eml file
  - Automatically populates TO (team members) and CC (current user)
  - Generates subject line with date
  - Converts body to HTML format
  - Opens draft in default email client

- **send_email_old.ps1** - Email Draft Creator (Outlook COM)
  - Uses Outlook COM object to create draft
  - Same recipient logic as send_email_new.ps1
  - Opens draft directly in Outlook window
  - Requires Outlook to be installed

## Security Notes

- **Never commit your `.env` file** to version control - it contains sensitive information
- Keep your KeePass database secure and use a strong master password
- The `.env` file is already in `.gitignore` to prevent accidental commits
- Regularly update your credentials and review access logs

## Troubleshooting

### Wrong PowerShell Version
**This is the most common issue!**
- Check your PowerShell version by running: `$PSVersionTable.PSVersion`
- If you see version 5.1.x, you're using the old Windows PowerShell
- You **must** install PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases/latest
- After installation, make sure to launch **PowerShell 7** (not "Windows PowerShell")
- PowerShell 7 appears as "PowerShell 7" in your Start menu, separate from "Windows PowerShell"

### Script Won't Run
- Ensure all scripts are unblocked (see Installation step 1)
- Verify execution policy is set correctly
- Run PowerShell as Administrator if needed

### KeePass Connection Issues
- Verify the `KEEPASS_PATH` in `.env` is correct
- Ensure the `KEEPASS_ENTRY_NAME` matches your database entry
- Check that KeePass is installed and the database is accessible

### Configuration Errors
- Double-check JSON syntax in `EMAIL_MAP` and `USER_MAP`
- Ensure all paths use proper Windows format with backslashes
- Verify the URL is correct and accessible

## Support

For issues or questions, please contact your system administrator or the development team.

## Git Setup

If you're setting up this project with git for the first time:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin <your-repository-url>
git push -u origin main
```

**Before your first commit**, verify that `.env` is not being tracked:
```bash
git status
```

The `.env` file should NOT appear in the list. Only `.env.example` should be tracked.

## License

This project is licensed under the **MIT License**.

See the [LICENSE](LICENSE) file for full details.

**Note**: This tool is designed for authorized use only. Ensure you have proper permissions before using it to access any systems.
