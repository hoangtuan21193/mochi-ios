# Số tiền ngoại tệ có phần lẻ — Design doc

Trạng thái: **đã triển khai** · Code: `Transaction.foreignAmount`, `ReceiptDraft.exactTotal`, `CardEmailParser.tapFigure` / `tapCurrency`, `MoneyField(value: Binding<Double>, fractionDigits:)` · Test: `ReceiptCasesTests.aTotalInAnotherCurrencyKeepsItsCents`, `TapAmountTests`, `TapCurrencyTests`, `MoneyExpressionCentsTests`

## Context and motivation

Một lần quẹt Apple Pay ở nước ngoài ($12.50) bị lưu thành $13 vì `foreignAmount` là `Int`. Số yên quy đổi lệch theo (¥1,912 thay vì ¥1,838 ở 0.0068 $/¥), và so trùng với email thẻ có thể trượt.

Goals:
- Lưu đúng số tiền đã trả, cả phần lẻ, cho mọi giao dịch ngoại tệ.
- Gõ được phần lẻ ở màn sửa giao dịch và màn Check and save.

Non-goals (v1):
- Sổ giữ bằng USD/EUR (`amount` của sổ vẫn là `Int`).
- Giá từng dòng hàng trên hoá đơn (`ReceiptDraft.Line.price`) vẫn là số nguyên: chỉ dùng để gợi ý món đồ thành belonging.

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** không có.
- **Tương thích lưu trữ:** giữ nguyên key `foreignAmount`, đổi kiểu `Int?` → `Double?`. Sổ cũ có `"foreignAmount": 12` đọc ra 12.0 (`decodeIfPresent(Double.self)` nhận số nguyên JSON). Test: `aBookWrittenWithWholeForeignAmountsStillOpens`.

| Lựa chọn | Được | Mất |
|---|---|---|
| A. Đơn vị nhỏ (cent) trong `Int`, key mới | số nguyên chính xác | key mới + chuyển đổi sổ cũ; phải biết số chữ số lẻ của từng loại tiền khi đọc |
| **B. `Double`, cùng key (chọn)** | sổ cũ đọc thẳng, không đổi tên key (rule 3) | sai số dấu phẩy động — không đáng kể: số tiền chỉ để hiển thị và chia cho tỉ giá rồi làm tròn ra yên |

## High-level behavior

1. Action "Add an Apple Pay spend" nhận Amount dạng chuỗi; `tapFigure` đọc số kèm phần lẻ ("US$12.50" → 12.5), `tapCurrency` đọc loại tiền.
2. Ngoại tệ: `foreignAmount = 12.5`, `amount = Finance.convert(12.5, rate:)` làm tròn ra yên. Chưa có tỉ giá → To review.
3. So trùng ngoại tệ (`Finance.sameSpend(paid:currency:...)`) so đúng 12.5, không so số yên.
4. `MoneyField` với `fractionDigits > 0` dùng bàn phím `.decimalPad`; chỉ dấu thập phân của locale là dấu lẻ (ở tiếng Việt "." là dấu nhóm nghìn).
5. Scan hoá đơn: `ReceiptDraft.exactTotal` giữ tổng như in ("TOTAL $4.85" → 4.85); `total` (Int) suy ra từ nó cho phần tính yên, điểm của lần đọc và kiểm tra tổng dòng. Hai ảnh ghép (`joined`) giữ phần lẻ của ảnh phía dưới. `ReceiptParser.exactUnits` đọc "1.234,56" là 1234.56, "74.700" vẫn là 74,700.
6. Hiển thị: `Currency.foreign(12.5, code: "USD")` → "USD 12.50"; số tròn → "USD 12".

## Tỉ giá tự lấy (quyết định #31)

- `ExchangeRates.parse` đọc reply của `https://open.er-api.com/v6/latest/<mã tiền của sổ>` — số đơn vị ngoại tệ cho 1 đơn vị của sổ, đúng cách `AppData.rates` giữ. Chỉ mã tiền rời máy.
- `Finance.ratesDue`: bật, và chưa tra lần nào hoặc lần cuối quá 12 giờ. `Store.refreshRates` chạy lúc mở app và lúc quay lại app; `Store.rate(for:)` tra ngay khi thiếu.
- Field mới: `AppData.ratesFetched: Date?`, `AppData.lookUpRates: Bool?` (nil = bật) — Optional, sổ cũ đọc được.
- Check and save: không có thẻ tỉ giá (design đúng). Đang tra: "Getting today's USD rate…", nút Save chờ. Không có tỉ giá: lưu vào To review với ¥0. Action Apple Pay làm như vậy.
- Test: `ExchangeRatesTests`.

## Vàng và crypto (planboard .planboard/gold-crypto)

- `Prices` (Engine): đọc gold-api.com (USD/oz) và CoinGecko (simple/price, search); 10 coin phổ biến cố định. `Finance.goldUnitPrice`, `Finance.priced`, `Finance.gainOnPaid`, `Finance.pricesDue`.
- `Investment` thêm `quantity`, `unit`, `goldKind`, `coinID`, `coinSymbol`, `unitPrice`, `pricedAt` (Optional); kind "gold"/"crypto" không tính vào hạn mức NISA.
- Màn: Investments có mục Gold và Crypto (SectionHeader +), `GoldSheet`, `CoinSheet`; công tắc riêng trong Your data.
- Test: `PricesTests`.
