# Attendance Tracker Deployment & Management Agent

The `deploy_agent.sh` script is a CLI management tool built to handle the end-to-end lifecycle of the Student Attendance Tracker app. It automates initial directory setups, populates configuration files, sets appropriate Linux file permissions, updates alert thresholds on the fly, and manages log archiving.

It also includes built-in signal handling so that if a setup gets interrupted midway through, your workspace stays clean without leaving broken folders behind.

## Quick Start

Grab the repository from GitHub:

git clone [https://github.com/Shekinah2807/deploy_agent_Shekinah2807.git](https://github.com/Shekinah2807/deploy_agent_Shekinah2807.git)

cd deploy_agent_Shekinah2807

Make the agent executable and start the menu:

chmod +x deploy_agent.sh
./deploy_agent.sh

Interactive Menu Walkthrough

When you run ./deploy_agent.sh, you'll see a 4-option menu:

1.Deploy Application: Creates a new environment folder (e.g., attendance_tracker_v1). You can choose between copying students from an existing template (Option A) or starting fresh with a new roster (Option B), then set custom warning and failure thresholds.

2.Run Application: Launches the interactive Python checker inside your chosen deployment folder so you can mark student attendance.

3.Archive Log Files: Scans for existing session logs in reports/ and safely moves timestamped copies into the archives/ folder.

4.Exit: Quits the agent.

Tip: If you hit Ctrl + C during deployment, the agent automatically zips up whatever partial files were created, cleans up the directory, and exits safely.

File Overview

| File / Directory | What It Does |
| --- | --- |
| `deploy_agent.sh` | Main Bash script that handles setup, execution, signal trapping, and archiving. |
| `README.md` | Setup instructions and documentation. |
| `templates/attendance_checker.py` | Python script that runs the interactive marking session and generates reports. |
| `templates/assets.csv` | Template CSV containing default student names and initial attendance counts. |
| `templates/config.json` | Master configuration template for run modes and threshold percentages. |

System Requirements
The script automatically verifies system requirements before running deployment tasks. Make sure you have:

Linux or WSL (Ubuntu recommended)

Bash shell (v4.0+)

Python 3

zip CLI utility

If zip isn't installed yet, grab it using apt:

sudo apt update && sudo apt install -y zip

How to Push Changes

If you're making updates or setting up your own repository, initialize Git and push using:

git init
git add .
git commit -m "feat: complete deployment agent setup"
git branch -M main
git remote add origin [https://github.com/Shekinah2807/deploy_agent_Shekinah2807.git](https://github.com/Shekinah2807/deploy_agent_Shekinah2807.git)
git push -u origin main

## Demo Video

4-minute project walk-through and terminal demonstration:

[Watch Demo Video on Google Drive](https://drive.google.com/file/d/1scmNSd9iwD0e1eIbS7nI7Ah6FsvuBa_N/view?usp=sharing)

Known Limitations

Student roster CSV files must strictly follow the required column header structure (Email, Names, Attendance Count, Absence Count).

