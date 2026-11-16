#!/usr/bin/env bash
# ==============================================================================
# Script: system_health.sh
# Description: Production system health monitoring and diagnostic reporter.
# Collects CPU, memory, filesystem disk usage, load average, and top 5 processes.
# Evaluates configurable thresholds, manages log rotation, and returns
# standardized monitoring exit codes (0 = healthy, 1 = warning, 2 = critical).
# ==============================================================================

set -euo pipefail

# Default threshold values (percentages)
DEFAULT_CPU_WARN=80
DEFAULT_CPU_CRIT=90
DEFAULT_MEM_WARN=80
DEFAULT_MEM_CRIT=90
DEFAULT_DISK_WARN=80
DEFAULT_DISK_CRIT=90

CPU_WARN_THRESHOLD="${DEFAULT_CPU_WARN}"
CPU_CRIT_THRESHOLD="${DEFAULT_CPU_CRIT}"
MEM_WARN_THRESHOLD="${DEFAULT_MEM_WARN}"
MEM_CRIT_THRESHOLD="${DEFAULT_MEM_CRIT}"
DISK_WARN_THRESHOLD="${DEFAULT_DISK_WARN}"
DISK_CRIT_THRESHOLD="${DEFAULT_DISK_CRIT}"

OUTPUT_JSON=false
LOG_FILE="health_log.txt"
MAX_LOG_SIZE_KB=1024  # 1 MB threshold for log rotation
MAX_BACKUP_FILES=3

show_help() {
  cat <<'EOF'
Usage: system_health.sh [OPTIONS]

Collects and logs system resource metrics, evaluates health thresholds, and returns
standard monitoring exit codes.

Options:
  --cpu-warn <percent>    CPU warning threshold percentage (default: 80)
  --cpu-crit <percent>    CPU critical threshold percentage (default: 90)
  --cpu <percent>         Alias to set both CPU warning and critical (crit = warn + 10, capped at 100)
  --mem-warn <percent>    Memory warning threshold percentage (default: 80)
  --mem-crit <percent>    Memory critical threshold percentage (default: 90)
  --mem <percent>         Alias to set both Memory warning and critical
  --disk-warn <percent>   Disk warning threshold percentage (default: 80)
  --disk-crit <percent>   Disk critical threshold percentage (default: 90)
  --disk <percent>        Alias to set both Disk warning and critical
  --log-file <path>       Target log file path (default: health_log.txt)
  --json                  Output entry in JSON format
  -h, --help              Display this help message and exit

Exit Codes:
  0                       Healthy (all metrics within thresholds)
  1                       Warning (at least one metric exceeded warning threshold)
  2                       Critical (at least one metric exceeded critical threshold)
EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu)
      CPU_WARN_THRESHOLD="${2:?Error: --cpu requires a value}"
      CPU_CRIT_THRESHOLD="$(( CPU_WARN_THRESHOLD + 10 > 100 ? 100 : CPU_WARN_THRESHOLD + 10 ))"
      shift 2
      ;;
    --cpu-warn)
      CPU_WARN_THRESHOLD="${2:?Error: --cpu-warn requires a value}"
      shift 2
      ;;
    --cpu-crit)
      CPU_CRIT_THRESHOLD="${2:?Error: --cpu-crit requires a value}"
      shift 2
      ;;
    --mem)
      MEM_WARN_THRESHOLD="${2:?Error: --mem requires a value}"
      MEM_CRIT_THRESHOLD="$(( MEM_WARN_THRESHOLD + 10 > 100 ? 100 : MEM_WARN_THRESHOLD + 10 ))"
      shift 2
      ;;
    --mem-warn)
      MEM_WARN_THRESHOLD="${2:?Error: --mem-warn requires a value}"
      shift 2
      ;;
    --mem-crit)
      MEM_CRIT_THRESHOLD="${2:?Error: --mem-crit requires a value}"
      shift 2
      ;;
    --disk)
      DISK_WARN_THRESHOLD="${2:?Error: --disk requires a value}"
      DISK_CRIT_THRESHOLD="$(( DISK_WARN_THRESHOLD + 10 > 100 ? 100 : DISK_WARN_THRESHOLD + 10 ))"
      shift 2
      ;;
    --disk-warn)
      DISK_WARN_THRESHOLD="${2:?Error: --disk-warn requires a value}"
      shift 2
      ;;
    --disk-crit)
      DISK_CRIT_THRESHOLD="${2:?Error: --disk-crit requires a value}"
      shift 2
      ;;
    --log-file)
      LOG_FILE="${2:?Error: --log-file requires a path}"
      shift 2
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'. Use --help for usage." >&2
      exit 2
      ;;
  esac
done

# Basic log rotation implementation
rotate_logs() {
  local target="$1"
  if [[ -f "${target}" ]]; then
    local size_kb
    size_kb="$(du -k "${target}" | cut -f1)"
    if [[ "${size_kb}" -ge "${MAX_LOG_SIZE_KB}" ]]; then
      local i
      for ((i = MAX_BACKUP_FILES - 1; i >= 1; i--)); do
        if [[ -f "${target}.${i}" ]]; then
          mv -f "${target}.${i}" "${target}.$((i + 1))"
        fi
      done
      mv -f "${target}" "${target}.1"
      touch "${target}"
    fi
  fi
}

# 1. Timestamp (UTC ISO-8601)
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# 2. CPU Usage Calculation (Calculates delta from /proc/stat)
get_cpu_usage() {
  if [[ -r /proc/stat ]]; then
    local _cpu user nice system idle iowait irq softirq steal
    read -r _cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    local total1=$(( user + nice + system + idle + iowait + irq + softirq + steal ))
    local idle1=$(( idle + iowait ))

    sleep 1

    read -r _cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    local total2=$(( user + nice + system + idle + iowait + irq + softirq + steal ))
    local idle2=$(( idle + iowait ))

    local total_diff=$(( total2 - total1 ))
    local idle_diff=$(( idle2 - idle1 ))

    if [[ "${total_diff}" -gt 0 ]]; then
      awk -v t="${total_diff}" -v i="${idle_diff}" 'BEGIN { printf "%.1f", ((t - i) / t) * 100 }'
      return
    fi
  fi
  # Fallback via top
  top -bn1 | awk '/Cpu\(s\)/ {print 100 - $8}' | tr -d '%'
}

CPU_USAGE="$(get_cpu_usage)"
CPU_USAGE_INT="${CPU_USAGE%.*}"
CPU_USAGE_INT="${CPU_USAGE_INT:-0}"

# 3. Memory Usage Calculation
MEM_TOTAL=0
MEM_AVAIL=0
if [[ -r /proc/meminfo ]]; then
  MEM_TOTAL="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
  MEM_AVAIL="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
fi

if [[ "${MEM_TOTAL}" -gt 0 ]]; then
  MEM_USED_KB=$(( MEM_TOTAL - MEM_AVAIL ))
  MEM_USAGE="$(awk -v t="${MEM_TOTAL}" -v u="${MEM_USED_KB}" 'BEGIN { printf "%.1f", (u / t) * 100 }')"
  MEM_TOTAL_MB=$(( MEM_TOTAL / 1024 ))
  MEM_USED_MB=$(( MEM_USED_KB / 1024 ))
else
  MEM_USAGE="0.0"
  MEM_TOTAL_MB=0
  MEM_USED_MB=0
fi
MEM_USAGE_INT="${MEM_USAGE%.*}"
MEM_USAGE_INT="${MEM_USAGE_INT:-0}"

# 4. Load Average (1m, 5m, 15m)
if [[ -r /proc/loadavg ]]; then
  read -r LOAD_1 LOAD_5 LOAD_15 _ < /proc/loadavg
else
  LOAD_1="0.00"
  LOAD_5="0.00"
  LOAD_15="0.00"
fi

# 5. Disk Usage Across All Real Mounted Filesystems
MAX_DISK_INT=0
DISK_DETAILS=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  DISK_DETAILS+=("${line}")
  usage_val="$(echo "${line}" | awk '{print $5}' | tr -d '%')"
  if [[ "${usage_val}" =~ ^[0-9]+$ ]] && [[ "${usage_val}" -gt "${MAX_DISK_INT}" ]]; then
    MAX_DISK_INT="${usage_val}"
  fi
done < <(df -h -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2)

# 6. Top 5 Processes by Memory Usage
TOP5_PROCS=()
while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  TOP5_PROCS+=("${line}")
done < <(ps -eo pid,user,%mem,%cpu,comm --sort=-%mem | head -n 6 | tail -n 5)

# 7. Evaluate Status & Alert Level
EXIT_CODE=0
WARNINGS=()
CRITICALS=()

# CPU Evaluation
if [[ "${CPU_USAGE_INT}" -ge "${CPU_CRIT_THRESHOLD}" ]]; then
  CRITICALS+=("CPU usage critical: ${CPU_USAGE}% (threshold: ${CPU_CRIT_THRESHOLD}%)")
  EXIT_CODE=2
elif [[ "${CPU_USAGE_INT}" -ge "${CPU_WARN_THRESHOLD}" ]]; then
  WARNINGS+=("CPU usage elevated: ${CPU_USAGE}% (threshold: ${CPU_WARN_THRESHOLD}%)")
  [[ "${EXIT_CODE}" -lt 1 ]] && EXIT_CODE=1
fi

# Memory Evaluation
if [[ "${MEM_USAGE_INT}" -ge "${MEM_CRIT_THRESHOLD}" ]]; then
  CRITICALS+=("Memory usage critical: ${MEM_USAGE}% (${MEM_USED_MB}MB/${MEM_TOTAL_MB}MB) (threshold: ${MEM_CRIT_THRESHOLD}%)")
  EXIT_CODE=2
elif [[ "${MEM_USAGE_INT}" -ge "${MEM_WARN_THRESHOLD}" ]]; then
  WARNINGS+=("Memory usage elevated: ${MEM_USAGE}% (${MEM_USED_MB}MB/${MEM_TOTAL_MB}MB) (threshold: ${MEM_WARN_THRESHOLD}%)")
  [[ "${EXIT_CODE}" -lt 1 ]] && EXIT_CODE=1
fi

# Disk Evaluation
if [[ "${MAX_DISK_INT}" -ge "${DISK_CRIT_THRESHOLD}" ]]; then
  CRITICALS+=("Disk usage critical: maximum mount utilization is ${MAX_DISK_INT}% (threshold: ${DISK_CRIT_THRESHOLD}%)")
  EXIT_CODE=2
elif [[ "${MAX_DISK_INT}" -ge "${DISK_WARN_THRESHOLD}" ]]; then
  WARNINGS+=("Disk usage elevated: maximum mount utilization is ${MAX_DISK_INT}% (threshold: ${DISK_WARN_THRESHOLD}%)")
  [[ "${EXIT_CODE}" -lt 1 ]] && EXIT_CODE=1
fi

# Rotate log file if necessary before appending
rotate_logs "${LOG_FILE}"

# Format entry (Text or JSON)
STATUS_STR="HEALTHY"
if [[ "${EXIT_CODE}" -eq 2 ]]; then
  STATUS_STR="CRITICAL"
elif [[ "${EXIT_CODE}" -eq 1 ]]; then
  STATUS_STR="WARNING"
fi

if [[ "${OUTPUT_JSON}" == "true" ]]; then
  # Format JSON output
  JSON_OUTPUT="{\"timestamp\":\"${TIMESTAMP}\",\"status\":\"${STATUS_STR}\",\"exit_code\":${EXIT_CODE},\"cpu_usage_percent\":${CPU_USAGE},\"memory\":{\"used_mb\":${MEM_USED_MB},\"total_mb\":${MEM_TOTAL_MB},\"usage_percent\":${MEM_USAGE}},\"load_average\":{\"1m\":\"${LOAD_1}\",\"5m\":\"${LOAD_5}\",\"15m\":\"${LOAD_15}\"},\"max_disk_usage_percent\":${MAX_DISK_INT},\"warnings\":["
  
  first=true
  for w in "${WARNINGS[@]}"; do
    if [[ "${first}" == "true" ]]; then
      JSON_OUTPUT+="\"${w}\""
      first=false
    else
      JSON_OUTPUT+=",\"${w}\""
    fi
  done
  JSON_OUTPUT+="],\"criticals\":["
  first=true
  for c in "${CRITICALS[@]}"; do
    if [[ "${first}" == "true" ]]; then
      JSON_OUTPUT+="\"${c}\""
      first=false
    else
      JSON_OUTPUT+=",\"${c}\""
    fi
  done
  JSON_OUTPUT+="]}"

  echo "${JSON_OUTPUT}" >> "${LOG_FILE}"
  echo "${JSON_OUTPUT}"
else
  # Format Plain Text output
  {
    echo "================================================================================"
    echo "[${TIMESTAMP}] SYSTEM HEALTH REPORT - Status: ${STATUS_STR} (Exit Code: ${EXIT_CODE})"
    echo "================================================================================"
    echo "CPU Usage:      ${CPU_USAGE}% (Warn: ${CPU_WARN_THRESHOLD}%, Crit: ${CPU_CRIT_THRESHOLD}%)"
    echo "Memory Usage:   ${MEM_USAGE}% [${MEM_USED_MB}MB / ${MEM_TOTAL_MB}MB] (Warn: ${MEM_WARN_THRESHOLD}%, Crit: ${MEM_CRIT_THRESHOLD}%)"
    echo "Load Average:   1m: ${LOAD_1} | 5m: ${LOAD_5} | 15m: ${LOAD_15}"
    echo ""
    echo "--- Filesystem Disk Usage ---"
    printf "%-20s %-8s %-8s %-8s %-6s %-20s\n" "Filesystem" "Size" "Used" "Avail" "Use%" "Mounted on"
    for d in "${DISK_DETAILS[@]}"; do
      echo "${d}"
    done
    echo ""
    echo "--- Top 5 Processes by Memory Usage ---"
    printf "%-8s %-12s %-6s %-6s %-20s\n" "PID" "USER" "%MEM" "%CPU" "COMMAND"
    for p in "${TOP5_PROCS[@]}"; do
      echo "${p}"
    done

    if [[ ${#WARNINGS[@]} -gt 0 || ${#CRITICALS[@]} -gt 0 ]]; then
      echo ""
      echo "--- Alerts & Notifications ---"
      for c in "${CRITICALS[@]}"; do
        echo "[CRITICAL] ${c}"
      done
      for w in "${WARNINGS[@]}"; do
        echo "[WARNING] ${w}"
      done
    fi
    echo ""
  } | tee -a "${LOG_FILE}"
fi

exit "${EXIT_CODE}"
