# Product brief

## Vấn đề

Người sống ở Nhật mua đồ (thường bằng thẻ tín dụng, có khi trả góp 0%) rồi bán lại trên Mercari, Rakuma, MapCamera… Tiền bị chia ra nhiều chỗ — ngân hàng, số dư marketplace, điểm PayPay/Rakuten, nợ thẻ, kế hoạch trả góp — nên câu hỏi đơn giản "tháng này có trả nổi không?" không có ai trả lời.

Google Sheet cũ ghi được từng món, nhưng không biết thẻ nào đóng sổ ngày nào, không tách điểm khỏi tiền, không dự báo.

## Người dùng

- Một người (hoặc một hộ), ở Nhật, tiền yên; có khoản vay/cho vay bằng đồng với người thân.
- Mua–bán vài chục món mỗi năm; mỗi món vài chục nghìn tới vài trăm nghìn yên.
- Tự gõ số dư từ ngân hàng và sao kê thẻ — app không kết nối ngân hàng.

## Goals

- Trả lời **"Tôi có trả nổi không?"** bằng chữ: ngày nào thiếu, thiếu bao nhiêu.
- Tách **4 con số** không bao giờ gộp: tiền mặt, an toàn để tiêu, dòng tiền tháng, tài sản ròng.
- Biết từng món: giá mua, giá bán ước tính, lãi dự kiến, điểm được hoàn — và lãi thật khi đã bán.
- Nhập được Google Sheet cũ mà không nhân đôi dữ liệu.
- Không bao giờ mất sổ: backup cục bộ mỗi ngày, book cũ luôn mở được.

## Non-goals

- Kết nối ngân hàng / thẻ / marketplace tự động.
- Đồng bộ nhiều thiết bị, iCloud.
- Phân loại chi tiêu hằng ngày (app ước lượng "mọi thứ khác" từ sao kê, không bắt gõ).
- Dark mode.
- Gợi ý đầu tư.
- Đặt tên loại hàng trong UI — sổ chỉ chứa *item*, category là của người dùng.

## Nguyên tắc sản phẩm

| Nguyên tắc | Hệ quả |
|---|---|
| **Item không di chuyển tiền** | Thêm / bán / nhập item không đụng ví, điểm, nợ thẻ. Số dư gõ tay từ ngân hàng. |
| **Điểm được báo cáo, không cộng vào** | Điểm hiện bên cạnh số tiền, không bao giờ vào cash, lãi hay tài sản ròng. |
| **Recurring là cam kết, không phải nợ** | Tiền nhà năm sau không nằm trong tài sản ròng. |
| **Nói điều sẽ xảy ra trước nút bấm** | Form kết thúc bằng dòng preview; thao tác phá huỷ qua alert. |
| **Control chỉ khi có lựa chọn** | Không menu một mục; nói kết quả bằng chữ. |

## 5 màn hình — chia theo thì

Mỗi con số sống ở **đúng một** màn hình.

| Tab | Thì | Trả lời | Nội dung chính |
|---|---|---|---|
| **Overview** | tương lai | "Bây giờ thế nào, và từ giờ tới horizon?" | Safe to spend (headline), lịch thanh toán từng ngày + shortfall, sell-all proceeds, lãi đã chốt tháng này, tile tài sản ròng |
| **Inventory** | hiện tại | "Tôi đang giữ gì?" | lọc (status / kỳ), 9 kiểu sắp xếp, tìm kiếm, chi tiết item, category, import, export |
| **Stats** | quá khứ | "Tháng 7 / năm 2025 tôi bán ra sao?" | tổng kết theo `Finance.Period`, lịch sử theo snapshot |
| **Wallet** | hiện tại | "Tiền nằm đâu, nợ ai?" | Cash & wallets, Point wallets, Credit card debt, Instalment plans, Every month, Loan book |
| **Settings** | — | cấu hình | Sales channels, Owners, Safe to spend (buffer, horizon), Selling, Backups, Data, ngôn ngữ, tiền tệ |

"Lãi tháng này" là của Overview; "lãi tháng 7" là của Stats — không lặp.

## Thuật ngữ

| Từ | Nghĩa trong Mochi |
|---|---|
| **Book** | toàn bộ dữ liệu, một file JSON (`AppData`) |
| **Wallet** | tiền thật: ngân hàng, số dư marketplace, tiền giấy |
| **Point wallet** | điểm (PayPay, Rakuten…) — không bao giờ là tiền |
| **Card debt** | số sao kê kỳ gần nhất, gõ tay |
| **Unbilled** | đã quẹt thẻ nhưng chưa vào sao kê |
| **Closing day** | ngày thẻ chốt sổ (締め日) |
| **Instalment** | kế hoạch trả góp (分割), thường 0% |
| **Recurring** | lương, tiền nhà, subscription — số tiền + ngày + trả bằng ví/thẻ nào |
| **Channel** | nơi bán: phí % (tiền) hoặc bonus % (điểm) |
| **Keeping** | item giữ lại dùng, loại khỏi mọi dự báo bán |
| **Horizon** | Safe to spend nhìn tới đâu: 30 ngày, 60 ngày, hoặc ngày lương |
| **Safety buffer** | tiền cố ý giữ lại, trừ khỏi Safe to spend |
| **Snapshot** | ảnh chụp cash + tài sản ròng mỗi tháng — lịch sử duy nhất |

## Ngôn ngữ & tiền tệ

- UI nguồn tiếng Anh; tiếng Việt và tiếng Nhật qua `Localizable.xcstrings`.
- Đổi ngôn ngữ có hiệu lực lần mở app sau.
- Tiền tệ hiển thị đổi được; khoản vay có thể bằng đồng (VND) và **không** vào 4 con số.
