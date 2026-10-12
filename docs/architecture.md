# Kiến trúc

SwiftUI, iOS 17+, target app + extension `MochiWidgets`, không package ngoài. Tính năng AI on-device chỉ bật trên iOS 26 (`#if canImport(FoundationModels)`). Cây thư mục chi tiết: `CLAUDE.md` mục Layout.

## Bốn lớp, một chiều

```
Models/        struct Codable thuần — không logic tiền
   │
Engine/Finance*.swift  hàm thuần: (AppData, Date) → con số
Engine/ReceiptParser, StatementParser   hàm thuần: chữ → bản nháp
   │
Store/Store.swift      @Observable, instance duy nhất — đọc/ghi AppData, gọi Finance
   │
Features/*             View: đọc store.x, gọi store.doY()
```

| Lớp | Được làm | Không được làm |
|---|---|---|
| **Models** | khai báo field, `init(from:)` tương thích ngược, helper thuần trên một struct (`InstallmentSchedule`) | đọc `Store`, `Date.now` ngầm |
| **Finance** | mọi phép tính hiện trên màn hình | đọc gì ngoài `AppData` + `Date`; side effect |
| **Store** | CRUD, undo, log ledger, ghi lịch đến hạn, save/load, backup, import, OCR/vị trí/iCloud/widget (file `Store+*.swift`, `ReceiptReader`, `NearbyPlace`, `CloudSync`) | công thức mới chưa có trong `Finance` |
| **View** | layout bằng component `DesignSystem/` | cộng trừ tiền, filter/sort list, parse số |

- **Không view model.** Một screen = một folder trong `Features/`, sheet nằm cạnh screen.
- **Synchronized folders:** file `.swift` mới trong `Mochi/`, `MochiWidgets/` hoặc `MochiTests/` tự vào target. Không sửa pbxproj cho file; di chuyển file bằng `git mv`.
- **Điều hướng:** `Router` (@Observable) giữ tab đang chọn, capture đang mở, filter của Transactions. Intent và URL `mochi://scan|add|review` đi qua nó.
- **`Store.shared`:** App Intents chạy ngoài cây view nên cần đúng instance đó; view vẫn lấy qua `@Environment(Store.self)`.

## Luồng một thao tác

Ví dụ: chụp hoá đơn.

1. Tab Add → `CaptureSheet` → VisionKit quét → `ReceiptReader.lines` (Vision OCR, offline).
2. `ReceiptParser.parse` → `ReceiptDraft` (tổng, ngày, cửa hàng, số đăng ký, 4 số thẻ, dòng hàng). iOS 26 có model thì `understand` bổ sung.
3. `Store.guess` điền tài khoản, category, vị trí, và *vì sao* từng ô.
4. Người dùng xác nhận → `store.addTransaction` (áp luật) → `Store.log` → `save()`.
5. `save()` ghi file, rồi `publishWidgetSnapshot()` cho widget.

Ví dụ: lương về. Không ai gõ gì: `postDueSchedules()` (lúc mở app và lúc quay lại foreground) ghi giao dịch `source: .recurring` với `scheduleID@ngày`, nên chạy lại không ghi đôi.

## Dữ liệu lưu trữ

- Một file: `Application Support/mochi.json`, `JSONEncoder` của `AppData`.
- `AppData.schemaVersion`: book không có key này là version 1.

### Tương thích ngược — luật cứng

| Làm | Không làm |
|---|---|
| field mới `Optional` (`[T]? = nil`) | `var x: Int = 0` không có `init(from:)` — decoder tổng hợp **throw**, cả book mở ra rỗng |
| hoặc đọc trong `init(from:)` bằng `decodeIfPresent ?? default` | đổi tên key |
| giữ field chết để decode (`autoBackup`, `lastBackup`, `SalesChannel.destination`) | xoá field đã từng lưu |
| lưu giá trị ổn định (`Currency` lưu ký hiệu, `AppLanguage` lưu mã) | lưu `rawValue` có thể đổi |

`CompatibilityTests.version1BookDecodes` giữ một file version 1; field mới phải được thêm vào kỳ vọng của fixture.

### Save / load

- `save()`: encode → **bỏ qua** nếu giống lần ghi trước → copy file cũ vào backup ngày (nếu hôm nay chưa có) → ghi atomic.
- `load()` lỗi: copy file sang `mochi.unreadable.json` *trước* mọi save, báo lỗi, giữ book trong bộ nhớ.
- Chi tiết: [design/local-backups.md](design/local-backups.md).

## Thời gian

- `Finance` nhận `today: Date` (mặc định `.now` chỉ ở call site Store). Test luôn truyền ngày cố định.
- `Finance.date(day:in:)` kẹp ngày 31 về cuối tháng ngắn (`dayClampsToShortMonths`).
- Snapshot tháng: `Store.takeMonthlySnapshotIfDue` khi mở app; giữ 36.

## Giao dịch và nhật ký

- **`data.transactions`** là sổ: số dư, chi tiêu, chu kỳ thẻ đều tính từ đây. Chi tiết: [design/transactions.md](design/transactions.md).
- **`data.ledger` (`LedgerEntry`)** là nhật ký thao tác: mỗi lần tiền di chuyển vẫn `Store.log`. Không màn hình nào hiện nó; vẫn phải ghi.

## Ngoài app

| Phần | File | Ghi chú |
|---|---|---|
| Siri / Shortcuts | `Intents/MochiIntents.swift` | số tiền cần Face ID khi khoá máy; thêm chi thì không |
| Widget, Lock Screen, Control | `MochiWidgets/` | đọc `widget.json` trong App Group, không mở sổ |
| iCloud | `Store/CloudSync.swift` | tắt sau cờ `MochiCloudSyncEnabled` |
| Thông báo | `Features/Settings/AutomationViews.swift` (`Notifier`) | lịch cục bộ, không server |

## Undo

| Thao tác | Undo trả lại |
|---|---|
| Import batch | xoá item đã thêm, khôi phục item đã ghi đè (`updatedItems`), xoá channel/wallet đã tạo |
| Xoá thẻ | gỡ liên kết thẻ khỏi item |
| Xoá item | giữ kế hoạch trả góp, bỏ liên kết |
| Undo sale | `unsell` gỡ `SaleRecord` |

## Design system

- Mọi màu, cỡ chữ, bo góc, khoảng cách: `DesignSystem/Tokens.swift` (`Organic`).
- Component theo họ: Containers, Buttons, Selection, Fields, DataDisplay, Layout.
- Luật và catalogue: `design.md`. Thiếu variant → thêm vào file họ tương ứng + `design.md`, không vẽ inline.

## Localization

- `Localizable.xcstrings`, nguồn `en`, khai báo `vi`, `ja`.
- Tham số component mang chữ của app: `LocalizedStringKey`. Tên người dùng gõ: `String` + `Text(verbatim:)`.
- `Store.setLanguage` ghi `AppleLanguages` / `AppleLocale`, hiệu lực lần mở sau.

## Debug flags

| Flag | Tác dụng |
|---|---|
| `-demo 1` | nạp lại book mẫu (`SampleData`) — **xoá dữ liệu hiện có của simulator** |
| `-tab N` | mở tab N: 0 Home · 1 Transactions · 2 Wallet · 3 Belongings · 4 Plan |
