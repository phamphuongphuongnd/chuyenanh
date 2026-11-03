#!/usr/bin/env bash
# Tải font Noto Sans (giấy phép OFL 1.1) vào app/assets/fonts/ — cần cho chữ Việt có dấu khi xuất PDF.
# Chạy trong thư mục app/:  bash tool/fetch_fonts.sh
# Font KHÔNG nằm trong git (~1,7 MB). Thiếu font thì app vẫn chạy nhưng PDF xuất ra lỗi chữ có dấu.
# App chỉ hỗ trợ tiếng Việt + tiếng Anh: KHÔNG tải font Trung/Nhật/Hàn (chữ CJK khi xuất thành `?`).
# Giấy phép Noto (OFL-1.1) đã commit sẵn ở assets/fonts/OFL-Noto.txt — bắt buộc đi kèm font khi phát hành.
set -euo pipefail
cd "$(dirname "$0")/../assets/fonts"
B=https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSans/full/ttf
get() { [ -s "$1" ] && { echo "đã có $1"; return; }; echo "tải $1"; curl -fsSL -o "$1" "$2"; }
get NotoSans-Regular.ttf   "$B/NotoSans-Regular.ttf"
get NotoSans-Bold.ttf      "$B/NotoSans-Bold.ttf"
echo "xong:"; ls -la ./*.ttf
