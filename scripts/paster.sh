#!/bin/bash

# Universal paste: images get saved + path inserted, text gets pasted directly.

SCREENSHOT_DIR="${1:-$HOME/.cache/tmux-paste-image}"
mkdir -p "$SCREENSHOT_DIR"

# Detect clipboard content type
if [ -n "$WAYLAND_DISPLAY" ]; then
    MIME=$(wl-paste --list-types 2>/dev/null | head -20)
    HAS_IMAGE=$(echo "$MIME" | grep -c "image/")
    HAS_TEXT=$(echo "$MIME" | grep -c "text/")
else
    MIME=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null)
    HAS_IMAGE=$(echo "$MIME" | grep -c "image/")
    HAS_TEXT=$(echo "$MIME" | grep -c "text/")
fi

# If clipboard has an image (and not just text), save and paste path
if [ "$HAS_IMAGE" -gt 0 ] && [ "$HAS_TEXT" -eq 0 ]; then
    FILENAME="image_$(date +%Y-%m-%d_%H-%M-%S).png"
    FILE_PATH="$SCREENSHOT_DIR/$FILENAME"

    if [ -n "$WAYLAND_DISPLAY" ]; then
        wl-paste --type image/png > "$FILE_PATH" 2>/dev/null
    else
        xclip -selection clipboard -t image/png -o > "$FILE_PATH" 2>/dev/null
    fi

    if [ -s "$FILE_PATH" ]; then
        PANE_CONTENT=$(tmux capture-pane -p | tail -5)
        if echo "$PANE_CONTENT" | grep -qE "(^›|^>|claude.*›|Human:|Assistant:)"; then
            tmux send-keys "/image $FILE_PATH" Enter
            tmux display-message "[paste] Image → Claude: $(basename $FILE_PATH)"
        else
            tmux send-keys "$FILE_PATH"
            tmux display-message "[paste] Image path: $FILE_PATH"
        fi
    else
        rm -f "$FILE_PATH"
        tmux display-message "[paste] No image data in clipboard"
    fi
else
    # Text paste — just send it through tmux
    if [ -n "$WAYLAND_DISPLAY" ]; then
        TEXT=$(wl-paste 2>/dev/null)
    else
        TEXT=$(xclip -selection clipboard -o 2>/dev/null)
    fi

    if [ -n "$TEXT" ]; then
        # Use printf to avoid trailing newline, -p to not remove from buffer stack
        printf '%s' "$TEXT" | tmux load-buffer -
        tmux paste-buffer -dp
    else
        tmux display-message "[paste] Clipboard empty"
    fi
fi
