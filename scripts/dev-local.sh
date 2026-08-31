#!/bin/zsh

set -euo pipefail

script_path="${0:A}"
project_root="${script_path:h:h}"
app_path="$project_root/build/BongoCat.app"
binary_path="$app_path/Contents/MacOS/BongoCat"
log_path="$HOME/Library/Application Support/BongoCat/Logs/BongoCat.log"

usage() {
  cat <<'EOF'
Usage: scripts/dev-local.sh <command>

Commands:
  install   Print first-run dependency steps
  up        Build and start BongoCat
  down      Stop BongoCat from this checkout
  status    Show whether this checkout is running
  logs      Print recent application logs
  restart   Rebuild and restart BongoCat
  test      Prepare Cubism and run Swift tests
  check     Run repository hygiene checks
  attach    Follow application logs
EOF
}

app_pids() {
  /usr/bin/pgrep -f "^$binary_path$" || true
}

stop_app() {
  local pid
  for pid in ${(f)"$(app_pids)"}; do
    [[ -n "$pid" ]] && /bin/kill "$pid"
  done

  local attempt
  for attempt in {1..20}; do
    [[ -z "$(app_pids)" ]] && return 0
    /bin/sleep 0.1
  done

  echo "BongoCat did not stop within two seconds." >&2
  return 1
}

start_app() {
  "$project_root/scripts/build-app.sh"
  stop_app
  /usr/bin/open "$app_path" || true
  /bin/sleep 2

  if [[ -z "$(app_pids)" ]]; then
    echo "BongoCat did not start." >&2
    return 1
  fi

  "$script_path" status
}

command="${1:-}"
case "$command" in
  install)
    cat <<'EOF'
1. Install Xcode 26 and select its Command Line Tools.
2. Install CMake: brew install cmake
3. Download Cubism SDK for Native 5 R5 from Live2D.
4. Export CUBISM_SDK_ROOT to the extracted SDK folder.
EOF
    ;;
  up | restart)
    start_app
    ;;
  down)
    stop_app
    echo "BongoCat stopped."
    ;;
  status)
    pids="$(app_pids)"
    if [[ -z "$pids" ]]; then
      echo "BongoCat is not running from $app_path"
      exit 1
    fi
    /bin/ps -p ${(f)pids} -o pid=,etime=,%cpu=,rss=,command=
    ;;
  logs)
    if [[ ! -f "$log_path" ]]; then
      echo "No BongoCat log exists at $log_path"
      exit 1
    fi
    /usr/bin/tail -n 80 "$log_path"
    ;;
  attach)
    /usr/bin/touch "$log_path"
    /usr/bin/tail -f "$log_path"
    ;;
  test)
    cd "$project_root"
    "$project_root/scripts/prepare-cubism.sh"
    swift test
    ;;
  check)
    "$project_root/scripts/check-repository.sh"
    ;;
  *)
    usage
    [[ -n "$command" ]] && exit 1
    ;;
esac
