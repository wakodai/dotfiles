#!/bin/bash

# 指定されたディスプレイID
TARGET_DISPLAY="$1"

# ターゲットディスプレイ上の空のスペースを探す
EMPTY_SPACE=$(yabai -m query --spaces | jq -r --arg display "$TARGET_DISPLAY" '.[] | select(.windows == [] and .display == ($display | tonumber)) | .index' | sort -n | head -n 1)

# カレントウィンドウのIDを取得
CURRENT_WINDOW=$(yabai -m query --windows --window | jq -r '.id')

# ターゲットディスプレイ上に空のスペースが無い場合は新規作成
if [ -z "$EMPTY_SPACE" ]; then
    # ターゲットディスプレイにフォーカスして新しいスペースを作成
    yabai -m display --focus "$TARGET_DISPLAY"
    yabai -m space --create
    EMPTY_SPACE=$(yabai -m query --spaces | jq -r --arg display "$TARGET_DISPLAY" \
        '.[] | select(.windows == [] and .display == ($display | tonumber)) | .index' | sort -n | head -n 1)
fi

# カレントウィンドウをターゲットディスプレイ上のブランクスペースに移動
yabai -m window "$CURRENT_WINDOW" --space "$EMPTY_SPACE"

# 移動したスペースにフォーカスを移す
yabai -m space --focus "$EMPTY_SPACE"

