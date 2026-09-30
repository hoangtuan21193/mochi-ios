# Testing & verify

Swift Testing (`import Testing`, `@Test`), không XCTest. Không CI — agent và người chạy tay theo [Definition of Done](sdlc.md#definition-of-done).

## Ba tầng

| Tầng | Test cái gì | Ở đâu | Khi nào bắt buộc |
|---|---|---|---|
| **Unit** | công thức `Finance`, decode tương thích | `MochiTests/FinanceTests.swift` | mọi thay đổi `Finance.swift` hay `Models/` |
| **Integration** | `Store` end-to-end: parse → preview → commit → undo | `MochiTests/ImportOldSheetTests.swift` | mọi thay đổi `Store+Import.swift` |
| **Manual** | màn hình thật, book mẫu, fresh install | simulator | mọi thay đổi UI |

## Suite hiện có

| Suite | Giữ điều gì |
|---|---|
| `FinanceTests` | mọi công thức Overview với book nhỏ, **today = CN 6/9/2026** (sau closing 15/8, trước due 10/9) |
| `CompatibilityTests` | `version1BookDecodes` (file version 1 vẫn mở), `currentBookRoundTrips` |
| `ImportOldSheetTests` | sheet định dạng Google Sheets gốc và mọi rule import |

Book trong `FinanceTests.book()`: ví Bank ¥500,000 · thẻ Card closing 15, due 10, debt ¥300,000 · Mercari 10% · lương 25 · tiền nhà 27 trả bằng thẻ · bảo hiểm 30 · buffer ¥100,000.

## Viết test

- **"Today" luôn cố định.** Không `Date.now` trong test. Dùng `FinanceTests.day(y, m, d)`.
- **Tên test là một câu nói rule**: `aCardWithNoClosingDayCountsEachChargeOnce`, `rentIsNotALiability`.
- **Có case âm**: thứ *không* được đếm (điểm không vào cash, bill trả thẻ không có ngày riêng).
- **Bug đã sửa → test tái hiện bug trước.** Ví dụ `unknownClosingDayNeverPutsTwoStatementsOnOneDay`.
- Tổng phải khớp dòng: `walletSectionTotalsMatchTheirRows`, `netWorthPartsAddUp`.
- Field lưu trữ mới → thêm vào kỳ vọng của `version1BookDecodes`.

## Lệnh

Build (0 warning trong `Mochi/` mới tính là pass):

```bash
xcodebuild -project Mochi.xcodeproj -scheme Mochi -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | grep -E "error:|warning: .*Mochi/|BUILD"
```

Tìm UDID simulator:

```bash
xcrun simctl list devices booted
```

Test:

```bash
xcodebuild -project Mochi.xcodeproj -scheme Mochi -destination "platform=iOS Simulator,id=<udid>" test 2>&1 | grep -E "error:|✘|Test run with"
```

Chạy với book mẫu, mở thẳng một tab (0 Overview · 1 Inventory · 2 Stats · 3 Wallet · 4 Settings):

```bash
xcrun simctl launch <udid> com.hoangtuan.mochi -demo 1 -tab 3
```

> `-demo 1` **xoá** dữ liệu hiện có của simulator và nạp book mẫu.

## Checklist kiểm tay (UI)

- [ ] Mở `-demo 1`, vào đúng tab đã sửa, chụp screenshot
- [ ] Book rỗng (fresh install): `xcrun simctl uninstall` rồi cài lại — màn hình có empty state hợp lý
- [ ] Chuỗi dài tiếng Việt không vỡ layout (tile `Metric` cùng chiều cao)
- [ ] Form: dòng preview đúng trước nút
- [ ] Thao tác phá huỷ: alert hiện trước
- [ ] Nhập tiền: `MoneyField`, phép tính `+ − × ÷` chạy
- [ ] Tên riêng: không autocorrect

**Gõ dữ liệu test:** bàn phím simulator có thể là Telex tiếng Việt — dùng `xcrun simctl pbcopy <udid>` rồi nút Paste, không dùng `text`.

## Báo cáo cuối mỗi thay đổi

```
Đã làm:     <thay đổi người dùng thấy>
Đã test:    build sạch · N test pass · screenshot tab X với -demo 1
Chưa test:  <thiết bị thật / fresh install / tiếng Nhật / …>
```
