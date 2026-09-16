#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -f "$ROOT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    . "$ROOT_DIR/.env"
fi

GUI_VARIANT="${GUI_VARIANT:-default}"
ARCHIVE="$ROOT_DIR/dist/dbus-autoterm.tar.gz"
CERBO_HOST="${CERBO_HOST:-${VENUS_TARGET:-root@einstein}}"
CERBO_APP_DIR="${CERBO_APP_DIR:-/data/apps/dbus-autoterm}"
CERBO_ARCHIVE_PATH="${CERBO_ARCHIVE_PATH:-/data/dbus-autoterm.tar.gz}"
REMOTE_DEPLOY_SCRIPT="${REMOTE_DEPLOY_SCRIPT:-/data/dbus-autoterm-deploy.sh}"
REMOTE_DEPLOY_LOG="${REMOTE_DEPLOY_LOG:-/data/dbus-autoterm-deploy.log}"
REMOTE_DEPLOY_STATUS="${REMOTE_DEPLOY_STATUS:-/data/dbus-autoterm-deploy.status}"
DEPLOY_TIMEOUT_SECONDS="${DEPLOY_TIMEOUT_SECONDS:-240}"
CERBO_PASSWORD="${CERBO_PASSWORD:-${SSH_PASSWORD:-}}"
TMP_DIR=$(mktemp -d)
CONTROL_PATH="$TMP_DIR/ssh-control"
SSH_OPTS="-o ControlMaster=auto -o ControlPersist=60 -o ControlPath=$CONTROL_PATH"
SSH_BIN="ssh"
SCP_BIN="scp"

if [ -n "$CERBO_PASSWORD" ]; then
    if ! command -v sshpass >/dev/null 2>&1; then
        echo "CERBO_PASSWORD is set, but sshpass is not installed." >&2
        echo "Install sshpass or unset CERBO_PASSWORD to use the normal interactive password prompt." >&2
        exit 1
    fi
    export SSHPASS="$CERBO_PASSWORD"
    SSH_BIN="sshpass -e ssh"
    SCP_BIN="sshpass -e scp"
fi

cleanup() {
    $SSH_BIN $SSH_OPTS -O exit "$CERBO_HOST" >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

case "$GUI_VARIANT" in
    default)
        ;;
    native-gui)
        ARCHIVE="$ROOT_DIR/dist/dbus-autoterm-native-gui.tar.gz"
        ;;
    *)
        echo "Unsupported GUI_VARIANT: $GUI_VARIANT" >&2
        exit 1
        ;;
esac

if [ ! -f "$ARCHIVE" ]; then
    echo "Missing package archive: $ARCHIVE" >&2
    if [ "$GUI_VARIANT" = "native-gui" ]; then
        echo "Run make package:native-gui first." >&2
    else
        echo "Run make package first." >&2
    fi
    exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
    echo "Missing ssh runtime" >&2
    exit 1
fi

if ! command -v scp >/dev/null 2>&1; then
    echo "Missing scp runtime" >&2
    exit 1
fi

echo "Uploading $ARCHIVE to $CERBO_HOST:$CERBO_ARCHIVE_PATH"
$SCP_BIN $SSH_OPTS "$ARCHIVE" "$CERBO_HOST:$CERBO_ARCHIVE_PATH"

# Install the deploy worker on the device. It is launched detached so that a dropped SSH
# connection during the GUI restart cannot interrupt the install. We prefer `setsid` but
# fall back to `nohup` for minimal BusyBox environments (e.g. some Venus OS builds). Progress
# is written to a log and a terminal status file that we poll from here.
echo "Uploading deploy worker to $CERBO_HOST:$REMOTE_DEPLOY_SCRIPT"
$SSH_BIN $SSH_OPTS "$CERBO_HOST" "cat > '$REMOTE_DEPLOY_SCRIPT'" <<'REMOTE_SCRIPT'
#!/bin/sh
set -eu

archive_path=$1
app_dir=$2
gui_variant=$3
log_file=$4
status_file=$5

exec >"$log_file" 2>&1

cleanup() {
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "DEPLOY_DONE"
        echo DONE > "$status_file"
    else
        echo "DEPLOY_FAILED rc=$rc"
        echo "FAILED rc=$rc" > "$status_file"
    fi
}
trap cleanup EXIT

echo "=== dbus-autoterm deploy started $(date) ==="

parent_dir=$(dirname "$app_dir")
deploy_root=/tmp/dbus-autoterm-deploy
extracted_dir="$deploy_root/dbus-autoterm"
backup_config="$deploy_root/config.ini"

echo "Stopping existing service if present"
if command -v svc >/dev/null 2>&1 && [ -d /service/dbus-autoterm ]; then
    svc -d /service/dbus-autoterm || true
    sleep 1
fi
pkill -f '/data/apps/dbus-autoterm/app.py' || true

echo "Preparing deploy directory"
rm -rf "$deploy_root"
mkdir -p "$deploy_root" "$parent_dir"

if [ -f "$app_dir/config.ini" ]; then
    cp "$app_dir/config.ini" "$backup_config"
fi

echo "Unpacking archive"
tar -xzf "$archive_path" -C "$deploy_root"

echo "Swapping app directory atomically"
old_dir="$parent_dir/dbus-autoterm.old"
rm -rf "$old_dir" || true
if [ -d "$app_dir" ]; then
    mv "$app_dir" "$old_dir"
fi
mv "$extracted_dir" "$app_dir"

if [ -f "$backup_config" ]; then
    mv "$backup_config" "$app_dir/config.ini"
fi

# Best-effort removal of the old tree; supervise dirs can be busy while
# runsv writes logs. Leftovers are cleaned up by the next deploy.
rm -rf "$old_dir" 2>/dev/null || echo "NOTE: leftover $old_dir will be cleaned next deploy"

echo "Running install.sh"
cd "$app_dir"
GUI_VARIANT="$gui_variant" bash install.sh

if command -v svc >/dev/null 2>&1 && [ -e /service/dbus-autoterm ]; then
    svc -u /service/dbus-autoterm || true
fi

echo "Cleaning up"
rm -f "$archive_path"
rm -rf "$deploy_root"
REMOTE_SCRIPT

echo "Launching detached deployment on $CERBO_HOST"
$SSH_BIN $SSH_OPTS "$CERBO_HOST" \
    "rm -f '$REMOTE_DEPLOY_STATUS'; if command -v setsid >/dev/null 2>&1; then setsid /bin/sh '$REMOTE_DEPLOY_SCRIPT' '$CERBO_ARCHIVE_PATH' '$CERBO_APP_DIR' '$GUI_VARIANT' '$REMOTE_DEPLOY_LOG' '$REMOTE_DEPLOY_STATUS' </dev/null >/dev/null 2>&1 & else nohup /bin/sh '$REMOTE_DEPLOY_SCRIPT' '$CERBO_ARCHIVE_PATH' '$CERBO_APP_DIR' '$GUI_VARIANT' '$REMOTE_DEPLOY_LOG' '$REMOTE_DEPLOY_STATUS' </dev/null >/dev/null 2>&1 & fi; echo LAUNCHED"

echo "Waiting for deployment to finish (detached; survives SSH drops)"
elapsed=0
while [ "$elapsed" -lt "$DEPLOY_TIMEOUT_SECONDS" ]; do
    status=$($SSH_BIN $SSH_OPTS "$CERBO_HOST" "cat '$REMOTE_DEPLOY_STATUS' 2>/dev/null" 2>/dev/null || true)
    case "$status" in
        DONE)
            echo "Deployment finished."
            $SSH_BIN $SSH_OPTS "$CERBO_HOST" "tail -n 20 '$REMOTE_DEPLOY_LOG' 2>/dev/null" 2>/dev/null || true
            exit 0
            ;;
        FAILED*)
            echo "Deployment FAILED: $status" >&2
            $SSH_BIN $SSH_OPTS "$CERBO_HOST" "tail -n 40 '$REMOTE_DEPLOY_LOG' 2>/dev/null" >&2 2>/dev/null || true
            exit 1
            ;;
    esac
    sleep 3
    elapsed=$((elapsed + 3))
done

echo "Timed out after ${DEPLOY_TIMEOUT_SECONDS}s waiting for deployment." >&2
echo "The job may still be running on-device. Check: $CERBO_HOST:$REMOTE_DEPLOY_LOG" >&2
exit 1
