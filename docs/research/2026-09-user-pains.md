# Người dùng app tài chính đau ở đâu, muốn gì

Ngày: 2026-09-30 · Nguồn: khảo sát, trang hỗ trợ của app, review App Store, bảng feature request (GitHub của Actual và Firefly III, bảng của Lunch Money, changelog của Monarch). **(U)** = chưa xác minh (chỉ thấy qua snippet hoặc nguồn thứ cấp). Không đọc trực tiếp được Reddit.

## Kết luận

1. **Bỏ app vì nhập liệu mệt** là vấn đề số 1, cả ở Nhật lẫn nước ngoài. Tính năng nào giảm thao tác đáng giá hơn mọi tính năng phân tích.
2. **Sync ngân hàng là con dao hai lưỡi:** mọi người muốn có nó nhất, nhưng cũng than phiền về nó nhất (hỏng kết nối, phải liên kết lại, đếm đôi). Mochi không sync nên phải thắng bằng cách **nhập tay thật nhanh cộng import file**.
3. **Mất dữ liệu khi app đóng cửa** là chuyện có thật: LINE家計簿 (2021, không có export), Mint (2024, export bị cắt ở 10,000 dòng). "Dữ liệu là của bạn" là một lý do để chọn app.
4. **Ba khoảng trống gần như không ai làm tốt:** 立替 / chia tiền với bạn bè, chu kỳ thẻ cộng 分割, đồ đạc tính theo giá bán lại. Hai cái sau Mochi đã có.

## Pain — ở Nhật

| # | Vấn đề | Bằng chứng |
|---|---|---|
| 1 | **Nhập tay mệt** | MF 2015 (n=3,302): hơn 70% nữ, hơn 50% nam từng bỏ 家計簿, lý do số 1 là 面倒 · MMD 2021 (n=443): 入力が面倒 34.5%, 続けるのが難しい 22.6% |
| 2 | Liên kết lỗi, phải liên kết lại, báo thành công mà không lấy được dữ liệu | Appliv 2023 (n=615): ~25% có dịch vụ không liên kết được · review MF ME trên App Store |
| 3 | Bản miễn phí bị cắt, tăng giá | MF ME cắt liên kết miễn phí từ 10 xuống 4 (2022-12) · tăng giá 2025-08 · Moneytree bản miễn phí chỉ giữ 12 tháng (2023) |
| 4 | **Đếm đôi**: thẻ + 引き落とし + lịch sử mua hàng | MF và Zaim đều có trang FAQ riêng cho việc này |
| 5 | **PayPay không có API** (70M+ người dùng) | chỉ có CSV nhập tay; MF hỗ trợ từ 2025-07 |
| 6 | Đọc hoá đơn sai | なるほどWiFi 2021 (n=208): 11.8% · Zaim có FAQ "đọc không chính xác", giờ bán thêm gói AI OCR trả phí |
| 7 | App đóng cửa, không có export | LINE家計簿 2021-11, docomo スマー簿 2024-01 |
| 8 | Vợ chồng chung tiền | MMD: 24.6% đang dùng chung, 13.5% muốn dùng chung · OsidOri 2019: tiền là nguyên nhân cãi nhau số 1 |

## Pain — nước ngoài

| # | Vấn đề | Bằng chứng |
|---|---|---|
| 1 | Tốn thời gian | Debt.com 2026 (n≈1,051): người không lập budget vì "tốn thời gian" tăng từ 16% lên 34%; giấy bút 37% > bảng tính 27% > app 22% |
| 2 | Sync hỏng | trang hỗ trợ của Monarch, Emma (phải liên kết lại mỗi 90 ngày), Trustpilot của BudgetBakers |
| 3 | Giao dịch trùng | YNAB và BudgetBakers có trang hỗ trợ riêng |
| 4 | Giá tăng, huỷ gói khó | YNAB $109/năm; forecast của Monarch nằm ở gói $199; Copilot tính tiền theo đầu người |
| 5 | Mất dữ liệu, bị khoá dữ liệu | Mint đóng 2024-03 |
| 6 | Riêng tư | Incogni 2023: 60% app budget trên Android chia sẻ dữ liệu cho bên thứ ba; tracker quảng cáo chạy trong Monarch (2024) |
| 7 | Quá phức tạp, gây cảm giác tội lỗi | YNAB mất 2–4 tuần mới quen (U) |

## Tính năng được xin nhiều nhất

| Tính năng | Bằng chứng (👍 trên GitHub / bảng request) |
|---|---|
| **Goals / quỹ cho khoản không đều** | Actual #496 **498** · Monarch: "một trong những tính năng được xin nhiều nhất" |
| Nhận diện chuyển khoản, khớp giao dịch | Actual #1628 **379**, #669 **121** |
| Đa tiền tệ | Actual #1132 **342** |
| Budget linh hoạt, ngày bắt đầu tháng tuỳ chọn | Lunch Money zero-based **330** · Actual #975 (đổi ngày đầu tháng) **113** |
| Chia sẻ trong gia đình | Actual #524 **315** · Monarch làm 2025-10 |
| Hoá đơn / đính kèm | Actual #530 **206** |
| Báo cáo, export | Actual #730 **163** |
| **Dự báo số dư** | Actual #517 **140** · Simplifi được Wirecutter chọn vì có projection |
| 2FA / riêng tư | Actual #2042 **182** |
| Rule tự gán category | Actual #500 **101** · gợi ý category theo GPS #1511 **63** |
| Subscription | C+R 2022 (n=1,000): 42% quên mình vẫn đang trả tiền một dịch vụ không còn dùng |
| **立替 / chia tiền** | không app lớn nào làm sẵn; ai cũng phải nối với Splitwise |
| **分割 / chu kỳ thẻ** | chỉ có một issue đang mở trên Firefly (#10073) |
| Trợ lý AI | Gallup 2026: ~1/5 người đã dùng, nhưng chỉ 3% tin "rất nhiều" |

## Đối chiếu với Mochi

| Nhu cầu | Mochi hiện có / đã thiết kế | Còn thiếu |
|---|---|---|
| Nhập nhanh | thiết kế: OCR offline, quick add theo vị trí, Apple Pay qua Shortcuts | import CSV của PayPay và thẻ; rule |
| Dự báo | `paymentsDue`, `shortfall`, Safe to spend | — |
| Chu kỳ thẻ + 分割 | có đủ | — |
| Đồ theo giá bán lại | có + thiết kế chi phí thật mỗi tháng | — |
| Chống đếm đôi | có khớp trùng khi import item | khớp giao dịch thẻ với 引き落とし |
| Export | export book JSON | export giao dịch CSV |
| Riêng tư | không tài khoản, không mạng, backup cục bộ | — |
| Goals, budget, subscription, 立替, chia sẻ, đa tiền tệ theo giao dịch | chưa có | — |

## Nguồn chính

- MF 2015: https://corp.moneyforward.com/news/release/corp/20150529_pfm_research/
- MMD 2021: https://mmdlabo.jp/investigation/detail_1975.html
- Appliv 2023: https://prtimes.jp/main/html/rd/p/000000330.000055900.html
- MF cắt bản miễn phí: https://corp.moneyforward.com/news/info/20221107-mf-press/
- PayPay CSV: https://www.itmedia.co.jp/news/articles/2510/31/news087.html
- LINE家計簿 đóng cửa: https://nlab.itmedia.co.jp/cont/articles/3325844/
- OsidOri 2019: https://prtimes.jp/main/html/rd/p/000000003.000047164.html
- Debt.com 2026: https://www.debt.com/research/best-way-to-budget/
- Incogni 2023: https://blog.incogni.com/budgeting-apps-research/
- Mint đóng cửa: https://en.wikipedia.org/wiki/Intuit_Mint
- Actual issues: https://github.com/actualbudget/actual/issues
- Lunch Money: https://feedback.lunchmoney.app/?sort=top
- Monarch: https://www.monarch.com/whats-new
- C+R subscriptions: https://www.crresearch.com/blog/subscription-service-statistics-and-costs/
- Gallup AI: https://fortune.com/2026/08/08/financial-advisers-trust-ai-usage-gap-gallup/
