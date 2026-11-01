# Export / import sổ theo phần — Design doc

Trạng thái: **đã triển khai** · Code: `Models/BookTransfer.swift`, `Store.exportBookFile(groups:)` / `readBookFile` / `importBook`, `Features/Settings/BookExportView.swift`, `BookImportView.swift` · Test: `BookTransferTests` · Quyết định: #37, `.planboard/book-transfer/`

## Context and motivation

File export là `.json`: share sang iPhone không có "mở bằng Mochi". Nút Import thay cả sổ ngay khi chọn file, không hỏi (sai luật 7). Sửa riêng đồ đạc (làm lại từ Google Sheet) thì phải thay luôn ví, thẻ, giao dịch.

Goals:
- Chạm file ở share sheet / AirDrop / Files là mở Mochi, không ghi gì cho tới khi xác nhận.
- Export và import chọn được từng phần; import chọn thay hay gộp.
- Mọi lần ghi để lại bản sao có giờ trong Earlier copies.

Non-goals (v1):
- Nhận mọi `.json` qua share sheet.
- Chọn chi tiết hơn sáu phần.
- Gộp từng trường của Settings.

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** #5 (backup cục bộ) có non-goal "merge hai book" — nay có, theo phần.
- **Tương thích lưu trữ:** `AppData.exportedGroups: [String]?` (decodeIfPresent). nil = cả sổ, nên file export cũ và sổ trên đĩa đọc như trước. `CompatibilityTests` kiểm tra.
- Mọi khoá của `AppData` đều optional, nên JSON bất kỳ decode thành sổ rỗng; `readBookFile` đòi ít nhất một khoá của sổ.

| Lựa chọn | Được | Mất |
|---|---|---|
| Nhận mọi `.json` | file cũ chạm-mở được | Mochi hiện trên JSON của mọi app |
| **Đuôi `.mochi` (chọn)** | Mochi chỉ hiện cho sổ | `.json` cũ mở qua nút Import |
| Chỉ thay | đơn giản | không thêm được dữ liệu từ máy khác |
| **Mỗi lần hỏi thay/gộp (chọn)** | cả hai việc | thêm một lựa chọn |

## High-level behavior

| Phần | Gồm |
|---|---|
| Belongings | items, categories, channels, importBatches |
| Wallets, cards and debts | wallets, pointWallets, cards, installments, loans, investments, owners |
| Transactions | transactions, spendingCategories, rules, ledger |
| Plan | recurring, budgets, goals |
| Net worth history | snapshots (gộp theo tháng) |
| Settings | currency, language, phí, safetyBuffer, horizon, holdingSources, household, notifications, lookUp*, rates, targetProfit |

1. Export book: sáu công tắc, bật hết; file `mochi-book-YYYY-MM-DD.mochi` mang `exportedGroups`.
2. Mở file: iOS chép vào `Documents/Inbox` → `onOpenURL` → sheet nào đang mở thì đóng → Import book. Đọc xong thì xoá bản trong Inbox.
3. Import book: phần không có trong file mờ đi ("Not in this file"); phần giống sổ ghi "Same as this book" và tắt sẵn; còn lại "Book N · file M", bật sẵn.
4. Replace | Merge (ẩn khi chỉ chọn Settings). Dòng nói trước: mỗi phần "N → M".
5. Nút "Replace 2 parts…" → alert → `importBook`: bản sao có giờ, `BookTransfer.apply`, lưu.
6. Thay cả sáu phần thì lấy luôn `ledgerStart` / `postedThrough` của file; ít hơn thì giữ của sổ.
7. Liên kết `itemID` (trả góp, giao dịch) tới món không còn → nil; import batch không còn món nào → bỏ.

## Testing approach

- Unit: `BookTransferTests` (export chỉ có phần chọn, thay không đụng phần khác, liên kết gãy về nil, gộp theo id, Settings luôn thay, phát hiện phần khác sổ, preview, ledgerStart).
- Manual (simulator): `-bookFile <path>` mở Import với file; `xcrun simctl openurl <udid> file:///…/x.mochi` giả AirDrop, cả khi đang mở sheet Export; Share file → Mochi có trong share sheet.

## Acceptance criteria

- [x] Share file `.mochi` → share sheet có Mochi, loại file "Mochi book".
- [x] Mở file khi đang có sheet → sheet đóng, Import book hiện đúng file.
- [x] Chỉ thay Belongings: 9 → 644 món, ví và 117 giao dịch giữ nguyên, có bản `mochi-…-HHmm.json`.
- [x] File không phải sổ → "This is not a Mochi book", sổ không đổi. → "This is not a Mochi book", sổ không đổi.
