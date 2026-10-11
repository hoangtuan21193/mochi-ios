# Phỏng vấn người dùng chính (chủ app)

Ngày: 2026-10-01 · Người trả lời: chủ app, dùng chung với vợ · Trạng thái: xong 4 vòng. Tóm lại thành [why.md](../why.md).

Đây là câu chuyện thật mà app phải phục vụ trước tiên. Nếu nó mâu thuẫn với [product.md](../product.md) hay [decisions.md](../decisions.md) thì ghi lại ở cuối file, không tự sửa.

## Hộ gia đình

- Hai người, cùng một sổ. Chồng nhập hết, kể cả tài khoản của vợ. Vợ hiện chỉ xem, nhưng **phải thêm và sửa được** trên cùng dữ liệu khi cần.
- Hai ngân hàng: của chồng và của vợ. Lương của mỗi người vào ngân hàng của người đó.
- Lương vào ngày 25. Ngày 25 rơi vào thứ Bảy, Chủ nhật hoặc ngày nghỉ thì nhận **ngày làm việc trước đó**.
- Thu nhập khác: tiền bán đồ, nằm trên các free market. Rút về ngân hàng mất **100–200 yên mỗi lần**.

## Thẻ và nợ

- Nhiều thẻ. Thẻ của chồng phần lớn trừ vào ngân hàng của chồng.
- Thẻ của vợ trừ vào ngân hàng của vợ. Chồng trả cả thẻ của vợ: **chuyển từ ngân hàng của mình sang ngân hàng của vợ trước ngày trừ**. Số chuyển không cố định, tuỳ tháng đó tiêu bao nhiêu.
- Trả góp: tiền mua camera, trừ hàng tháng thẳng vào tài khoản.
- Có phí thường niên của thẻ.
- Gần như mọi thứ đều trả bằng thẻ, rất ít dùng tiền mặt.
- Mỗi thẻ trừ tiền một ngày khác nhau. **Biết ngày trừ, không biết ngày chốt sổ**: "mua ngày 30/1 thì khoảng 27/2 phải trả" (kiểu 月末締め翌月27日払い). Có một ngày quanh mùng 10 là lúc "số tiền kỳ này được chốt" (請求確定日), mỗi thẻ một ngày.
- Nhiều khoản trả góp 0% chạy cùng lúc.
- Tiền chuyển sang ngân hàng vợ phải được **ghi lại**: số dư bên này giảm, bên kia tăng.

## Câu hỏi app phải trả lời

- **Hiện tại không biết mình thật sự có bao nhiêu tiền**, vì cùng lúc có nợ thẻ, trả góp, và đồ đã mua mà chưa bán.
- **Safe to spend** = đủ tiền trả kỳ thẻ gần nhất, và còn một khoản tiền mặt nhỏ để phòng thân. Không phải "tiêu được bao nhiêu tới ngày lương", vì chi tiêu đi qua thẻ chứ không trừ thẳng vào tiền mặt. Số phòng thân chưa biết đặt bao nhiêu, muốn app gợi ý.
- Tiền dùng để trả thẻ gồm: ngân hàng của cả hai, **tiền trên Mercari** (rút về được, trừ phí rút), và **lương ngày 25**, nếu lương về trước ngày trừ thẻ.

- Rút tiền Mercari về ngân hàng mất **2–3 ngày làm việc** (không tính ngày nghỉ).
- **Một con số cho cả hộ.** Không cần xem riêng tiền của chồng / vợ; chỉ cần biết tài khoản nào sắp thiếu.

## Một vòng tiền điển hình

Dùng **thẻ của vợ** mua máy ảnh → bán trên Mercari → rút tiền Mercari về **ngân hàng của chồng** → chồng chuyển tiền sang **ngân hàng của vợ** → thẻ vợ trừ tiền vào ngân hàng vợ.

Mỗi bước nằm ở một tài khoản khác nhau. Tổng của hộ có thể đủ trong khi đúng tài khoản bị trừ lại thiếu.

## Mở app để làm gì

1. Nhập ngay khoản vừa tiêu, hoặc món vừa mua để bán lại.
2. Xem tháng sau phải trả thẻ bao nhiêu, có đủ không, thiếu bao nhiêu.

## Mua bán đồ

- Khoảng **100 món mỗi năm, mỗi món 10–30 man**. Có món lời, có món lỗ.
- Thường dùng một thời gian rồi mới bán.
- Mua ở nhiều nơi: Mercari, ヤフオク, MapCamera, Kitamura, cửa hàng. Trả bằng thẻ. Nhiều nơi cho điểm (MapCamera), và **điểm quan trọng**.
- Bán trên các free market của Nhật. Muốn **người ở nước khác cũng dùng được**, nên nơi bán phải tự cài: tên nơi bán, phí theo **% hoặc số tiền cố định mỗi món**.
- Muốn app trả lời:
  - lời/lỗ từng món khi đã bán
  - tổng lời theo tháng và theo năm
  - tiền đang "kẹt" trong đồ chưa bán
  - món nào nên bán, món nào để quá lâu, món nào đang mất giá
  - giữ một món thì tốn bao nhiêu mỗi tháng
  - **nếu bán bây giờ thì lời hay lỗ bao nhiêu**
- **Không cần** "món nào nên bán" — bỏ.
- Giá bán ước tính do người dùng tự gõ. App được **gợi ý** giá thị trường, nhưng không bao giờ tự đổi số đã gõ.
- Muốn tính được **trước khi mua**: mua X giá Y thì bán lại có lời không, sau phí sàn, ship và phí rút.
- **Lời tính cả điểm.**
- Điểm không đều nhau: **PayPay** tiêu ở đâu cũng được, chắc chắn là tài sản. **MapCamera** bị khoá, chỉ tiêu được ở MapCamera. Có thể đổi điểm khoá ra tiền bằng cách mua đồ bằng điểm rồi bán, nhưng bán không phải lúc nào cũng lời.
- Phí chi tiết: phí sàn (thường 5–10%), ship (mỗi món một khác), phí rút tiền. Đóng gói tự làm, không tốn.

## Phạm vi

- Sau này **đưa lên App Store** cho người ở nước khác.
- AI chỉ dùng model trong máy do Apple cung cấp (Foundation Models), không trả phí API bên ngoài.

## Lệch với code / doc hiện tại

| # | Nhu cầu | Hiện trạng |
|---|---|---|
| 1 | Biết tài khoản *nào* thiếu tiền và phải chuyển bao nhiêu sang ngân hàng vợ | `Finance.paymentsDue` cộng chung tiền mọi tài khoản. Tổng đủ nhưng ngân hàng vợ thiếu thì app vẫn báo ổn |
| 2 | Lương lùi về ngày làm việc trước đó | `Finance.date(day:in:)` không biết cuối tuần hay ngày nghỉ. Ngày trừ thẻ ở Nhật thường lùi sang ngày làm việc *sau* — chưa có |
| 3 | Phí rút tiền từ free market | `AppData.defaultTransferFee` (210) không được đọc ở đâu cả |
| 4 | Phí bán cố định mỗi món | `SalesChannel` chỉ có `rate` (%) |
| 5 | Lời/lỗ từng món, "bán bây giờ lời bao nhiêu" | Quyết định #18 cấm chữ "profit" trên màn belonging |
| 6 | Vợ cùng sửa một sổ | `CloudSync` đã có code nhưng đang tắt. Cần Apple Developer Program trả phí để ký iCloud |
| 7 | Một người, một hộ | product.md / roadmap / #12 nhắm tới "app tài chính cho nhiều người": budget, goals, AI… |
| 8 | Dùng được ở nước khác | product.md: "người ở Nhật, tiền yên" |
| 9 | Không biết ngày chốt sổ, chỉ biết "mua ngày 30 thì trả ngày 27 tháng sau" | `CardSheet` hỏi "Closes on day (15)" bằng một ô số |
| 10 | Lời tính cả điểm | CLAUDE.md: điểm "never in cash, profit or net worth" |
| 11 | Safe to spend tính tới lúc trả xong kỳ thẻ gần nhất, có lương ngày 25 | Horizon là 30 / 60 ngày / tới ngày lương. "Tới ngày lương" bỏ chính khoản lương đó và các kỳ thẻ trừ sau ngày lương |
| 12 | Tiền Mercari dùng để trả thẻ | Được tính như tiền ngân hàng: không trừ phí rút, không tính thời gian chờ rút |
| 13 | Tính trước khi mua: mua giá Y thì bán bao nhiêu mới hoà | Chưa có |
| 14 | Cột "Thẻ vợ" là thẻ của hộ, dùng để mua đồ | `Store.columnsIgnored` cố ý bỏ qua cột này ("someone else's card") |
| 15 | Điểm dùng ở đâu cũng được (PayPay) là tài sản | Điểm không vào net worth, mọi loại như nhau |
| 16 | Rút Mercari mất 2–3 ngày làm việc | Không có lịch ngày làm việc, không nhắc hạn rút |
