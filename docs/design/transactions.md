# Sổ giao dịch (ledger) — Design doc

Trạng thái: **đã triển khai** (2026-09-30, nhánh `redesign/phase-0`) · Code: `Models/Transaction.swift`, `Engine/Finance+Ledger.swift`, `Store/Store+Ledger.swift` · Test: `LedgerTests`

## Context and motivation

Số dư trước đây gõ tay, item không di chuyển tiền (decisions #1). Muốn làm app tài chính cho nhiều người thì phải biết tiền đi đâu — Monarch, Zaim, Money Forward đều là ledger (decisions #12).

Goals:
- Mỗi khoản chi / thu / chuyển là một dòng người dùng sửa được.
- Số dư, chi tiêu, chu kỳ thẻ tính từ các dòng đó.
- Sổ cũ mở ra **không đổi con số nào**.

Non-goals (v1):
- Sync ngân hàng. Chia sổ theo nhiều tiền tệ gốc (giao dịch ngoại tệ quy về yên theo tỉ giá gõ).

## Nằm ở màn hình nào

| Con số / UI | Màn hình | Vì sao |
|---|---|---|
| Danh sách, To review | Transactions | hiện tại |
| Chi theo category, 6 tháng | Transactions → Spending | quá khứ |
| Số dư từng tài khoản | Home → Accounts | hiện tại |
| Budget kỳ lương | Plan | kế hoạch |

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** màn hình Activity (#6) — khác: đó là nhật ký thao tác, cái này là sổ người dùng sửa. Biểu đồ số dư (#3) vẫn cấm.
- **Tương thích lưu trữ:** mọi field mới Optional hoặc `decodeIfPresent`; `schemaVersion` 2.

| Lựa chọn | Được | Mất |
|---|---|---|
| Giữ số dư gõ tay, thêm chi tiêu bên cạnh | không đụng số cũ | hai sự thật cho một số dư |
| **Số dư = số mở + Σ giao dịch (chọn)** | một sự thật; gõ lại số dư vẫn được (adjustment) | cần ranh giới `ledgerStart` cho sổ cũ |

## High-level behavior

1. Lần đầu mở bản mới: `startLedgerIfNeeded` đặt `ledgerStart = hôm nay`, `Wallet.balance` hiện tại thành số mở.
2. Mỗi giao dịch có `kind`:

| Kind | Ảnh hưởng | Là chi tiêu? |
|---|---|---|
| spend | − tài khoản | có (`myShare` nếu chia) |
| income | + tài khoản | không |
| move | − nguồn, + đích (thẻ: trả nợ) | không |
| refund | + tài khoản | trừ lại chi tiêu |
| asset | − tài khoản, gắn `itemID` | **không** — hiện riêng ở Spending |
| adjustment | ± chênh lệch khi gõ lại số dư | không |

3. Lịch tự ghi (`postDueSchedules`, lúc mở app và quay lại): lương, bill, trả thẻ vào ngày due từ `payFrom`, trả góp, tích luỹ đầu tư. Khoá `scheduleID@yyyy-MM-dd` → chạy lại không ghi đôi.
4. Thẻ: `debt` gõ tay là mỏ neo tại `statementDate`. Qua closing sau mỏ neo → sao kê = Σ charge trong kỳ. Move vào thẻ = đã trả.
5. Item mua mới → `bookPurchase` tạo giao dịch asset; sửa giá → `syncPurchase`; xoá item → xoá giao dịch gắn; bán → income vào tài khoản chọn; bỏ bán → xoá income đó.
6. Giao dịch trước `ledgerStart` bị bỏ qua khi tính số dư (số mở đã chứa nó); bill Every month vẫn đếm theo cách cũ cho ngày trước `ledgerStart`.

## Công thức

```swift
static func balance(of account: String, _ data: AppData) -> Int
// = Wallet.balance + Σ effect(on: account) của giao dịch từ ledgerStart
static func spending(_ data: AppData, in interval: DateInterval) -> Int
// = Σ spendingAmount (spend, refund); không move, asset, income, adjustment
```

- **Không** đếm: điểm; mua belonging trong Spending; charge của item đã có giao dịch gắn (tránh đếm đôi trên thẻ).

## Dữ liệu lưu trữ

| Field | Kiểu | Mặc định | Ở |
|---|---|---|---|
| `transactions`, `spendingCategories`, `budgets`, `goals`, `rules`, `investments` | `[T]?` | `nil` | `AppData` |
| `ledgerStart`, `postedThrough`, `lastCheckin` | `Date?` | `nil` | `AppData` |
| `placeName` | `String?` | `nil` | `Transaction` |
| `lookUpPlaceNames` | `Bool?` | `nil` (= bật) | `AppData` |
| `payFrom`, `statementDate`, `last4` | `String?` / `Date?` | `nil` | `CreditCard` |
| `payFrom` | `String?` | `nil` | `Installment` |
| `valueHistory`, `warrantyUntil`, `receiptFile`, `boughtToResell` | Optional | `nil` | `Item` |

## Ledger & undo

- Mọi thao tác trên vẫn `Store.log(LedgerEntry)`.
- Xoá giao dịch split → xoá cả khoản cho vay mang `splitID`. Xoá item → xoá giao dịch asset/income gắn.

## Error handling and UX

| Loại | Ví dụ | Xử lý |
|---|---|---|
| Apple Pay / scan không chắc | category trống | `needsReview`, badge trên tab |
| Sổ cũ | chưa có giao dịch | không đổi số; Home có thẻ "bắt đầu" |
| Gõ lại số dư | ngân hàng nói khác | adjustment, copy nói "the difference is booked as a correction" |

## Testing approach

- Unit: `LedgerTests` (21), `ReceiptParserTests`, `StatementParserTests`; `FinanceTests` giữ nguyên cho sổ cũ.
- Manual: `-demo 1` — sổ mẫu bắt đầu ledger 70 ngày trước.

## Acceptance criteria

- [x] Given sổ version 1, when mở bản mới, then mọi con số giữ nguyên (`switchingToTheLedgerChangesNoFigure`).
- [x] Given chi bằng thẻ, then nợ tính một lần và là chi tiêu (`spendingOnACardIsOwedOnceAndCountsAsSpending`).
- [x] Given mua belonging bằng thẻ, then nợ một lần và **không** là chi tiêu.
- [x] Given trả sao kê, then cash và nợ cùng giảm, net worth không đổi.
- [x] Given lịch chạy hai lần, then lần hai không thêm gì.
- [x] Given bill đã ghi, then không đếm lại từ danh sách Every month.
- [x] Given until payday, then lương ngày đó **không** tính.
