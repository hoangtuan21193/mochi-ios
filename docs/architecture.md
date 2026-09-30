# Kiến trúc

SwiftUI, iOS 17+, một target, không package ngoài. Cây thư mục chi tiết: `CLAUDE.md` mục Layout.

## Bốn lớp, một chiều

```
Models/        struct Codable thuần — không logic tiền
   │
Engine/Finance.swift   hàm thuần: (AppData, Date) → con số
   │
Store/Store.swift      @Observable, instance duy nhất — đọc/ghi AppData, gọi Finance
   │
Features/*             View: đọc store.x, gọi store.doY()
```

| Lớp | Được làm | Không được làm |
|---|---|---|
| **Models** | khai báo field, `init(from:)` tương thích ngược, helper thuần trên một struct (`InstallmentSchedule`) | đọc `Store`, `Date.now` ngầm |
| **Finance** | mọi phép tính hiện trên màn hình | đọc gì ngoài `AppData` + `Date`; side effect |
| **Store** | CRUD, undo, log ledger, save/load, backup, import | công thức mới chưa có trong `Finance` |
| **View** | layout bằng component `DesignSystem/` | cộng trừ tiền, filter/sort list, parse số |

- **Không view model.** Một screen = một folder trong `Features/`, sheet nằm cạnh screen.
- **Synchronized folders:** file `.swift` mới trong `Mochi/` hoặc `MochiTests/` tự vào target. Không sửa pbxproj; di chuyển file bằng `git mv`.

## Luồng một thao tác

Ví dụ: bán một item.

1. View gọi `store.sell(item, channelName:, price:)`.
2. `Store` tính `SaleRecord.net` qua `Finance.netProceeds`, gắn `sale` vào item.
3. `Store.log` ghi `LedgerEntry` kind `"x"` (bản ghi, không di chuyển tiền).
4. `Store.save()` → file trên đĩa.
5. `@Observable` báo view; view đọc lại `store.resaleBusiness`, v.v.

Ví không đổi — người dùng gõ số dư mới khi tiền về thật.

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

## Ledger

- Mỗi lần tiền di chuyển → `Store.log(LedgerEntry)`. Mua/bán cũng log (kind `"x"`).
- **Không màn hình nào hiện ledger** hiện nay. Vẫn phải ghi: đó là bản ghi duy nhất *vì sao* một số dư gõ tay thay đổi, không dựng lại được.
- Thứ gì hiện lại ledger thì đọc `data.ledger` mới nhất trước.

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
| `-tab N` | mở tab N (0…4) |
