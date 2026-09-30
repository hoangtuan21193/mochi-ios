# Nhật ký quyết định

ADR-lite: mỗi mục là một quyết định đã chốt, lý do, và hệ quả. **Agent đọc file này trước khi đề xuất** — nhiều thứ ở đây đã được thử và bỏ.

Thêm mục mới bằng [templates/decision.md](templates/decision.md). Không xoá mục cũ; quyết định bị đảo thì thêm mục mới và đánh dấu mục cũ "Thay bởi #N".

## Tóm tắt

| # | Quyết định | Trạng thái |
|---|---|---|
| 1 | Item không bao giờ di chuyển tiền | Chốt |
| 2 | Bốn con số, không gộp thành một | Chốt |
| 3 | Không biểu đồ số dư tiền mặt | **Đã bỏ** (2 lần) |
| 4 | Thẻ không có closing day: sao kê đóng hôm nay | Chốt |
| 5 | Backup cục bộ, không iCloud | Chốt |
| 6 | Ledger ghi, không hiện | Chốt |
| 7 | Bỏ card "Richer or poorer?" khỏi Overview | **Đã bỏ** |
| 8 | Năm tab, không hơn | Chốt |
| 9 | Chỉ light mode | Chốt |
| 10 | Purchase key = Item + 購入日 + Buy on Market | Chốt |
| 11 | Fresh install hoàn toàn rỗng | Chốt |

## Đã bỏ — đừng đưa lại

Muốn đưa lại một thứ dưới đây → dừng, hỏi người, viết design doc giải thích điều gì đã đổi.

- **Biểu đồ số dư tiền mặt** trên Overview — thử 2 lần, bỏ 2 lần (#3).
- **Card "Richer or poorer?"** + `CashFlowSheet` + `Store.thisMonth` (#7).
- **Card "Sell these to stay above the reserve"** — gợi ý bán item để bù thiếu.
- **Màn hình Activity** (ledger) — bị coi là rối (#6).
- **Toggle iCloud backup** — chưa từng ghi gì (#5).
- **`Store.realCash`, `saleContribution`** — thay bằng 4 con số (#2).
- **Lấy tháng dương lịch thay cho closing day** khi thẻ không có closing day — đếm đôi bill trả thẻ (#4).
- Cost basis, expected margin, điểm, stock trên thẻ ở Overview — là phần tính nháp, đã có chỗ khác.

## Chi tiết

### 1. Item không di chuyển tiền
- **Bối cảnh:** sổ có nhiều khoản chi không phải hàng bán lại; tự động trừ ví khi mua sẽ lệch số dư ngân hàng.
- **Quyết định:** thêm / sửa / bán / import item không đụng ví, điểm, nợ thẻ. Số dư gõ tay từ ngân hàng và sao kê.
- **Hệ quả:** `Store.purchases(on:in:)` liệt kê item quẹt thẻ trong tháng để đối chiếu với sao kê.

### 2. Bốn con số
- **Bối cảnh:** một con số "tiền thật" trộn cash, nợ, stock và bị hiểu sai.
- **Quyết định:** `cashNow`, `safeToSpend`, `monthlyCashFlow`, `netWorth` tách hẳn. Khoản vay đồng nằm ngoài cả bốn.
- **Hệ quả:** mỗi con số một hàm, một bộ test.

### 3. Không biểu đồ số dư
- **Bối cảnh:** biểu đồ chỉ trả lời "có thiếu không" nếu người đọc tự trừ; trông như đường tài sản nhưng di chuyển vì lý do không phải tài sản (trả thẻ làm nó giảm mà net worth không đổi; bán lỗ làm nó tăng mà bạn nghèo đi).
- **Quyết định:** Overview trả lời bằng chữ: `paymentsDue` (một dòng mỗi ngày + số dư chạy) và `shortfall`.
- **Hệ quả:** `projectedCashBalance` giữ lại vì `paymentsDue` và Stats dùng chung vòng đi; không đưa lên màn hình.

### 4. Thẻ không closing day
- Xem [design/card-cycle.md](design/card-cycle.md).

### 5. Backup cục bộ
- Xem [design/local-backups.md](design/local-backups.md).

### 6. Ledger ghi, không hiện
- **Bối cảnh:** màn hình Activity bị bỏ vì rối.
- **Quyết định:** vẫn ghi `LedgerEntry` mỗi lần tiền di chuyển (mua/bán là kind `"x"`).
- **Hệ quả:** là bản ghi duy nhất *vì sao* số dư gõ tay đổi, không dựng lại được sau này.

### 7. Bỏ "Richer or poorer?"
- **Bối cảnh:** trước khi có snapshot thứ hai, con số duy nhất hiện được là `planned` — một dự báo — và bị đọc như kết quả thật.
- **Quyết định:** chuyển động thật tháng-qua-tháng thuộc Stats, vẽ từ snapshot (một lần đọc là một điểm, thấy rõ).
- **Hệ quả:** `monthlyCashFlow` và test giữ lại cho màn hình nào hiện nó sau.

### 8. Năm tab
- **Bối cảnh:** iOS gập tab thứ 6 vào "More", chôn Activity và Settings sau một lần chạm.
- **Quyết định:** Overview · Inventory · Stats · Wallet · Settings. Loan book mở từ Wallet.

### 9. Light only
- **Bối cảnh:** palette Organic một giọng (nền kem, chữ mực), không có bản tối. Dark mode làm chữ trắng trên card kem.
- **Quyết định:** `.preferredColorScheme(.light)` + pin interface style.

### 10. Purchase key
- Xem [design/sheet-import.md](design/sheet-import.md).

### 11. Fresh install rỗng
- **Bối cảnh:** người bán Mercari và người trade-in MapCamera cần channel khác nhau, phí khác nhau; list điền sẵn là 4 thứ phải xoá trước thứ thật đầu tiên.
- **Quyết định:** `AppData.empty` không có gì. Settings giải thích channel và đưa nút +.
