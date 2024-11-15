#!/bin/bash

# カラのスペースを探す
EMPTY_SPACE=$(yabai -m query --spaces | jq -r '.[] | select(.windows == []) | .index' | sort -n | head -n 1)

# カレントウィンドウのIDを取得
CURRENT_WINDOW=$(yabai -m query --windows --window | jq -r '.id')

# カラのスペースが無い場合は新規作成
if [ -z "$EMPTY_SPACE" ]; then
    # 新しいスペースを作成し、スペースIDを取得
    yabai -m space --create
    EMPTY_SPACE=$(yabai -m query --spaces | jq -r '.[] | select(.windows == []) | .index' | sort -n | head -n 1)
fi

# カレントウィンドウを最も若いカラのスペースに移動
yabai -m window "$CURRENT_WINDOW" --space "$EMPTY_SPACE"

# 移動したスペースにフォーカスを移す
#yabai -m space --focus "$EMPTY_SPACE"

