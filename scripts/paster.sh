#!/bin/bash

# Universal paste: images get saved + path inserted, text gets pasted directly.
# Cross-platform: macOS (pngpaste/pbpaste), Wayland (wl-paste), X11 (xclip).

SCREENSHOT_DIR="${1:-$HOME/.cache/tmux-paste-image}"
mkdir -p "$SCREENSHOT_DIR"

# --- Detect clipboard backend ---------------------------------------------
# CLIP_BACKEND is one of: macos | wayland | x11 | none
if [ "$(uname)" = "Darwin" ]; then
    CLIP_BACKEND="macos"
elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-paste >/dev/null 2>&1; then
    CLIP_BACKEND="wayland"
elif command -v xclip >/dev/null 2>&1; then
    CLIP_BACKEND="x11"
else
    CLIP_BACKEND="none"
fi

if [ "$CLIP_BACKEND" = "none" ]; then
    tmux display-message "[paste] No clipboard tool found (need pngpaste/wl-paste/xclip)"
    exit 1
fi

# --- Does the clipboard hold an image? ------------------------------------
HAS_IMAGE=0
case "$CLIP_BACKEND" in
    macos)
        # `clipboard info` lists the flavors; PNG/TIFF => an image is present.
        if osascript -e 'clipboard info' 2>/dev/null | grep -qiE 'PNG|TIFF|image'; then
            HAS_IMAGE=1
        fi
        ;;
    wayland)
        if wl-paste --list-types 2>/dev/null | grep -qi 'image/'; then
            HAS_IMAGE=1
        fi
        ;;
    x11)
        if xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -qi 'image/'; then
            HAS_IMAGE=1
        fi
        ;;
esac

# --- Image branch: save to a file, then hand the path to whatever's focused -
if [ "$HAS_IMAGE" -eq 1 ]; then
    FILENAME="image_$(date +%Y-%m-%d_%H-%M-%S).png"
    FILE_PATH="$SCREENSHOT_DIR/$FILENAME"

    case "$CLIP_BACKEND" in
        macos)   pngpaste "$FILE_PATH" >/dev/null 2>&1 ;;
        wayland) wl-paste --type image/png > "$FILE_PATH" 2>/dev/null ;;
        x11)     xclip -selection clipboard -t image/png -o > "$FILE_PATH" 2>/dev/null ;;
    esac

    if [ -s "$FILE_PATH" ]; then
        PANE_CONTENT=$(tmux capture-pane -p | tail -5)
        if echo "$PANE_CONTENT" | grep -qE "(^›|^>|claude.*›|Human:|Assistant:)"; then
            tmux send-keys "$FILE_PATH"
            tmux display-message "[paste] Image → Claude: $(basename "$FILE_PATH")"
        else
            tmux send-keys "$FILE_PATH"
            tmux display-message "[paste] Image path: $FILE_PATH"
        fi
    else
        rm -f "$FILE_PATH"
        tmux display-message "[paste] No image data in clipboard"
    fi
    exit 0
fi

# --- Text branch: paste clipboard text straight through --------------------
case "$CLIP_BACKEND" in
    macos)   TEXT=$(pbpaste 2>/dev/null) ;;
    wayland) TEXT=$(wl-paste 2>/dev/null) ;;
    x11)     TEXT=$(xclip -selection clipboard -o 2>/dev/null) ;;
esac

if [ -n "$TEXT" ]; then
    # printf avoids a trailing newline; -p keeps the buffer on the stack.
    printf '%s' "$TEXT" | tmux load-buffer -
    tmux paste-buffer -dp
else
    tmux display-message "[paste] Clipboard empty"
fi
