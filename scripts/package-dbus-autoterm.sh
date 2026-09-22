#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/dbus-autoterm"
EXT_DIR="$APP_DIR/ext"
DIST_DIR="$ROOT_DIR/dist"
GUI_VARIANT="${GUI_VARIANT:-default}"
ARCHIVE_NAME="dbus-autoterm.tar.gz"
VELIB_PYTHON_REF="${VELIB_PYTHON_REF:-master}"
PYSERIAL_REF="${PYSERIAL_REF:-v3.5}"
TMP_DIR=$(mktemp -d)
export COPYFILE_DISABLE=1

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

case "$GUI_VARIANT" in
    default)
        ;;
    native-gui)
        ARCHIVE_NAME="dbus-autoterm-native-gui.tar.gz"
        ;;
    *)
        echo "Unsupported GUI_VARIANT: $GUI_VARIANT" >&2
        exit 1
        ;;
esac

ARCHIVE="$DIST_DIR/$ARCHIVE_NAME"
VARIANT_EXCLUDE=

if ! command -v curl >/dev/null 2>&1; then
    echo "Missing curl runtime" >&2
    exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
    echo "Missing tar runtime" >&2
    exit 1
fi

TAR_BIN="tar"
if command -v gtar >/dev/null 2>&1; then
    TAR_BIN="gtar"
fi

download_archive() {
    url=$1
    destination=$2
    curl -fsSL "$url" -o "$destination"
}

extract_single_root() {
    archive=$1
    destination=$2
    mkdir -p "$destination"
    tar -xzf "$archive" -C "$destination"
}

install_dependency() {
    name=$1
    url=$2
    prefix=$3
    archive="$TMP_DIR/$name.tar.gz"

    download_archive "$url" "$archive"
    extract_single_root "$archive" "$TMP_DIR"

    source_root=$(find "$TMP_DIR" -maxdepth 1 -type d -name "$prefix" | head -n 1)
    if [ -z "$source_root" ] || [ ! -d "$source_root" ]; then
        echo "Failed to extract dependency '$name' from $url" >&2
        exit 1
    fi

    mkdir -p "$EXT_DIR/$name"
    cp -R "$source_root"/. "$EXT_DIR/$name/"
}

mkdir -p "$DIST_DIR"
rm -rf "$EXT_DIR"
mkdir -p "$EXT_DIR"

install_dependency \
    "velib_python" \
    "${VELIB_PYTHON_URL:-https://codeload.github.com/victronenergy/velib_python/tar.gz/refs/heads/$VELIB_PYTHON_REF}" \
    "velib_python-*"
install_dependency \
    "pyserial" \
    "${PYSERIAL_URL:-https://codeload.github.com/pyserial/pyserial/tar.gz/refs/tags/$PYSERIAL_REF}" \
    "pyserial-*"

rm -f "$ARCHIVE"

is_darwin=0
if uname -s 2>/dev/null | grep -qi "darwin"; then
    is_darwin=1
fi

tar_args=""
if "$TAR_BIN" --help 2>/dev/null | grep -q -- '--no-mac-metadata'; then
    tar_args="$tar_args --no-mac-metadata"
fi
if "$TAR_BIN" --help 2>/dev/null | grep -q -- '--no-xattrs'; then
    tar_args="$tar_args --no-xattrs"
fi
if "$TAR_BIN" --help 2>/dev/null | grep -q -- '--no-acls'; then
    tar_args="$tar_args --no-acls"
fi
if "$TAR_BIN" --help 2>/dev/null | grep -q -- '--no-fflags'; then
    tar_args="$tar_args --no-fflags"
fi
if [ "$GUI_VARIANT" = "default" ]; then
    VARIANT_EXCLUDE="--exclude=dbus-autoterm/native-gui"
else
    # For native-gui variant, explicitly include native-gui
    VARIANT_EXCLUDE=""
fi
# even with COPYFILE_DISABLE and --no-xattrs, so BusyBox tar on Venus
# prints 12x "Ignoring unknown ...". xattr -c cannot clear it on SIP
# volumes. Use python tarfile on Darwin which never stores xattrs.
if [ "$is_darwin" -eq 1 ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$ROOT_DIR" "$ARCHIVE" "$GUI_VARIANT" <<'PY'
import pathlib, tarfile, fnmatch, sys
root = pathlib.Path(sys.argv[1])
archive = pathlib.Path(sys.argv[2])
variant = sys.argv[3]
excludes = [
    "dbus-autoterm/__pycache__",
    "dbus-autoterm/tests",
    "dbus-autoterm/*.pyc",
    "dbus-autoterm/.DS_Store",
    "dbus-autoterm/._*",
]
if variant == "default":
    excludes.append("dbus-autoterm/native-gui")

def excluded(rel_posix: str) -> bool:
    for pat in excludes:
        if fnmatch.fnmatch(rel_posix, pat) or rel_posix.startswith(pat.rstrip("*")) and pat.endswith("*") and False:
            return True
        # fnmatch handles *; also handle directory prefix
        if fnmatch.fnmatch(rel_posix, pat):
            return True
        if pat.endswith("/*") and rel_posix.startswith(pat[:-1]):
            return True
        if pat == rel_posix or rel_posix.startswith(pat + "/"):
            return True
    return False

with tarfile.open(archive, "w:gz", format=tarfile.USTAR_FORMAT) as tf:
    base = root / "dbus-autoterm"
    for p in root.rglob("*"):
        # only include dbus-autoterm tree
        try:
            rel = p.relative_to(root)
        except ValueError:
            continue
        rel_posix = rel.as_posix()
        if not rel_posix.startswith("dbus-autoterm"):
            continue
        if rel_posix == "dbus-autoterm":
            tf.add(p, arcname=rel_posix, recursive=False)
            continue
        if excluded(rel_posix):
            continue
        # skip pycache internals already excluded
        tf.add(p, arcname=rel_posix, recursive=False)
PY
else
    "$TAR_BIN" -C "$ROOT_DIR" $tar_args \
        --exclude='dbus-autoterm/__pycache__' \
        --exclude='dbus-autoterm/tests' \
        --exclude='dbus-autoterm/*.pyc' \
        --exclude='dbus-autoterm/.DS_Store' \
        --exclude='dbus-autoterm/._*' \
        $VARIANT_EXCLUDE \
        -czf "$ARCHIVE" \
        dbus-autoterm
fi
echo "Created $ARCHIVE"
