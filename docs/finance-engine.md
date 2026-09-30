# Finance engine

`Mochi/Engine/Finance.swift` — `enum Finance`, toàn hàm thuần `(AppData, Date) → giá trị`. Mọi con số trên màn hình đi ra từ đây; `Store` chỉ bọc lại, view chỉ đọc.

## Bốn con số — không bao giờ gộp

| Con số | Hàm | Công thức | Ở đâu |
|---|---|---|---|
| **Cash now** | `cashNow` | Σ `Wallet.balance` (không điểm) | Wallet |
| **Safe to spend** | `safeToSpend(_:horizon:)` | cash + thu chắc chắn trước horizon − thẻ − trả góp − bill trả bằng tiền mặt trước horizon − `safetyBuffer` | Overview (headline) |
| **Monthly cash flow** | `monthlyCashFlow(_:month:)` | lương + lãi bán đã chốt − bill − living estimate − phí trả góp; + Δcash / Δnet worth thật từ snapshot | **chưa màn hình nào** — xem [decisions.md](decisions.md) |
| **Net worth** | `netWorth` | cash + stock theo giá bán + khoản cho vay (yên) − sao kê thẻ − unbilled − gốc trả góp − khoản vay (yên) | Overview (tile nhỏ) |

- Khoản vay bằng **đồng (VND) nằm ngoài cả bốn**.
- Recurring tương lai (tiền nhà năm sau) **không** là nợ.

## Item & bán hàng

| Hàm | Ý nghĩa |
|---|---|
| `shipping(item)` | `item.shippingFee ?? defaultShippingFee` |
| `netProceeds` | kênh tiền: giá × (1 − phí%) − ship. Kênh điểm: giá × (1 + bonus%), ship tính riêng là tiền ra |
| `expectedProfit` | kênh tiền: net − giá mua. Kênh điểm: −giá mua − ship (lỗ tiền mặt là thật, điểm báo cáo riêng) |
| `realizedProfit` | `sale.net − buyPrice`; `nil` khi chưa bán |
| `liquidation` | Σ net của item **for sale** (không Keeping, không kênh điểm) = "sell-all proceeds" |
| `pointsFromSelling` | điểm nếu bán hết qua kênh điểm — cạnh `liquidation`, không trong nó |
| `unrealizedProfit` | Σ lãi dự kiến trên stock for sale |

### Điểm — báo cáo, không cộng

- `pointsEarned(_:in:)`: điểm tính vào **ngày mua**. `pointsOnStock`: điểm trên stock chưa bán.
- Hiện cạnh số tiền ở item, Inventory, Stats. Không bao giờ vào cash, lãi, net worth.
- Ví dụ: ống kính ¥785,266 hoàn ¥94,328 điểm có thể lỗ ¥45,266 tiền mặt mà vẫn là giao dịch tốt.

## Chu kỳ thẻ — `cycle(for:)`

Trả về `CardCycle`. Chi tiết và lý do: [design/card-cycle.md](design/card-cycle.md).

| Trường | Khoảng |
|---|---|
| `statementStockCost` / `statementBills` | (previousClosing, lastClosing] — nằm trong `debt` đã gõ |
| `unbilledStockCost` / `unbilledBills` | (lastClosing, today] — chưa có sao kê |
| `comingBills` | (today, nextClosing] |
| `livingEstimate` | max(0, debt − stock trong sao kê − bill trong sao kê) = "mọi thứ khác" |
| `projectedNext` | unbilled + comingBills + livingEstimate |
| `owedStatement` | `debt` nếu due day chưa qua, ngược lại 0 |

- `closingDay == nil` → sao kê **đóng hôm nay**: cả hai cửa sổ unbilled rỗng.
- `unbilledDue` luôn sau `statementDue` một kỳ, không bao giờ cùng ngày.
- `cardDebt` = Σ `owedStatement`; `unbilledCharges` = Σ `unbilled`.

## Trả góp (分割)

- Nhập theo giấy xác nhận: 分割支払回数, 初回お支払金額, 2回目以降お支払金額, お支払期間, 毎月のお支払日.
- `InstallmentSchedule` → `principal = first + monthly × (n − 1)`; đọc ngược cho form sửa.
- Số kỳ đã trả **đếm từ ngày**, không tick tay.

| Hàm | Ý nghĩa |
|---|---|
| `installmentRemaining` | tổng còn phải trả, gồm phí — tiền sẽ rời ngân hàng |
| `installmentPrincipal` | remaining − phí chưa phát sinh — vào net worth |
| `feePerPayment` | `feeTotal / months` — phần chi phí trong mỗi kỳ (cash flow) |

Mỗi kỳ trả là một event có ngày trong dự báo — tổng không bao giờ coi là đến hạn một lần.

## Dự báo

| Hàm | Trả về |
|---|---|
| `events(_:from:to:)` | mọi event tiền trong (today, end]: `income`, `receivable`, `card`, `installment`, `bill`, `loan` |
| `paymentsDue(_:to:)` | một `DueDay` mỗi ngày: tổng, tên, `balanceAfter`, `shortfall` |
| `shortfall(_:)` | (số tiền ngày tệ nhất, ngày thiếu đầu tiên) hoặc `nil` |
| `projectedCashBalance` | cùng vòng đi đó — **không đưa lên màn hình** |
| `upcomingLines` | event gom nhóm theo thẻ / kế hoạch, vẫn cộng đúng |

- Bill trả bằng thẻ **không** xuất hiện vào ngày của nó; nó nằm trong event thẻ ở due day.
- `Horizon`: `.days(30)` · `.days(60)` · `.payday` (lương kế tiếp; không có lương → 30 ngày). Lưu `"30d"` / `"60d"` / `"payday"`.

## Kỳ & lịch sử

- `Period`: `.all` · `.year(y)` · `.month(y, m)` — dùng chung cho Inventory và Stats.
- `summary(for:)`: bán ra trong kỳ, không gì khác.
- `items(_:status:period:sort:search:)`: **nơi duy nhất** lọc và sắp xếp list.
- `matches(_:search:)`: bám theo số đã gõ, tha nửa số chữ — "200mmf2.8" tìm ra "200 f2.8".
- `history(months:)`: doanh số mọi tháng; số dư chỉ ở tháng có snapshot.
- `snapshot`: `CashSnapshot` (cash, cardDebt, installmentDebt, netWorth).

## Thêm một công thức

1. Viết hàm trong `Finance`, chỉ nhận `AppData` + `Date`.
2. Viết test trong `FinanceTests` với `today` cố định (6/9/2026 trong book mẫu test).
3. Test cả case âm (thứ **không** được đếm).
4. Thêm property / hàm trong `Store`.
5. View đọc property đó.
6. Rule mới → một dòng trong `CLAUDE.md` mục Domain facts.
