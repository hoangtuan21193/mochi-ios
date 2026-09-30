# Roadmap — Mochi thành app tài chính cá nhân đầy đủ

Ngày chốt danh sách: 2026-09-30 · Căn cứ: [research/2026-09-user-pains.md](research/2026-09-user-pains.md), [research/2026-09-market.md](research/2026-09-market.md) · Thiết kế: canvas "Mochi — Personal finance redesign".

Trạng thái: **danh sách đã chốt, thứ tự và phạm vi từng phase chưa chốt.**

## Định vị

Tài chính cá nhân cho người ở Nhật, **không cần sync ngân hàng**: nhập nhanh (chụp hoá đơn offline, vị trí, import CSV), biết chắc đủ tiền trả thẻ, và biết đồ mình sở hữu thật ra tốn bao nhiêu. Dữ liệu nằm trên máy người dùng.

## 16 tính năng đã chọn (cùng thiết kế đã có)

| Nhóm | Tính năng | Cỡ | Phụ thuộc |
|---|---|---|---|
| Nền | Model `Transaction` + phong cách mới (sáng / tối) | L | — |
| Nền | **Chống đếm đôi** thẻ ↔ 引き落とし ↔ item | M | Transaction |
| Nền | **Export đầy đủ** CSV + JSON, không giới hạn | S | Transaction |
| Nhập | Chụp hoá đơn offline (đã thiết kế) | L | Transaction |
| Nhập | Quick add theo vị trí (đã thiết kế) | M | Transaction |
| Nhập | **Import CSV PayPay + thẻ** | M | Transaction, chống đếm đôi |
| Nhập | **Rule tự gán category** (cửa hàng / địa điểm) | M | Transaction |
| Nhập | **Widget + Lock Screen** | S | Safe to spend |
| Nhập | **Check-in tuần 1 phút** | S | hàng chờ duyệt |
| Kế hoạch | **Budget theo kỳ lương** | M | Transaction, category |
| Kế hoạch | **Goals / quỹ cho khoản không đều** | M | budget |
| Kế hoạch | **Theo dõi subscription** | S | `Recurring` đang có |
| Kế hoạch | **Thông báo** (kỳ thẻ, thiếu tiền, chi lớn) | S | `paymentsDue` đang có |
| Khác biệt | **立替 / 割り勘** | M | Loan book đang có |
| Khác biệt | **Bảo hành + hoá đơn gắn với đồ** | S | ảnh hoá đơn |
| Khác biệt | **Đa tiền tệ theo giao dịch** | M | Transaction |
| Khác biệt | **Đầu tư nhập tay (NISA)** | S | net worth |
| Chia sẻ | **iCloud sync + chia sẻ vợ/chồng** | L | mọi model |
| Chia sẻ | **Trợ lý AI on-device** | M | Transaction, Foundation Models |

## Thứ tự đề xuất

| Phase | Nội dung | Vì sao đứng đây |
|---|---|---|
| **0 · Nền** | Transaction, phong cách mới, chống đếm đôi, export | mọi thứ khác dựng trên đây. Field `currency` và id dạng UUID có ngay từ đầu, để sau này đa tiền tệ và sync không phải đổi schema |
| **1 · Nhập nhanh** | scan, quick add, CSV PayPay/thẻ, rule, widget, check-in | pain số 1; không có phần này thì các phase sau không có dữ liệu |
| **2 · Kế hoạch** | budget kỳ lương, goals, subscription, thông báo | cần vài tuần dữ liệu thật mới có ý nghĩa |
| **3 · Khác biệt** | 立替, bảo hành, đa tiền tệ, NISA | nhỏ, độc lập, làm song song được |
| **4 · Chia sẻ & AI** | iCloud + chia sẻ, trợ lý AI | lớn nhất, rủi ro nhất; cần schema đã ổn định |

## Rủi ro đã biết

- **iCloud sync** đổi cách lưu trữ (một file JSON → CloudKit). Cần design doc riêng về migration và xung đột khi hai máy cùng sửa.
- **Trợ lý AI** chỉ chạy trên iPhone 15 Pro trở lên có bật Apple Intelligence. Nó phải trả lời từ số liệu của `Finance`, không tự tính. Người dùng còn tin AI thấp (3% tin "rất nhiều").
- **Đa tiền tệ** chạm vào 4 con số: phải quyết định quy đổi theo tỉ giá nào, ngày nào. Khoản vay bằng đồng hiện nằm ngoài cả 4 con số.
- **16 tính năng cho một người làm:** mỗi phase phải ra được bản dùng được, không để tới cuối mới xong hết.

## Việc tiếp theo

1. Chốt thứ tự và phạm vi từng phase (planboard).
2. Ghi các quyết định mới vào `decisions.md`: dark mode, màn hình Transactions, biểu đồ ở Spending và Net worth, mua đồ không tính vào Spending.
3. Viết design doc cho Phase 0: `docs/design/transactions.md`.
