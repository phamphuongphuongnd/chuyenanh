#!/usr/bin/env bash
# Tải font Noto (giấy phép OFL 1.1) vào app/assets/fonts/ — cần cho chữ Việt có dấu + Trung/Nhật/Hàn khi xuất PDF.
# Chạy trong thư mục app/:  bash tool/fetch_fonts.sh
# Font KHÔNG nằm trong git (~39 MB). Thiếu font thì app vẫn chạy nhưng PDF xuất ra lỗi chữ có dấu và CJK.
# Giấy phép Noto (OFL-1.1) đã commit sẵn ở assets/fonts/OFL-Noto.txt — bắt buộc đi kèm font khi phát hành.
# Ghi chú: NotoSansSC/JP/KR là bản biến thiên (variable) — Syncfusion vẽ được nhưng nét hơi mảnh.
set -euo pipefail
cd "$(dirname "$0")/../assets/fonts"
B=https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSans/full/ttf
G=https://github.com/google/fonts/raw/main/ofl
get() { [ -s "$1" ] && { echo "đã có $1"; return; }; echo "tải $1"; curl -fsSL -o "$1" "$2"; }
get NotoSans-Regular.ttf   "$B/NotoSans-Regular.ttf"
get NotoSans-Bold.ttf      "$B/NotoSans-Bold.ttf"
get NotoSansSC-Regular.ttf "$G/notosanssc/NotoSansSC%5Bwght%5D.ttf"
get NotoSansJP-Regular.ttf "$G/notosansjp/NotoSansJP%5Bwght%5D.ttf"
get NotoSansKR-Regular.ttf "$G/notosanskr/NotoSansKR%5Bwght%5D.ttf"
echo "xong:"; ls -la ./*.ttf
