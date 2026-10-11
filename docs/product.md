# Product brief

Câu chuyện người dùng và các câu hỏi app phải trả lời: [why.md](why.md). File này là bản tóm tắt cho người làm.

## Vấn đề

Người sống ở Nhật mua đồ (thường bằng thẻ tín dụng, có khi trả góp 0%) rồi bán lại trên Mercari, Rakuma, MapCamera… Tiền bị chia ra nhiều chỗ — ngân hàng, số dư marketplace, điểm PayPay/Rakuten, nợ thẻ, kế hoạch trả góp — nên câu hỏi đơn giản "tháng này có trả nổi không?" không có ai trả lời.

Google Sheet cũ ghi được từng món, nhưng không biết thẻ nào đóng sổ ngày nào, không tách điểm khỏi tiền, không dự báo.

## Người dùng

- Một hộ (vợ chồng, chung một sổ), ở Nhật, tiền yên; có khoản vay/cho vay bằng đồng với người thân. Sau này lên App Store cho người ở nước khác: nơi bán, phí, tiền tệ đều do người dùng cài.
- Hai ngân hàng trở lên, nhiều thẻ trừ vào những ngân hàng khác nhau; chuyển tiền giữa tài khoản để thẻ trừ được.
- Mua–bán khoảng 100 món mỗi năm, mỗi món 10–30 man; dùng một thời gian rồi bán.
- Tự gõ số dư từ ngân hàng và sao kê thẻ — app không kết nối ngân hàng.

## Goals

- Trả lời **"Tôi có trả nổi không?"** bằng chữ: ngày nào thiếu, thiếu bao nhiêu, **ở tài khoản nào**, phải chuyển bao nhiêu từ đâu.
- Tách **4 con số** không bao giờ gộp: tiền mặt, an toàn để tiêu, dòng tiền tháng, tài sản ròng.
- Biết từng món: giá mua, giá bán ước tính, lời/lỗ nếu bán bây giờ (tính cả phí và điểm) — và lời thật khi đã bán; tổng lời theo tháng, theo năm.
- Nhập được Google Sheet cũ mà không nhân đôi dữ liệu.
- Không bao giờ mất sổ: backup cục bộ mỗi ngày, book cũ luôn mở được.

## Non-goals

- Kết nối ngân hàng / thẻ / marketplace tự động.
- Gợi ý đầu tư.
- Gợi ý "món nào nên bán".
- Tự lấy giá thị trường từ marketplace (không có API công khai). App chỉ gợi ý từ sổ, hoặc mở trang tìm kiếm cho người dùng tự xem.
- AI qua API trả phí; chỉ Foundation Models trong máy.

Đã từng là non-goal, giờ đã làm: iCloud chia sẻ sổ (#17), dark mode (#15), giao dịch và phân loại chi tiêu (#12).
- Đặt tên loại hàng trong UI — sổ chỉ chứa *item*, category là của người dùng.

## Nguyên tắc sản phẩm

| Nguyên tắc | Hệ quả |
|---|---|
| **Mọi lần tiền đi là một giao dịch** | Mua một món ghi giao dịch `asset` trên tài khoản đã trả (#12, thay "item không di chuyển tiền"). |
| **Điểm không bao giờ là tiền mặt** | Điểm không vào cash và Safe to spend. **Đang xem lại:** người dùng muốn lời của một món tính cả điểm, và điểm dùng ở đâu cũng được (PayPay) vào tài sản ròng — xem why.md. |
| **Recurring là cam kết, không phải nợ** | Tiền nhà năm sau không nằm trong tài sản ròng. |
| **Nói điều sẽ xảy ra trước nút bấm** | Form kết thúc bằng dòng preview; thao tác phá huỷ qua alert. |
| **Control chỉ khi có lựa chọn** | Không menu một mục; nói kết quả bằng chữ. |

## 5 tab — chia theo câu hỏi

Mỗi con số sống ở **đúng một** màn hình.

| Tab | Thì | Trả lời | Nội dung chính |
|---|---|---|---|
| **Home** | tương lai | "Tiêu được bao nhiêu tới horizon?" | Safe to spend (headline), Scan / Type / To review, nơi đang đứng, Coming up + shortfall, budget còn lại, tile net worth |
| **Transactions** | hiện tại / quá khứ | "Tiền đã đi đâu?" | danh sách + filter + tìm, To review; segment Spending: category, cửa hàng, 6 tháng |
| **Wallet** | hiện tại | "Có bao nhiêu, nợ bao nhiêu?" | net worth + biểu đồ, tài khoản, điểm, thẻ, trả góp, People, đầu tư |
| **Belongings** | hiện tại | "Tôi đang giữ gì, tốn bao nhiêu một tháng?" | status, kỳ, 9 kiểu sắp xếp, tìm, chi phí thật / tháng, worth, bảo hành |
| **Plan** | kế hoạch | "Kỳ lương này còn bao nhiêu, để dành được gì?" | Budget kỳ lương, Goals, Recurring (mọi khoản cố định, list/lịch) |

Quét hoá đơn không là tab: Home (Scan receipt), Transactions (nút scan), widget, Control Center, Action button, Siri. Settings (bánh răng Home) chỉ còn cấu hình: Rules, Categories, Notifications, Household, Your data, Ask Mochi.

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
