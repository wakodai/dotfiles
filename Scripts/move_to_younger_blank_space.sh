#!/bin/bash

# 現在のディスプレイIDを取得
CURRENT_DISPLAY=$(yabai -m query --windows --window | jq -r '.display')

# カレントディスプレイ上の空のスペースを探す
EMPTY_SPACE=$(yabai -m query --spaces | jq -r --arg display "$CURRENT_DISPLAY" '.[] | select(.windows == [] and .display == ($display | tonumber)) | .in    dex' | sort -n | head -n 1)

# カラのスペースが無い場合は新規作成
if [ -z "$EMPTY_SPACE" ]; then
    # 新しいスペースを現在のディスプレイに作成し、スペースIDを取得
    yabai -m display --focus "$CURRENT_DISPLAY" # カレントディスプレイにフォーカス
    yabai -m space --create
    EMPTY_SPACE=$(yabai -m query --spaces | jq -r --arg display "$CURRENT_DISPLAY" '.[] | select(.windows == [] and .display == ($display | tonumber)) |     .index' | sort -n | head -n 1)
fi

# 移動したスペースにフォーカスを移す
yabai -m space --focus "$EMPTY_SPACE"

