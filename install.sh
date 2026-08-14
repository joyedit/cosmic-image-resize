#!/usr/bin/env bash
# Install cosmic-image-resize and register it as a COSMIC Files context action.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
TARGET="${BIN_DIR}/cosmic-image-resize"
CONFIG_DIR="${HOME}/.config/cosmic/com.system76.CosmicFiles/v1"
CONFIG="${CONFIG_DIR}/context_actions"
MENU_NAME="Resize / Compress Images…"

say() { printf '%s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }

# --- dependency check -------------------------------------------------------
missing=()
for tool in python3 convert identify zenity gio notify-send; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if ((${#missing[@]})); then
    warn "missing required tools: ${missing[*]}"
    say  "  install them with:"
    say  "    sudo apt install imagemagick zenity libglib2.0-bin libnotify-bin"
    say  ""
    say  "Continuing anyway; the menu entry will not work until they are present."
fi

# --- install the script -----------------------------------------------------
mkdir -p "$BIN_DIR"
install -m 755 "${REPO_DIR}/cosmic-image-resize" "$TARGET"
say "installed  ${TARGET}"

case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) warn "${BIN_DIR} is not on your PATH (the menu entry uses an absolute path, so this is harmless)" ;;
esac

# --- register the context action -------------------------------------------
mkdir -p "$CONFIG_DIR"

entry=$(cat <<RON
    (
        name: "${MENU_NAME}",
        confirm: false,
        selection: Files,
        steps: [
            "${TARGET} %F",
        ],
    ),
RON
)

if [[ ! -s "$CONFIG" ]]; then
    { echo "["; echo "$entry"; echo "]"; } > "$CONFIG"
    say "created    ${CONFIG}"
elif grep -q 'cosmic-image-resize' "$CONFIG"; then
    say "already registered in ${CONFIG} — leaving it alone"
else
    backup="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG" "$backup"
    say "backed up  ${backup}"
    # Splice the new entry in before the closing bracket of the RON list.
    if awk -v entry="$entry" '
        /^[[:space:]]*\][[:space:]]*$/ && !done { print entry; done = 1 }
        { print }
        END { exit done ? 0 : 1 }
    ' "$backup" > "$CONFIG"; then
        say "updated    ${CONFIG}"
    else
        cp "$backup" "$CONFIG"
        warn "could not merge automatically — your config is unchanged."
        say  "Add this entry inside the list in ${CONFIG} by hand:"
        say  ""
        say  "$entry"
        exit 1
    fi
fi

say ""
say "Done. Restart COSMIC Files (close every window and reopen) to pick up the change:"
say "    pkill -x cosmic-files && setsid cosmic-files >/dev/null 2>&1 &"
say ""
say "Then right-click an image — \"${MENU_NAME}\" is at the bottom of the menu."
