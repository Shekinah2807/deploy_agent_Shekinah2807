#!/usr/bin/env bash

set -euo pipefail

DEPLOY_DIR=""

# Trap SIGINT (Ctrl+C) and SIGTSTP (Ctrl+Z)
cleanup_on_interrupt() {
    echo ""
    echo "[!] Deployment interrupted by signal (Ctrl+C or Ctrl+Z)."
    
    if [ -n "$DEPLOY_DIR" ] && [ -d "$DEPLOY_DIR" ]; then
        ZIP_NAME="${DEPLOY_DIR}_archive.zip"
        echo "[*] Archiving incomplete directory '$DEPLOY_DIR' into '$ZIP_NAME'..."
        zip -r -q "$ZIP_NAME" "$DEPLOY_DIR" || true
        echo "[*] Removing incomplete directory..."
        rm -rf "$DEPLOY_DIR"
        echo "[+] Cleanup complete. Partial state saved in $ZIP_NAME."
    fi
    exit 1
}

trap 'cleanup_on_interrupt' SIGINT SIGTSTP

check_prerequisites() {
    echo "==> Running pre-flight checks..."
    for cmd in python3 zip; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "[Error] Pre-flight check failed: '$cmd' is not installed." >&2
            exit 1
        fi
    done
    echo "[+] Pre-flight checks passed."
}

feature_deploy() {
    check_prerequisites

    read -rp "Enter directory suffix/name for attendance_tracker_{input}: " INPUT_SUFFIX
    if [ -z "$INPUT_SUFFIX" ]; then
        echo "[Error] Directory name identifier cannot be empty."
        exit 1
    fi

    DEPLOY_DIR="attendance_tracker_${INPUT_SUFFIX}"

    if [ -d "$DEPLOY_DIR" ]; then
        echo "Directory '$DEPLOY_DIR' already exists."
        read -rp "Do you want to overwrite it? (y/N): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo "[!] Deployment aborted by user."
            exit 1
        fi
        rm -rf "$DEPLOY_DIR"
    fi

    echo "==> Creating directory structure..."
    mkdir -p "$DEPLOY_DIR/Helpers"
    mkdir -p "$DEPLOY_DIR/reports"

    if [ -f "templates/attendance_checker.py" ] && [ -f "templates/config.json" ]; then
        cp templates/attendance_checker.py "$DEPLOY_DIR/"
        cp templates/config.json "$DEPLOY_DIR/Helpers/"
    else
        echo "[Error] Source files missing in templates/ directory." >&2
        exit 1
    fi

    echo "Select Roster Creation Strategy:"
    echo "  1) Option A - Copy from template"
    echo "  2) Option B - Generate fresh roster"
    read -rp "Choice (1 or 2): " ROSTER_CHOICE

    if [ "$ROSTER_CHOICE" == "1" ]; then
        if [ ! -f "templates/assets.csv" ]; then
            echo "[Error] templates/assets.csv not found." >&2
            exit 1
        fi
        read -rp "How many students to copy? " STUDENT_COUNT
        
        head -n 1 templates/assets.csv > "$DEPLOY_DIR/Helpers/assets.csv"
        tail -n +2 templates/assets.csv | head -n "$STUDENT_COUNT" >> "$DEPLOY_DIR/Helpers/assets.csv"
        
        sed -i 's/"total_sessions":.*/"total_sessions": 5/' "$DEPLOY_DIR/Helpers/config.json"

    elif [ "$ROSTER_CHOICE" == "2" ]; then
        read -rp "How many students to generate? " STUDENT_COUNT
        echo "Email,Names,Attendance Count,Absence Count" > "$DEPLOY_DIR/Helpers/assets.csv"
        
        for (( i=1; i<=STUDENT_COUNT; i++ )); do
            echo "student${i}@example.com,Student ${i},0,0" >> "$DEPLOY_DIR/Helpers/assets.csv"
        done

        sed -i 's/"total_sessions":.*/"total_sessions": 1/' "$DEPLOY_DIR/Helpers/config.json"
    else
        echo "[Error] Invalid selection."
        exit 1
    fi

    chmod +x "$DEPLOY_DIR/attendance_checker.py"
    chmod 600 "$DEPLOY_DIR/Helpers/config.json"
    echo "[+] Permissions set: attendance_checker.py (+x), config.json (600)."

    read -rp "Do you want to update attendance alert thresholds in config.json? (y/N): " UPDATE_THRESH
    if [[ "$UPDATE_THRESH" =~ ^[Yy]$ ]]; then
        read -rp "Enter warning threshold percentage: " WARN_VAL
        read -rp "Enter failure threshold percentage: " FAIL_VAL

        sed -i "s/\"warning\":.*/\"warning\": ${WARN_VAL},/" "$DEPLOY_DIR/Helpers/config.json"
        sed -i "s/\"failure\":.*/\"failure\": ${FAIL_VAL}/" "$DEPLOY_DIR/Helpers/config.json"
        echo "[+] Thresholds updated."
    fi

    echo "==> Verifying deployment by running application..."
    feature_run "$DEPLOY_DIR"
    
    DEPLOY_DIR=""
}

feature_run() {
    local TARGET_DIR="${1:-}"

    if [ -z "$TARGET_DIR" ]; then
        read -rp "Enter deployed project directory name (e.g., attendance_tracker_v1): " TARGET_DIR
    fi

    if [ ! -d "$TARGET_DIR" ]; then
        echo "[Error] Directory '$TARGET_DIR' does not exist." >&2
        exit 1
    fi

    echo "==> Launching Attendance Checker..."
    (cd "$TARGET_DIR" && python3 attendance_checker.py)
}

feature_archive() {
    read -rp "Enter deployed project directory name to archive logs from: " TARGET_DIR

    if [ ! -d "$TARGET_DIR" ]; then
        echo "[Error] Directory '$TARGET_DIR' does not exist." >&2
        exit 1
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    ARCHIVE_BASE="$TARGET_DIR/archives"

    mkdir -p "$ARCHIVE_BASE/attendance"
    mkdir -p "$ARCHIVE_BASE/absent"

    ATTENDANCE_LOG="$TARGET_DIR/reports/attendance.log"
    ABSENT_LOG="$TARGET_DIR/reports/absent.log"

    LOG_FOUND=0

    if [ -f "$ATTENDANCE_LOG" ]; then
        DEST="$ARCHIVE_BASE/attendance/attendance_${TIMESTAMP}.log"
        cp "$ATTENDANCE_LOG" "$DEST"
        echo "[+] Archived: $ATTENDANCE_LOG -> $DEST"
        LOG_FOUND=1
    else
        echo "[-] Graceful notice: $ATTENDANCE_LOG does not exist. Skipping."
    fi

    if [ -f "$ABSENT_LOG" ]; then
        DEST="$ARCHIVE_BASE/absent/absent_${TIMESTAMP}.log"
        cp "$ABSENT_LOG" "$DEST"
        echo "[+] Archived: $ABSENT_LOG -> $DEST"
        LOG_FOUND=1
    else
        echo "[-] Graceful notice: $ABSENT_LOG does not exist. Skipping."
    fi

    if [ "$LOG_FOUND" -eq 0 ]; then
        echo "[*] No logs found in $TARGET_DIR/reports/ to archive."
    fi
}

show_menu() {
    echo "=========================================="
    echo "   Attendance Tracker Management Agent    "
    echo "=========================================="
    echo "1) Deploy Application"
    echo "2) Run Application"
    echo "3) Archive Log Files"
    echo "4) Exit"
    echo "=========================================="
    read -rp "Select an option [1-4]: " CHOICE

    case "$CHOICE" in
        1) feature_deploy ;;
        2) feature_run ;;
        3) feature_archive ;;
        4) echo "Exiting."; exit 0 ;;
        *) echo "[Error] Invalid selection."; exit 1 ;;
    esac
}

show_menu
