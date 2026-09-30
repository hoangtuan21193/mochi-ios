# Import sheet — Design doc

Trạng thái: **đã triển khai** · Code: `Store+Import.swift`, `Features/Import/` · Test: `ImportOldSheetTests`

## Context and motivation

Sổ mua bán sống nhiều năm trong một Google Sheet. Chuyển sang Mochi phải dán cả sheet vào một lần, dán lại khi sheet cập nhật, và **không bao giờ nhân đôi sổ**.

Goals:
- Dán TSV/CSV (từ Google Sheets hay từ Export của chính app) → xem preview → commit.
- Đọc cột theo **tên header**, không theo vị trí.
- Dán lại cùng một sheet → 0 item mới.
- Sheet đi trước sổ (dòng đã bán) → cập nhật item có sẵn.
- Undo một batch trả lại đúng như trước.

Non-goals (v1):
- Đọc `.xlsx`, kết nối Google Sheets API.
- Import ví, thẻ, trả góp — chỉ item.
- Đoán ngày mua khi sheet không có cột ngày.

## Implementation considerations

- **Parse không đụng store.** `parseImport` trả `ImportPreview`; chỉ `commitImport` ghi.
- **Delimiter:** tab hay phẩy, cái nào nhiều hơn ở dòng đầu. File có tab không bao giờ bị coi là CSV.
- **Header fold:** bỏ hoa/thường, dấu, full-width → khớp `Store.columnAliases` (tiếng Anh, Việt, Nhật). Chỉ cột **Name** bắt buộc để coi dòng đầu là header.
- **Cột nhìn giống mà không được đọc** — `Store.columnsIgnored`:

| Cột | Vì sao bỏ |
|---|---|
| Thẻ vợ / Thẻ chồng | thẻ của người khác, không phải thẻ đã mua món này |
| % Point | tỉ lệ điểm; số điểm là cột Earn Point |
| New price / Giá mới | giá mới, không phải giá bán được bây giờ |
| Loan time | độ dài kế hoạch sống ở Wallet |

- Cột lạ **bị bỏ qua**, không đẩy các cột khác lệch đi. Cả cột bỏ và cột lạ đều liệt kê trên màn hình đúng như đã viết.

## High-level behavior

1. Người dùng dán text → `parseImport` → preview: dòng, cảnh báo, lỗi, cột dùng / bỏ, channel mới.
2. Mỗi dòng được gắn `DuplicateKind` so với sổ **và** với các dòng trước trong cùng sheet.
3. Dòng trùng mặc định **tắt**; dòng đã bán trùng item có sẵn thành **update**.
4. Hai dòng điều khiển trên list:
   - Lặp lại: **Skip them** / **Import anyway**
   - Đã bán: **Mark them sold** / **Leave mine as they are**
5. `commitImport` ghi theo thứ tự sheet (`insert(contentsOf:at: 0)`), tạo `ImportBatch`.

### Nhận diện purchase

`Store.purchaseKey` = **Item + 購入日 + Buy on Market**. Không gì khác.

- Không có *Sell on*: cùng dòng export lại với channel khác vẫn là cùng purchase.
- Không có giá: gõ lại số không tạo ra món thứ hai.
- Thẻ không thay thế được shop bị thiếu.

| `DuplicateKind` | Điều kiện | Là trùng? | Mặc định |
|---|---|---|---|
| `none` | — | không | bật |
| `sameNameOnly` | cùng tên, khác ngày | không, badge "Same name" | bật |
| `sameNameAndDate` | cùng tên + ngày, khác market | không, badge | bật |
| `exact` | cùng 3 cột với item trong sổ | **có**, "Already here" | tắt |
| `repeatedInFile` | cùng 3 cột với dòng trước trong sheet | **có**, "Twice in this sheet" | tắt |

### Dòng đã bán ghi đè

- Dòng trùng mà cột Sold = TRUE → `ImportRow.updates` = id item sẽ bị ghi.
- `Store.merge(_:over:)` đặt dòng lên item: giữ id, giữ condition / accessories / attributes (sheet không có cột này).
- Item **như trước** lưu vào `ImportBatch.updatedItems` để undo.
- Đếm riêng mọi nơi: `batch.count` = thêm mới, `updatedCount` = ghi đè.

### Sheet không có cột ngày

Sheet Google gốc: `Sold? · Item · Thẻ vợ · Buy · Buy on Market · % Point · Earn Point · New price · Sell Price · Sell on · Shipping Fee · Income · Profit`.

- Mọi dòng được đặt ngày hôm nay — ngày của app, không phải của sổ.
- Hai dòng cùng tên + market → "Same name", **cả hai vào** (hai món giống nhau và một dòng gõ hai lần trông như nhau).

### Sheet thắng suy luận của app

- Sell on trống = "Keeping" **chỉ khi** cột status im lặng.
- `Sold?` = FALSE + Sell on trống → stock, chưa có nơi bán.

## Error handling and UX

| Loại | Xử lý |
|---|---|
| Không có header nào chứa cột Name | đọc theo vị trí, thứ tự cột Export; preview báo "No header row" |
| Dòng không parse được | `failures` (số dòng + lý do), các dòng khác vẫn vào |
| Giá trị lạ trong ô | `warnings` trên dòng, dòng vẫn vào |
| Channel / wallet chưa có | tạo mới, ghi vào batch để undo xoá |

## Lifecycle

- `commitImport` so trùng với sổ **như lúc bấm nút**, không bao giờ với dòng vừa ghi trong cùng lần dán (gộp 2 dòng thành 1 từng làm import 5 dòng chỉ ghi 3).
- `ImportHistoryView` (Settings): xem batch, `deleteImportBatch` (undo), `forgetImportBatch` (giữ item, quên batch).

## Future-proofing

- Alias mới: thêm vào `columnAliases`, không đổi code parse.
- Import ví / thẻ: sẽ cần batch ghi thêm loại đối tượng — `ImportBatch` đã có `createdWallets` làm mẫu.

## Testing approach

- Integration trong `ImportOldSheetTests`, dùng sheet định dạng gốc: pin đã bán + pin còn giữ, hai Z8 giá khác nhau, hai ghế giống hệt — tất cả đều vào.

## Acceptance criteria

- [ ] Given sổ rỗng, when dán sheet 5 dòng khác nhau, then 5 item, đúng thứ tự sheet.
- [ ] Given đã import sheet đó, when dán lại, then mọi dòng "Already here", tắt, commit ghi 0.
- [ ] Given chỉ cột Sell on đổi, when dán lại, then vẫn là "Already here".
- [ ] Given item chưa bán trong sổ, when dán dòng cùng key với Sold = TRUE, then item được đánh dấu bán, id giữ nguyên, undo trả lại item chưa bán.
- [ ] Given sheet không cột ngày có hai dòng cùng tên + market, then cả hai vào với badge "Same name".
- [ ] Given cột "Thẻ vợ", then không đọc vào `cardName`, liệt kê là bị bỏ.
- [ ] Given undo một batch, then item thêm biến mất, item ghi đè trở lại, channel tạo mới bị xoá.
