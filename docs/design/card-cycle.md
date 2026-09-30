# Chu kỳ thẻ tín dụng — Design doc

Trạng thái: **đã triển khai** · Code: `Finance.cycle(for:)`, `CardSheet` · Test: `FinanceTests` (các test `card…`, `aCardWith…`)

## Context and motivation

Thẻ Nhật chốt sổ (締め日) một ngày, trừ tiền (支払日) ngày khác. Một món quẹt hôm nay có thể vào sao kê tháng này hoặc tháng sau. Không tách được thì Safe to spend và net worth đếm sai — và từng đếm **đôi** bill trả bằng thẻ.

Goals:
- Tách charge thành **statement** (đã gõ, trả `statementDue`) và **unbilled** (trả `unbilledDue`).
- Ước lượng sao kê kế tiếp mà không bắt gõ chi tiêu hằng ngày.
- Mỗi charge đếm **đúng một lần** vào net worth và Safe to spend.

Non-goals (v1):
- Đọc sao kê tự động.
- Hạn mức, điểm thẻ, trả tối thiểu (リボ).

## Implementation considerations

- `CreditCard.debt` = số sao kê gần nhất, **gõ tay**. Không bao giờ tự cộng khi mua item.
- `closingDay: Int?` — Optional để book cũ decode được, và vì người dùng có thể không biết.
- Mua item bằng thẻ = stock (tài sản, theo giá bán) **và** unbilled (nợ) cùng lúc → net worth chỉ đổi bằng margin dự kiến.

| Lựa chọn khi `closingDay == nil` | Kết quả |
|---|---|
| ~~Lấy tháng dương lịch thay closing day~~ | bill trả thẻ ngày 5 nằm trong `debt` đã gõ **và** là unbilled → đếm đôi, lan vào net worth và Safe to spend |
| **Sao kê đóng hôm nay** (chọn) | `debt` = mọi thứ thẻ đang nợ; cả hai cửa sổ unbilled rỗng; chỉ `comingBills` chiếu tới |

## High-level behavior

Có `closingDay`:
- `lastClosing` = closing day gần nhất ≤ hôm nay; `previousClosing` / `nextClosing` = ±1 tháng.
- `statementDue` = due day kế tiếp sau `lastClosing` — có thể **đã qua** → sao kê coi như đã trả, `owedStatement = 0`.
- Charge trong (previous, last] = trong sao kê; (last, today] = unbilled.
- `unbilledDue` = due day sau max(`nextClosing`, `statementDue`) — không bao giờ cùng ngày với `statementDue`.

Không `closingDay`:
- `lastClosing` = hôm nay. `statementDue` luôn ở phía trước.
- Unbilled = 0. `comingBills` = bill trả thẻ trong (today, +1 tháng].

Ước lượng:
- `livingEstimate` = max(0, debt − stock trong sao kê − bill trong sao kê) — "mọi thứ khác".
- `projectedNext` = unbilled + comingBills + livingEstimate.
- `projectedSteady` = bill hằng tháng + livingEstimate — cho các kỳ xa hơn, không giả định stock.

Bill trả bằng thẻ **không bao giờ** là event tiền mặt vào ngày của nó; tiền mặt rời đi vào due day của thẻ.

## Error handling and UX

- Form thẻ mới **hỏi closing day**.
- Thẻ không có closing day: sheet của thẻ nói bằng chữ nó đang mất gì (không tách được billed / unbilled).
- `Store.purchases(on:in:)` liệt kê item quẹt trong tháng để đối chiếu với sao kê thật.

## Testing approach

Unit trong `FinanceTests`, today = 6/9/2026, thẻ closing 15 / due 10:

| Test | Giữ rule |
|---|---|
| `cardCycleFindsClosingAndDueDates` | ngày closing / due đúng |
| `statementPastDueDayCountsAsPaid` | due đã qua → 0 |
| `unknownClosingDayNeverPutsTwoStatementsOnOneDay` | hai due không trùng ngày |
| `stockBoughtThisMonthIsUnbilledNotStatement` | mua sau closing → unbilled |
| `cardStockPurchaseMovesNetWorthByMarginOnly` | net worth chỉ đổi bằng margin |
| `aCardWithNoClosingDayCountsEachChargeOnce` | không đếm đôi |
| `aCardWithAClosingDayStillSplitsBilledFromUnbilled` | vẫn tách khi có closing |
| `cardPaidBillsNeverAppearOnTheirOwnDay` | bill thẻ không có event riêng |

## Acceptance criteria

- [ ] Given closing 15, due 10, today 6/9, when mua ¥100,000 ngày 1/9, then unbilled +¥100,000, `debt` không đổi.
- [ ] Given today 11/9 (qua due 10/9), then `owedStatement` = 0.
- [ ] Given thẻ không closing day, tiền nhà ¥180,000 trả bằng thẻ đã qua ngày, then tiền nhà đếm 0 lần ngoài `debt`.
- [ ] Given bất kỳ thẻ nào, then `statementDue ≠ unbilledDue`.
