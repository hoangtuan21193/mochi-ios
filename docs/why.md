# Mochi để làm gì

Viết từ câu chuyện của người dùng đầu tiên (chủ app và vợ), 2026-10-01. Ghi chép đầy đủ: [research/2026-10-interview.md](research/2026-10-interview.md). Mọi tính năng phải trả lời được: *nó giúp câu hỏi nào dưới đây?*

## Người dùng

Một hộ ở Nhật, hai vợ chồng, chung một sổ.

- **Tiền nằm ở nhiều nơi:** ngân hàng của chồng, ngân hàng của vợ, số dư trên các free market (Mercari…), điểm (PayPay, MapCamera).
- **Gần như mọi thứ trả bằng thẻ.** Có nhiều thẻ, mỗi thẻ trừ tiền một ngày, vào một ngân hàng khác nhau. Có nhiều khoản trả góp 0% chạy cùng lúc, và phí thường niên.
- **Mua đồ cũ, dùng một thời gian, rồi bán lại:** khoảng 100 món mỗi năm, mỗi món 10–30 man. Có món lời, có món lỗ. Không phải công ty, chỉ là mua bán cá nhân những món mình thích (camera, MacBook).
- **Chồng nhập hết.** Vợ chủ yếu xem, nhưng phải thêm và sửa được trên cùng một sổ.

Một vòng tiền điển hình: dùng thẻ vợ mua máy ảnh → bán trên Mercari → rút về ngân hàng của chồng (mất 2–3 ngày làm việc, phí 100–200 yên) → chồng chuyển sang ngân hàng của vợ → thẻ vợ trừ tiền vào ngân hàng của vợ.

## Vấn đề

**"Mình thật sự có bao nhiêu tiền?" — không ai trả lời được.** Mở app ngân hàng thì thấy một số. Nhưng thẻ đang nợ, trả góp còn chạy, đồ mua về chưa bán, tiền nằm trên Mercari chưa rút. Không ai cộng trừ những thứ đó lại cho bạn.

Câu hỏi khó nhất không phải tổng, mà là **đúng tài khoản, đúng ngày**: tổng của hộ đủ, nhưng ngân hàng vợ thiếu đúng hôm thẻ vợ trừ tiền.

## Câu hỏi app phải trả lời

Theo thứ tự quan trọng.

| # | Câu hỏi | Trả lời đúng trông thế nào |
|---|---|---|
| 1 | **Kỳ thẻ tới phải trả bao nhiêu, có đủ không, thiếu bao nhiêu?** | Mỗi thẻ: số tiền + ngày trừ + từ ngân hàng nào. Tính cả lương ngày 25 (lùi về ngày làm việc trước nếu rơi vào ngày nghỉ) và tiền Mercari (sau phí rút, kịp rút trước ngày trừ). |
| 2 | **Phải chuyển bao nhiêu sang tài khoản nào, trước ngày nào?** | "Chuyển ¥130,000 sang ngân hàng vợ trước 27/10." Bấm "đã chuyển" thì số dư hai bên tự đổi. |
| 3 | **Tiêu thêm được bao nhiêu?** (Safe to spend) | Sau khi trả đủ kỳ thẻ gần nhất, còn giữ một khoản phòng thân nhỏ. Một con số cho cả hộ. |
| 4 | **Một món: mua giá này thì bán có lời không? Bán bây giờ lời/lỗ bao nhiêu?** | Tính cả phí sàn (thường 5–10%), ship, phí rút, và **điểm**. Có cả lúc *trước khi mua*: bán bao nhiêu mới hoà vốn. |
| 5 | **Lời bao nhiêu trong tháng, trong năm?** | Tổng lời của các món đã bán, theo tháng và theo năm. |
| 6 | **Tiền đang "kẹt" trong đồ bao nhiêu? Giữ món này tốn bao nhiêu một tháng?** | Tổng giá trị đồ chưa bán. Mỗi món: giữ bao lâu, mất giá bao nhiêu mỗi tháng. |
| 7 | **Tổng cộng mình giàu lên hay nghèo đi?** | Tài sản ròng = tiền + đồ (giá bán được) + điểm dùng được − nợ thẻ − trả góp còn lại. |

Mỗi lần mở app, người dùng làm một trong hai việc: **nhập ngay** khoản vừa tiêu hoặc món vừa mua, hoặc **xem câu 1–3**.

## Nguyên tắc rút từ câu chuyện

- **Hỏi bằng câu người dùng biết.** Người dùng biết "mua ngày 30 thì trả ngày 27 tháng sau", không biết "締め日 là ngày mấy".
- **Giá do người dùng gõ; app chỉ gợi ý.** Gợi ý giá thị trường không bao giờ tự đổi con số đã gõ.
- **Lời của một món tính cả điểm.** Điểm cũng không đều nhau: PayPay tiêu ở đâu cũng được, điểm MapCamera chỉ tiêu được ở MapCamera.
- **Nơi bán do người dùng tự cài:** tên, phí theo % hoặc số tiền cố định mỗi món. App sẽ lên App Store, nên không được giả định chỉ có Mercari.
- **AI chỉ chạy trong máy** (Foundation Models của Apple). Không trả phí API bên ngoài.

## Không cần

- Gợi ý "món nào nên bán".
- Xem riêng tiền của chồng / của vợ: chỉ cần một con số cho cả hộ, cộng với cảnh báo theo từng tài khoản.
- Tự lấy giá từ Mercari / MapCamera: không có API công khai, và scrape thì vi phạm điều khoản.
