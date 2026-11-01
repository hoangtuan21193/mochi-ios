# Profit — Design doc

Trạng thái: **đã triển khai** · Code: `Finance.profitByMonth` / `extremeTrades` / `saleYears` (Finance+Accounts.swift), `Store.profitThisMonth`, `Features/Inventory/ProfitView.swift`, `ProfitColumns` · Test: `ProfitByMonthTests` · Quyết định: #38

## Context and motivation

Ô "Profit this year" chỉ cho một con số cả năm; người dùng mua bán ~100 món/năm muốn thấy tháng này lời bao nhiêu, và cả năm đi lên xuống thế nào, món nào lời/lỗ nhất (comment trên canvas, 2026-10-12).

Goals:
- Tháng này lời bao nhiêu, một cái nhìn trên Belongings và Home.
- Một chạm ra cả năm theo tháng, có biểu đồ, có món lời/lỗ nhất.

Non-goals (v1):
- Lời theo kênh bán, theo danh mục.
- Bấm một tháng để lọc Belongings › Sold (Sold đã có chọn tháng).
- Theo kỳ lương.

## Nằm ở màn hình nào

| Con số / UI | Màn hình | Vì sao |
|---|---|---|
| Profit this month | Belongings, Home (ô) | quá khứ gần, người dùng chọn giữ cả hai |
| Lời năm, theo tháng, món lời/lỗ nhất | Profit (đẩy từ ô) | quá khứ |

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** #14 (Stats gộp vào Belongings, biểu đồ chỉ ở Spending/Net worth) — sửa bởi #38. #3 không đụng: đây là kết quả bán, không phải số dư.
- **Tương thích lưu trữ:** không có field mới.
- Lời = `Finance.trade` (tiền + điểm, #27); phần tiền luôn ở cạnh.
- Tháng của một lần bán = `SaleRecord.date`. Sổ làm lại từ Google Sheet có ngày bán là ngày 1 của tháng tích sold.

## Công thức

```swift
static func profitByMonth(_ data: AppData, year: Int) -> [MonthProfit]   // 12 tháng, tháng trống = 0
static func extremeTrades(_ data: AppData, year: Int, count: Int = 3) -> (best: [ItemTrade], worst: [ItemTrade])
static func saleYears(_ data: AppData, today: Date) -> [Int]             // năm có bán + năm nay
```

- Tổng 12 tháng = `profitWithPoints(.year)` (test giữ).
- Hoà vốn không vào lời nhất hay lỗ nhất.

## Acceptance criteria

- [x] Ô "Profit this month" trên Belongings và Home mở màn Profit.
- [x] Biểu đồ: lời xanh có phần điểm, lỗ đỏ dưới đường 0, tháng trống là đường; sáng và tối phân biệt được tiền/điểm.
- [x] ◀ ▶ chỉ qua các năm có bán.
- [x] Món lời/lỗ nhất mở trang của món đó.
