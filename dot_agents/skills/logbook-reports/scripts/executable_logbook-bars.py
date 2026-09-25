#!/usr/bin/env python3
"""logbook の日次ログを縦=日付・横=棒グラフで表示する。

使い方:
    logbook-bars                       # 当月
    logbook-bars 2026-07               # 指定月
    logbook-bars 2026-07 --employee ID # 他の従業員
    logbook-bars 2026-07 --no-color    # 色なし（パイプ時は自動で色なし）
"""

import argparse
import calendar
import json
import subprocess
import sys
from datetime import date

WEEKDAYS = "月火水木金土日"
MIN_PER_CELL = 20          # 棒グラフ 1 文字あたりの分数
SCHEDULED_MIN = 8 * 60     # 所定労働 1 日 8 時間
LABEL_W = 13               # "07-14 (火)  " の表示幅

C = {
    "reset": "\033[0m",
    "dim": "\033[2m",
    "bold": "\033[1m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "cyan": "\033[36m",
    "red": "\033[31m",
    "blue": "\033[34m",
}


def paint(text, *names):
    if not USE_COLOR:
        return text
    return "".join(C[n] for n in names) + text + C["reset"]


def run_logbook(subcommand, month, employee=None):
    cmd = ["logbook", subcommand, "--month", month, "--json"]
    if employee:
        cmd += ["--employee", employee]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(proc.stderr.strip() or f"`{' '.join(cmd)}` に失敗しました")
    return json.loads(proc.stdout)


def hm(minutes, signed=False):
    sign = "+" if signed and minutes >= 0 else "-" if minutes < 0 else ""
    m = round(abs(minutes))
    return f"{sign}{m // 60}h {m % 60:02d}m"


def make_bar(minutes, width, mark):
    """労働時間の棒。8h までは緑、超過分はシアン、不足分は薄いドットで埋める。"""
    cells = minutes / MIN_PER_CELL
    full = int(cells)
    half = (cells - full) >= 0.5

    out = ""
    for i in range(width):
        if i < full:
            out += paint("█", "green" if i < mark else "cyan")
        elif i == full and half:
            out += paint("▌", "green" if i < mark else "cyan")
        elif i < mark:
            out += paint("·", "dim")
        else:
            out += " "
    return out.rstrip()


def scale_header(width, mark):
    """時間目盛りと罫線の 2 行を返す。"""
    labels = [" "] * width
    rule = ["─"] * width
    for h in range(0, width * MIN_PER_CELL // 60 + 1, 2):
        pos = h * 60 // MIN_PER_CELL
        if pos >= width:
            break
        text = f"{h}h"
        if pos + len(text) <= width:
            labels[pos:pos + len(text)] = list(text)
        rule[pos] = "┼"
    if mark < width:
        rule[mark] = "┿"
    pad = " " * LABEL_W
    return (pad + paint("".join(labels), "dim"),
            pad + paint("".join(rule), "dim"))


def main():
    ap = argparse.ArgumentParser(
        description="logbook の日次労働時間を横棒グラフで表示する")
    ap.add_argument("month", nargs="?", default=date.today().strftime("%Y-%m"),
                    help="対象月 (YYYY-MM, 既定: 当月)")
    ap.add_argument("--employee", help="従業員 ID (既定: config の default_employee)")
    ap.add_argument("--no-color", action="store_true", help="色を付けない")
    args = ap.parse_args()

    global USE_COLOR
    USE_COLOR = not args.no_color and sys.stdout.isatty()

    try:
        year, mon = (int(x) for x in args.month.split("-"))
        date(year, mon, 1)
    except ValueError:
        sys.exit(f"月の指定が不正です: {args.month} (YYYY-MM 形式で指定してください)")

    summary = run_logbook("summary", args.month, args.employee)
    logs = {row["date"]: row
            for row in run_logbook("log", args.month, args.employee)}
    specials = {s["date"]: s for s in summary.get("specialdays", [])}

    work_min = summary["work_ns"] / 6e10
    leave_min = summary["leave_ns"] / 6e10
    sched_min = summary["scheduled_worktime_ns"] / 6e10
    total_min = work_min + leave_min
    diff_min = total_min - sched_min

    print()
    print(paint(f"{summary['name']} ({summary['employee_id']})  {args.month}", "bold"))
    print(f"  所定 {hm(sched_min)} ({summary['scheduled_workdays']}日)"
          f"   実労働 {hm(work_min)} + 休暇 {hm(leave_min)}"
          f" = {paint(hm(total_min), 'bold')}"
          f"   {paint(hm(diff_min, signed=True), 'green' if diff_min >= 0 else 'red')}")
    print()

    max_min = max([r["work_ns"] / 6e10 for r in logs.values()] + [SCHEDULED_MIN])
    width = int(max_min / MIN_PER_CELL) + 4
    mark = SCHEDULED_MIN // MIN_PER_CELL
    for line in scale_header(width, mark):
        print(line)

    today = date.today()
    no_record = []
    for day in range(1, calendar.monthrange(year, mon)[1] + 1):
        d = date(year, mon, day)
        iso = d.isoformat()
        row = logs.get(iso)
        special = specials.get(iso)
        is_holiday = d.weekday() >= 5 or (special and special["type"] == "休")

        # 曜日が全角 1 文字ぶん広いので、パディングは LABEL_W - 1 で表示幅を揃える
        plain = f"{d.month:02d}-{d.day:02d} ({WEEKDAYS[d.weekday()]})".ljust(LABEL_W - 1)
        label = paint(plain, "dim") if is_holiday else plain

        if row:
            minutes = row["work_ns"] / 6e10
            day_sched = 0 if is_holiday else SCHEDULED_MIN
            gap = minutes - day_sched
            tail = (f"  {hm(minutes):>8}  "
                    + paint(f"{hm(gap, signed=True):>8}",
                            "green" if gap >= 0 else "yellow"))
            bar = make_bar(minutes, width, day_sched // MIN_PER_CELL)
            pad = " " * max(0, width - visible_len(bar))
            print(label + bar + pad + tail)
        elif is_holiday:
            note = f"  {special['description']}" if special else ""
            print(label + paint("休" + note, "dim"))
        elif d > today:
            print(label + paint("―", "dim"))
        else:
            # 所定労働日なのにログが無い日。月の休暇合計があれば休暇の可能性が高い
            no_record.append(iso)
            note = "  (休暇と推定)" if leave_min > 0 else "  (記録なし)"
            print(label + paint("░" * mark, "dim") + paint(note, "dim"))

    print()
    print(paint("  █ 8h まで   █ 8h 超過   · 8h への不足   ░ ログ無し"
                f"   ┿ = 8h ライン   1 文字 = {MIN_PER_CELL} 分", "dim"))
    if no_record and leave_min > 0:
        print(paint(f"  休暇合計 {hm(leave_min)} ({summary['leave_days']}日) / "
                    f"ログの無い所定労働日 {len(no_record)}日 — "
                    "休暇の日付は API に無いため推定です", "dim"))
    print()


def visible_len(s):
    """ANSI エスケープを除いた表示幅。"""
    out, i = 0, 0
    while i < len(s):
        if s[i] == "\033":
            while i < len(s) and s[i] != "m":
                i += 1
            i += 1
        else:
            out += 1
            i += 1
    return out


if __name__ == "__main__":
    main()
