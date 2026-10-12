# Spending — Design doc

Trạng thái: **đã triển khai** (2026-10-04) · Code: `Engine/Finance+Spending.swift`, `Features/Transactions/SpendingSection.swift`, `DesignSystem/DataDisplay.swift` (`ShareRing`, `ShareColumns`, `FlowChart`, `MonthBars`) · Test: `SpendingTests` · Canvas: `Spending`, `SpendingColumns`, `SpendingFlow` (+Dark, iPad, Fold)

## Context and motivation

Spending chỉ có tháng lịch, chia theo category hoặc shop, một biểu đồ vòng. Canvas vẽ thêm: chọn kỳ, chia theo nơi chi, hai kiểu biểu đồ nữa (cột, dòng chảy thu nhập). Mấy phép tính (tháng trước, mỗi ngày, %) đang nằm trong view — phạm luật #2.

Goals:
- Kỳ: tháng lịch, kỳ lương (payday → payday, như Budget), năm. Nút ◀ ▶ bước theo kỳ đó.
- Chia theo Categories · Shops · Places (tên nơi đã lưu trên giao dịch).
- Ba kiểu biểu đồ cho cùng một danh sách: vòng, cột, dòng chảy. Danh sách tên và % bên dưới không đổi.
- Mọi con số trên màn từ `Finance`, có test.

Non-goals (v1):
- Không so kỳ tuỳ chọn (from–to). Không lọc theo tài khoản.
- Dòng chảy không chia nhỏ thu nhập theo nguồn.

## Nằm ở màn hình nào

| Con số / UI | Màn hình | Vì sao |
|---|---|---|
| Đã chi, so kỳ trước, lớn nhất, mỗi ngày | Transactions › Spending | quá khứ |
| Thu nhập → chi → còn lại (dòng chảy) | Transactions › Spending | quá khứ của một kỳ; không phải `monthlyCashFlow` (dự báo, decisions #7) |
| 6 tháng | Transactions › Spending | quá khứ |

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** card "Richer or poorer?" (#7) là *dự báo* tháng này. Dòng chảy ở đây chỉ cộng giao dịch đã ghi trong kỳ đã chọn, nói rõ "income, followed to where it went", nên không đọc thành kết quả tháng. Biểu đồ số dư (#3) vẫn cấm — đây không phải số dư.
- **Tương thích lưu trữ:** không có field mới. Kỳ và kiểu biểu đồ là tuỳ chọn hiển thị (`@AppStorage`), không nằm trong sổ.
- "Left over" = thu nhập − đã chi trong kỳ. Mua đồ (asset) không vào cả hai, như ở tổng.
- Chi hơn thu: cột trái thêm "From what you had" = phần thiếu, không có "Left over".

| Lựa chọn kỳ | Được | Mất |
|---|---|---|
| Chỉ tháng lịch | đơn giản | lương ngày 25 làm tháng nào cũng lệch |
| **Tháng · kỳ lương · năm (chọn)** | khớp Budget; nhìn được cả năm | thêm một menu; kỳ lương chỉ hiện khi có lương |

## High-level behavior

1. Hàng trên: ◀ tên kỳ ▶ và menu "Month ⌄" (Month · Pay period · Year; Pay period chỉ khi sổ có lương). Tương lai không mở.
2. 4 ô: Spent · Against <kỳ trước> · Largest (% của tổng) · Per day (số ngày đã qua của kỳ).
3. Where it went: Categories · Shops · Places, rồi biểu đồ, rồi nút đổi kiểu biểu đồ (vòng · cột · dòng chảy), rồi danh sách.
   - Cột: một cột một dòng, số rút gọn (85k) trên đầu, icon category (hoặc chữ đầu tên shop/nơi) dưới chân.
   - Dòng chảy: thu nhập bên trái, 3 dòng lớn nhất + "N more" + "Left over" bên phải.
4. Dòng xanh: mua đồ trong kỳ (không vào tổng), giá trị đồ mất trong một tháng.
5. Last six months: cột có số trên đầu, tháng đang xem đậm; chạm để đi tới tháng đó.

## Công thức

```swift
enum SpendingPeriod { case month, payPeriod, year }
static func spendingInterval(_ data: AppData, _ p: SpendingPeriod, containing: Date) -> DateInterval
static func spendingSummary(_ data: AppData, _ p: SpendingPeriod, containing: Date, by: SpendingSplit, today: Date) -> SpendingSummary
// spent, previous (nil nếu kỳ trước chưa có gì), largest + percent, perDay, days, shares (+ percent)
static func spendingByPlace(_ data: AppData, in: DateInterval) -> [Share]
static func incomeFlow(_ data: AppData, in: DateInterval, shares: [Share]) -> IncomeFlow
```

## Testing approach

- `SpendingTests`: kỳ lương bước đúng; per day đếm ngày đã qua; % cộng lại ≤ 100; places gom theo tên; dòng chảy: left over = thu − chi, chi > thu thì có "from what you had"; "N more" gom phần còn lại.
- Manual: `-open spending`, ba kiểu biểu đồ qua `-spending.chart ring|columns|flow`, kỳ qua `-spending.period month|payPeriod|year`.

## Acceptance criteria

- [x] Given lương ngày 25, when chọn Pay period, then kỳ là 25 → 24 và ◀ lùi đúng một kỳ.
- [x] Given chi > thu, then dòng chảy không có Left over âm.
- [x] Given view, then không có phép cộng trừ nào trong `SpendingSection`.
