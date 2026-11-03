#!/usr/bin/env bash
# Prints a release's notes for <tag>: the download table, in Persian and
# English, linking to this release's own files (their versioned names,
# AWMVPN-1.2.3-...). It does not read the README, so the notes stay right
# when the README changes.
#
#   bash scripts/release-notes.sh v1.1.1
set -euo pipefail

tag="${1:?usage: release-notes.sh <tag>}"
version="${tag#v}"
repo="${GITHUB_REPOSITORY:-daschera1492/awmvpn-client}"
base="https://github.com/$repo/releases/download/$tag"

file() { echo "$base/AWMVPN-$version-$1"; }
core() { echo "$base/awmvpn-core-$version-$1"; }

cat <<EOF
## دانلود

| سیستم | فایل |
| --- | --- |
| اندروید (همهٔ گوشی‌ها) | [AWMVPN-$version-Android-universal.apk]($(file Android-universal.apk)) |
| اندروید ۶۴ بیتی (ARM) | [AWMVPN-$version-Android-arm64-v8a.apk]($(file Android-arm64-v8a.apk)) |
| ویندوز (نصب‌کننده) | [AWMVPN-$version-Windows-Setup-x64.exe]($(file Windows-Setup-x64.exe)) |
| ویندوز (نسخهٔ پرتابل) | [AWMVPN-$version-Windows-x64.zip]($(file Windows-x64.zip)) |
| مک (Apple Silicon و Intel) | [AWMVPN-$version-macOS.dmg]($(file macOS.dmg)) |
| لینوکس ۶۴ بیتی (x86) | [AWMVPN-$version-Linux-amd64.tar.gz]($(file Linux-amd64.tar.gz)) |
| لینوکس ۶۴ بیتی (ARM) | [AWMVPN-$version-Linux-arm64.tar.gz]($(file Linux-arm64.tar.gz)) |
| هستهٔ لینوکس برای OpenWrt (x86) | [awmvpn-core-$version-linux-amd64.tar.gz]($(core linux-amd64.tar.gz)) |
| هستهٔ لینوکس برای OpenWrt (ARM) | [awmvpn-core-$version-linux-arm64.tar.gz]($(core linux-arm64.tar.gz)) |

## شروع

۱. توکن را از ربات [@awmvpn_bot](https://t.me/awmvpn_bot) بگیرید: دستور `/token`.
۲. برنامه را نصب و باز کنید، به **اشتراک‌ها** بروید و **فعال‌سازی** را بزنید.
۳. کل پیام ربات (یا خود توکن) را بچسبانید. اکانت اضافه می‌شود و تا تاریخ
   پایان توکن کار می‌کند.

هر زیرمجموعه یک جایگاه اشتراک بیشتر می‌دهد. با `/revoke` همهٔ توکن‌های فعال
لغو می‌شوند و برنامه اکانت آن‌ها را حذف می‌کند.

## Download

| System | File |
| --- | --- |
| Android (all phones) | [AWMVPN-$version-Android-universal.apk]($(file Android-universal.apk)) |
| Android 64-bit ARM | [AWMVPN-$version-Android-arm64-v8a.apk]($(file Android-arm64-v8a.apk)) |
| Windows (installer) | [AWMVPN-$version-Windows-Setup-x64.exe]($(file Windows-Setup-x64.exe)) |
| Windows (portable) | [AWMVPN-$version-Windows-x64.zip]($(file Windows-x64.zip)) |
| macOS (Apple Silicon and Intel) | [AWMVPN-$version-macOS.dmg]($(file macOS.dmg)) |
| Linux 64-bit (x86) | [AWMVPN-$version-Linux-amd64.tar.gz]($(file Linux-amd64.tar.gz)) |
| Linux 64-bit (ARM) | [AWMVPN-$version-Linux-arm64.tar.gz]($(file Linux-arm64.tar.gz)) |

Subscriptions come from [@awmvpn_bot](https://t.me/awmvpn_bot): send `/token`,
then paste the bot's message into the app's **Subscriptions** page. There is
no sign-in or sign-up form. Checksums are in \`SHA256SUMS.txt\`; the desktop
apps verify their updates against \`SHA256SUMS.txt.sig\`.
EOF
