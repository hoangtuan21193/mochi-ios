# Wallet — Design doc

Trạng thái: **đã triển khai** (2026-10-04) · Code: `Engine/Finance+Wallet.swift`, `Features/Accounts/AccountsView.swift`, `DesignSystem/DataDisplay.swift` (`NetWorthLine`) · Test: `WalletTests`, `NetWorthTests` · Canvas: `Wallet`, `WalletCards`, `WalletInvested`, `iPadWallet`, `FoldWallet`, `NetWorth`(+Dark)

## Context and motivation

Wallet là một cột dài: tiền, điểm, thẻ, trả góp, người, đầu tư, mỗi dòng chỉ tên và số. Không dòng nào nói tài khoản để làm gì, có thiếu không, phải chuyển tiền trước ngày nào. Canvas vẽ lại: net worth có đường nhỏ, chia 3 tab, mỗi dòng có một câu.

Goals:
- Mỗi tài khoản nói nó nhận gì (lương), trả gì (thẻ, trả góp), thiếu bao nhiêu vào ngày nào, chuyển trước ngày nào; marketplace nói rút về đâu, mất bao nhiêu, rút trước ngày nào.
- Mỗi thẻ: sao kê còn phải trả, ngày trừ, từ tài khoản nào, phần chưa lên sao kê.
- Mọi con số từ `Finance`, có test.

Non-goals (v1):
- Không có màn chi tiết tài khoản mới. Chạm vào dòng vẫn mở sheet sửa như cũ.
- Dark mode Wallet không có artboard riêng; dùng token như các màn khác.

## Nằm ở màn hình nào

| Con số / UI | Màn hình | Vì sao |
|---|---|---|
| Thiếu ở tài khoản nào, chuyển trước ngày nào | Wallet › Accounts (dòng tài khoản) | hiện tại; Home vẫn giữ câu "move ¥X from A to B" của thẻ sắp trả |
| Rút marketplace trước ngày nào | Wallet › Accounts | hiện tại |
| Sao kê thẻ, chưa lên sao kê | Wallet › Cards and plans | hiện tại |
| Đường net worth nhỏ | Wallet (đầu màn) | dài hạn; chart đầy đủ ở Net worth |

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** biểu đồ số dư (#3) — đường ở đây là net worth, không phải tiền mặt. Net worth "By type" bỏ (#35).
- **Tương thích lưu trữ:** không có field mới. Tab đang mở, khoảng thời gian của Net worth là `@AppStorage`.
- Dòng phụ của tài khoản dùng chính forecast của Home (`events`, `accountForecast`, `transfersNeeded`), nhìn 45 ngày tới, nên hai màn không bao giờ nói khác nhau.
- Snapshot mẫu của sổ demo được hạ cho khớp net worth thật của sổ, và nạp demo chụp luôn snapshot tháng này, để đường không đi lên trong khi dòng "since January" âm.

## Công thức

```swift
static func accountNotes(_ data: AppData, today: Date) -> [AccountNote]   // balance, incomes, pays, shortBy/shortOn, moveBy, withdrawBy/forDebit
static func cardLines(_ data: AppData, today: Date) -> [CardLine]         // statement (owedStatement), due, unbilled
static func installmentDebits(_ data: AppData, in: DateInterval) -> Int
static func netWorthSeries(_ data: AppData, _ range: NetWorthRange, today: Date) -> NetWorthSeries
```

## Acceptance criteria

- [x] Given JCB trả từ MUFG thiếu ¥65,200 ngày 13/10, then dòng MUFG nói "¥65,200 short on 13 Oct" và "move by 9 Oct" (`WalletTests`).
- [x] Given Mercari rút về SMBC 3 ngày làm việc, then "by 21 Oct for the 27th".
- [x] Given một snapshot, then Net worth không in số thay đổi (`NetWorthTests`).
