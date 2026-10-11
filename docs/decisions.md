# Nhật ký quyết định

ADR-lite: mỗi mục là một quyết định đã chốt, lý do, và hệ quả. **Agent đọc file này trước khi đề xuất** — nhiều thứ ở đây đã được thử và bỏ.

Thêm mục mới bằng [templates/decision.md](templates/decision.md). Không xoá mục cũ; quyết định bị đảo thì thêm mục mới và đánh dấu mục cũ "Thay bởi #N".

## Tóm tắt

| # | Quyết định | Trạng thái |
|---|---|---|
| 1 | Item không bao giờ di chuyển tiền | Thay bởi #12 |
| 2 | Bốn con số, không gộp thành một | Chốt |
| 3 | Không biểu đồ số dư tiền mặt | **Đã bỏ** (2 lần) |
| 4 | Thẻ không có closing day: sao kê đóng hôm nay | Chốt |
| 5 | Backup cục bộ, không iCloud | Sửa bởi #17 |
| 6 | Ledger ghi, không hiện | Chốt |
| 7 | Bỏ card "Richer or poorer?" khỏi Overview | **Đã bỏ** (vẫn đúng trên Home) |
| 8 | Năm tab, không hơn | Tab đổi bởi #14 |
| 9 | Chỉ light mode | Thay bởi #15 |
| 10 | Purchase key = Item + 購入日 + Buy on Market | Chốt |
| 11 | Fresh install hoàn toàn rỗng | Chốt |
| 12 | Ledger giao dịch: số dư = số mở + Σ giao dịch | Chốt (2026-09) |
| 13 | "Until payday" không tính lương của chính ngày đó | Chốt |
| 14 | Tab: Home · Transactions · Add · Belongings · Plan | Thay bởi #24 |
| 15 | Light + dark, font hệ thống | Chốt |
| 16 | Nhập liệu offline: Vision OCR + luật, AI chỉ trên máy | Chốt |
| 17 | Chia sẻ sổ qua iCloud, tắt sau cờ | Chốt |
| 18 | Belonging nói "chi phí thật / tháng", không nói "lời" | Thay bởi #26 |
| 19 | Tên địa danh: sổ trước, Apple Maps sau, tắt được | Chốt (2026-10) |
| 20 | Quét: bấm chụp là sang Check and save, đọc tiếp ở nền | Chốt (2026-10) |
| 21 | Hoá đơn dài / bị cắt: để trống thay vì đoán, quét tiếp phần còn lại | Chốt (2026-10) |
| 22 | Hoá đơn ngoại tệ: đọc tiền trên giấy, quy đổi theo tỉ giá gõ lần trước | Chốt (2026-10) |
| 23 | Hoá đơn nghiêng: dòng theo độ nghiêng của chữ, ảnh được nắn thẳng rồi đọc lại | Chốt (2026-10) |
| 24 | 5 tab thật: Home · Transactions · Wallet · Belongings · Plan; bỏ (+) | Chốt (2026-10) |
| 25 | Recurring kiểu Monarch: mọi khoản cố định một chỗ, lọc theo loại, list/lịch | Chốt (2026-10) |
| 26 | Belonging theo mục đích: để bán → lời/lỗ nếu bán bây giờ; giữ dùng → chi phí thật/tháng | Chốt (2026-10), thay #18 |
| 27 | Lời của một món tính cả điểm; điểm dùng ở đâu cũng được vào tài sản ròng, điểm khoá thì không | Chốt (2026-10) |
| 28 | Dự báo theo từng tài khoản, gợi ý chuyển tiền giữa tài khoản của mình | Chốt (2026-10) |
| 29 | Safe to spend nhìn tới hết các kỳ thẻ gần nhất, tính lương về trước đó | Chốt (2026-10) |
| 30 | Ngày làm việc Nhật: lương lùi về trước, thẻ và trả góp lùi về sau | Chốt (2026-10) |
| 31 | Tỉ giá, giá vàng, giá crypto tự lấy qua mạng; không gõ tay; tắt được | Chốt (2026-10), thay một phần #22 |
| 32 | Không kết nối ngân hàng; nhập gần như tự động bằng Apple Pay, email thẻ, share sao kê | Chốt (2026-10) |
| 33 | Pro mua một lần (¥980), không subscription, không quảng cáo | Chốt (2026-10) |
| 34 | Bấm chụp là xong: không đọc lại ảnh sau khi chụp | Chốt (2026-10) |

## Đã bỏ — đừng đưa lại

Muốn đưa lại một thứ dưới đây → dừng, hỏi người, viết design doc giải thích điều gì đã đổi.

- **Biểu đồ số dư tiền mặt** trên Overview — thử 2 lần, bỏ 2 lần (#3).
- **Card "Richer or poorer?"** + `CashFlowSheet` + `Store.thisMonth` (#7).
- **Card "Sell these to stay above the reserve"** — gợi ý bán item để bù thiếu.
- **Màn hình Activity** (ledger `LedgerEntry`) — bị coi là rối (#6). Transactions (#12) không phải nó: là danh sách chi tiêu người dùng tự sửa, không phải nhật ký thao tác.
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

### 12. Ledger giao dịch
- **Bối cảnh:** #1 giữ số dư gõ tay; muốn thành app tài chính cho nhiều người thì phải biết chi vào đâu. Người dùng: "các app khác làm thế nào" — Monarch, Zaim, Money Forward đều là ledger.
- **Quyết định:** `Transaction` (spend / income / move / refund / asset / adjustment). `Wallet.balance` là số mở; số dư = số mở + Σ ảnh hưởng. Gõ lại số dư = một giao dịch `.adjustment`. Lịch (lương, bill, trả thẻ, trả góp, tích luỹ) tự ghi vào ngày đến hạn. Mua belonging là giao dịch `.asset` gắn `itemID`.
- **Hệ quả:** `ledgerStart` chia sổ cũ/mới — trước ngày đó tính như cũ, nên mở sổ cũ không đổi con số nào (`switchingToTheLedgerChangesNoFigure`). Chu kỳ thẻ tính từ giao dịch, sao kê gõ tay là mỏ neo. `LedgerEntry` vẫn ghi (#6). Chi tiết: [design/transactions.md](design/transactions.md).

### 13. Lương ngày payday
- **Bối cảnh:** "until payday" kết thúc đúng ngày lương; tính lương đó vào làm Safe to spend phình ra bằng một tháng lương.
- **Quyết định:** horizon `.payday` bỏ income rơi đúng ngày cuối. Test `untilPaydayDoesNotCountThatDaysSalary`.

### 14. Tab mới
- **Bối cảnh:** Stats (quá khứ) và Overview (tương lai) chia nhau con số bán hàng; app chung cần chỗ cho giao dịch và kế hoạch. "This pay period" trên Home khó hiểu → tab riêng.
- **Quyết định:** Home · Transactions (+ Spending) · Add (mở capture) · Belongings · Plan (Budget / Goals / Subscriptions). Stats gộp vào Belongings (bán theo kỳ) và Net worth (biểu đồ từ snapshot). Accounts, People, Settings là màn hình đẩy vào, không phải tab.
- **Hệ quả:** biểu đồ có ở Spending và Net worth; biểu đồ số dư tiền mặt vẫn cấm (#3).

### 15. Dark mode, font hệ thống
- **Bối cảnh:** #9 vì palette kem không có bản tối; font hiển thị chỉ Latin-1 nên tiếng Việt/Nhật đã phải rơi về font hệ thống.
- **Quyết định:** mọi token `Color.dynamic(light, dark)`; font hệ thống, số `monospacedDigit`. Tên namespace `Organic` giữ nguyên để không đổi call site.

### 16. Nhập liệu offline
- **Bối cảnh:** người dùng không muốn AI online; nhập tay là lý do số 1 người ta bỏ app tài chính.
- **Quyết định:** VisionKit quét → Vision OCR (ja, en) → `ReceiptParser` (luật, có test) → `Store.guess` (nhớ theo số đăng ký インボイス hoặc tên, thẻ theo 4 số cuối, category theo luật/lịch sử). Foundation Models chỉ iOS 26 và chỉ khi máy có. Vị trí so với nơi đã lưu trước; tên chỗ mới lấy từ Apple Maps (#19). Apple Pay qua Shortcuts automation → To review. CSV sao kê có khớp trùng.
- **Hệ quả:** mọi thứ đoán ra đều nói *vì sao* cạnh ô, và chờ ở To review khi không chắc.

### 17. iCloud chia sẻ
- **Bối cảnh:** hộ gia đình cần hai máy một sổ; #5 bỏ toggle vì nó không ghi gì.
- **Quyết định:** `CloudSync` — cả sổ là một record trong zone riêng, share cả zone. Bản mới hơn thắng, bản bị thay được backup trước. Tắt cho tới khi Info.plist có `MochiCloudSyncEnabled` và container tồn tại ([setup-xcode.md](setup-xcode.md)).
- **Hệ quả:** backup cục bộ của #5 vẫn chạy như cũ.

### 18. Chi phí thật của belonging
- **Bối cảnh:** ở Nhật, app "hỗ trợ resell" dễ bị ghét; nhưng biết một món thực sự tốn bao nhiêu thì ai cũng cần.
- **Quyết định:** belonging hiện (giá mua − tiền bán ròng hoặc giá trị hiện tại) / số tháng giữ. Dưới một tháng thì không hiện. Không có chữ "profit" trên màn hình belonging. `boughtToResell` chỉ đổi lời nhắc 古物商.

### 19. Tên địa danh khi quét
- **Bối cảnh:** "Where you were when you scanned" không nói gì; người dùng muốn thấy tên chỗ. iPhone không đổi toạ độ ra tên được khi offline.
- **Quyết định:** `Store.placeName` hỏi sổ trước (`Finance.placeName`: tên đã lưu trong 80 m, rồi cửa hàng hay trả tiền ở đó), chỉ khi sổ không biết mới hỏi Apple Maps (`CLGeocoder`: landmark, không có thì quận + phường). Tên lưu vào `Transaction.placeName`, lần sau ở gần đó không hỏi lại. `AppData.lookUpPlaceNames` (nil = bật) tắt ở Settings › Your data.
- **Hệ quả:** đây là thứ duy nhất trong luồng quét gửi dữ liệu ra ngoài (toạ độ, không có số tiền hay hoá đơn); màn Check and save ghi rõ "From Apple Maps". Không mạng thì vẫn lưu toạ độ, không có tên. Không phải AI.

### 20. Quét: bấm chụp là sang Check and save
- **Bối cảnh:** chờ đọc xong ảnh (và model on-device) mới rời camera làm bấm chụp có cảm giác treo.
- **Quyết định:** rời camera ngay với những gì đọc được lúc ngắm; ảnh nét đọc ở nền, chỉ điền ô người dùng chưa sửa; Save chờ tới khi đọc xong ảnh. Camera dùng thiết bị nhiều ống kính để tự sang macro.

### 21. Hoá đơn dài, bị cắt, nhiều ngôn ngữ
- **Bối cảnh:** chụp mỗi phần dưới thì tên cửa hàng bị lấy từ một dòng hàng; chụp mỗi phần trên thì "tổng" là món đắt nhất. Vision đọc theo chữ của ngôn ngữ đứng đầu: Nhật trước thì tiếng Việt mất dấu, Việt trước thì tiếng Nhật thành "·160".
- **Quyết định:** parser để trống chứ không đoán (`missingTop` / `missingBottom`); Check and save báo và có "Scan the rest", hai phần ghép bằng `ReceiptDraft.joined` (dòng trùng ở chỗ chồng lên chỉ giữ một), ảnh xếp phần đầu ở trên. Từ khoá Nhật / Anh / Việt có điểm mạnh yếu (総合計 > 合計 > thành tiền), từ Latin dài được sai một chữ. Số tiền đọc theo dấu phân cách (74.700 là nghìn, 25.35 là xu, làm tròn về đơn vị). Đọc theo thứ tự ngôn ngữ của sổ; trông sai chữ thì đọc lại thứ tự kia (`ReceiptReader.otherOrder`), hoà điểm thì giữ bản đọc lại.
- **Hệ quả:** `ReceiptCasesTests` giữ các dòng Vision thật đọc ra (cả bản đọc sai). Hoá đơn ngoại tệ: xem #22.

### 22. Hoá đơn ngoại tệ
- **Bối cảnh:** hoá đơn Việt trong sổ yên bị ghi "¥125,000" và còn được gợi ý làm belonging.
- **Quyết định:** `ReceiptParser.currency` đọc ¥/円, ₫/VND/"d" sau số, $/USD, €/EUR; không có ký hiệu thì chữ Nhật = yên, chữ/từ Việt = đồng; không có gì thì nil (tiền của sổ, không đoán). Khác tiền của sổ: giao dịch giữ `currency` + `foreignAmount` + `rate` (các trường màn sửa giao dịch đã dùng), số trong sổ = `Finance.convert` theo tỉ giá gõ lần trước (`data.rates`); chưa có tỉ giá thì chưa lưu được. Ngưỡng belonging so sau khi quy đổi. "It was in yen" bỏ nhận diện sai.
- **Hệ quả:** không tra tỉ giá online — sao kê thẻ mới có tỉ giá thật. Xu ($4.85) làm tròn về đơn vị như mọi số trong sổ.

### 23. Hoá đơn chụp nghiêng
- **Bối cảnh:** chụp nghiêng thì giá bên phải lệch lên/xuống quá nửa dòng so với tên bên trái; ghép theo toạ độ y ráp "合計" với giá của dòng khác. Khung khoanh chữ nhật thẳng không theo chữ.
- **Quyết định:** ghép dòng theo hướng của chữ (4 góc Vision trả về); cụm ngắn Vision cho hộp vuông nên mượn hướng của cụm dài gần nhất. Khung khoanh vẽ theo 4 góc (`LineOutline`). Sau khi chụp, ảnh được cắt tờ giấy ra và nắn phối cảnh (mô hình tài liệu, và tứ giác lớn nhất — mô hình có lúc khoanh sai), tăng tương phản, đọc lại; giữ bản đọc điểm cao nhất cùng ảnh của nó.
- **Hệ quả:** đọc ảnh lâu hơn (tối đa 3 ảnh × 2 thứ tự ngôn ngữ); Save chờ trong lúc đó.

### 24. Tab Wallet, bỏ (+)
- **Bối cảnh:** tiền nằm ở Accounts (mở từ Home), đầu tư ở Net worth, đồ ở Belongings — người dùng không biết vàng, cổ phiếu, tài khoản thuộc đâu. (+) chiếm một ô tab mà không phải màn hình.
- **Quyết định:** Wallet = "có bao nhiêu, nợ bao nhiêu": net worth ở đầu (biểu đồ bấm vào), rồi tài khoản, điểm, thẻ, trả góp, Every month, People, đầu tư (NISA, cổ phiếu, vàng). Belongings = đồ mua để dùng. Quét hoá đơn vào từ Home, nút nhỏ ở Transactions, widget Scan, Control Center, Action button, Siri. Không thêm tab thứ 6: iPhone gom ô thứ 6 vào "More".
- **Hệ quả:** Settings không còn mục tiền nào; loan book mở từ People. `-tab 2` là Wallet.

### 25. Recurring kiểu Monarch
- **Bối cảnh:** tiền nhà không phải subscription, nhưng người dùng muốn thấy mọi khoản cố định ở một chỗ như Monarch (Rocket Money và Money Forward tách riêng).
- **Quyết định:** Plan › Recurring thay Subscriptions: theo tháng, ô tổng (tiền vào / bills / subscriptions / còn phải trả), lọc All · Bills · Subscriptions · Income, xem List (Upcoming / Done) hoặc Calendar, thêm khoản mới tại đây. Loại suy từ khoản: thu nhập, `category == "subscription"`, còn lại là bill. "Still using it?" giữ cho subscription. Wallet bỏ Every month, chỉ còn một dòng dẫn sang.
- **Hệ quả:** `Finance.recurringDue` / `recurringTotals` / `recurringIncomeByDay` có test; không đổi dữ liệu lưu.

### 26. Belonging theo mục đích
- **Bối cảnh:** #18 cấm chữ "profit" vì sợ app resell bị ghét. Người dùng chính mua bán khoảng 100 món/năm và cần lời/lỗ của từng món (docs/why.md, câu 4–5).
- **Quyết định:** `Item.boughtToResell` quyết định con số chính: món để bán hiện "bán bây giờ lời/lỗ ¥X" (sau phí, ship, phí rút, cộng điểm); món giữ dùng hiện chi phí thật mỗi tháng như #18. Belongings lọc To sell / To use / Sold.
- **Hệ quả:** #18 còn đúng cho món giữ dùng.

### 27. Điểm
- **Bối cảnh:** "Lời phải tính điểm" (phỏng vấn). PayPay dùng như tiền; điểm MapCamera chỉ dùng ở MapCamera.
- **Quyết định:** lời = tiền về − giá mua − phí + điểm (1 điểm = ¥1, chỉnh được theo ví điểm); luôn hiện kèm phần tiền. Ví điểm có cờ "dùng ở đâu cũng được": loại đó vào tài sản ròng, loại khoá thì không. Không điểm nào vào tiền mặt hay Safe to spend.
- **Hệ quả:** CLAUDE.md mục Points sửa theo.

### 28. Dự báo theo tài khoản
- **Bối cảnh:** tổng của hộ đủ nhưng ngân hàng vợ thiếu đúng ngày thẻ vợ trừ; dự báo cộng chung thì báo "ổn".
- **Quyết định:** mỗi tài khoản có dự báo riêng (thẻ trừ từ đâu, lương và rút marketplace vào đâu); thiếu thì gợi ý "chuyển ¥X từ A sang B trước ngày Y"; "Đã chuyển" ghi một giao dịch move. Home vẫn một con số cho cả hộ.

### 29. Safe to spend
- **Bối cảnh:** người dùng: "đủ trả tới 27/10, sau lương 25/10 hay không". "Tới ngày lương" bỏ đúng khoản lương dùng để trả thẻ ngày 27.
- **Quyết định:** horizon mặc định = ngày trả muộn nhất của các kỳ thẻ gần nhất; tính lương và tiền marketplace rút kịp trước ngày đó. Phần đã quẹt chưa vào sao kê hiện riêng, không trừ.

### 30. Ngày làm việc
- **Quyết định:** lịch ngày nghỉ Nhật tính theo luật (ngày cố định, Happy Monday, xuân/thu phân, nghỉ bù, 国民の休日). Lương lùi về ngày làm việc trước; thẻ, trả góp lùi về ngày làm việc sau; rút marketplace đếm ngày làm việc.

### 31. Giá tự lấy
- **Bối cảnh:** người dùng không muốn gõ tỉ giá; có vàng, crypto.
- **Quyết định:** tỉ giá, giá vàng (theo thị trường sẽ bán), giá crypto lấy qua mạng; chỉ gửi mã tiền / loại vàng / tên coin, không gửi số lượng. Offline dùng giá gần nhất và ghi ngày. Tắt được trong Your data. Đầu tư không bao giờ vào tiền mặt hay Safe to spend.
- **Hệ quả:** #22 còn đúng phần đọc tiền trên hoá đơn; phần "không bao giờ tra tỉ giá" bỏ.

### 32. Không kết nối ngân hàng
- **Bối cảnh:** Nhật phải đăng ký 電子決済等代行業; thẻ, PayPay không có API cá nhân; aggregator cần server và tiền.
- **Quyết định:** nhập gần như tự động: Apple Pay qua Shortcuts (hỏi category hoặc lưu im), email báo chi tiêu của thẻ qua Shortcuts, share CSV/PDF vào Mochi. Kết nối thật để sau, như Pro, qua bên đã có giấy phép.

### 33. Pro một lần
- **Quyết định:** Pro mua một lần ¥980 (giá riêng theo nước; ¥980 thay ¥1,000 vì giá lẻ dễ mua hơn), Family Sharing, dùng thử 14 ngày bằng món ¥0. Free luôn có: thẻ, Safe to spend, scan, belongings, export. Pro: sổ chung, Buy advice, giá vàng/crypto, import, Ask Mochi. Không quảng cáo, không bán dữ liệu.

### 34. Không đọc lại ảnh sau khi chụp
- **Bối cảnh:** trước đây camera đọc hoá đơn lúc ngắm, bấm chụp xong lại đọc ảnh lần nữa (cắt, làm thẳng, sửa ngôn ngữ) rồi điền đè những ô chưa sửa. Người dùng phải chờ thêm, và lần đọc thứ hai có thể ra số khác với số vừa thấy trong khay, trông như app tự đổi ý.
- **Quyết định:** khay lúc bấm chụp là kết quả. Ảnh chụp chỉ được lưu làm hoá đơn, không đọc lại. Ảnh chọn từ Photos không có lần đọc lúc ngắm nên vẫn được đọc đầy đủ (`ReceiptReader.read`).
- **Hệ quả:** model trên máy (iOS 26) không còn chạy sau khi chụp; vẫn chạy cho ảnh chọn từ Photos. "Scan the rest" vẫn ghép hai lần đọc lúc ngắm.


### 35. Net worth không vẽ "By type"
- **Bối cảnh:** canvas Net worth có nút Net worth | By type. Snapshot tháng chỉ giữ tiền mặt, nợ thẻ, nợ trả góp và net worth; vẽ theo loại nghĩa là vẽ lại đường tiền mặt theo thời gian.
- **Quyết định:** bỏ "By type". Net worth chỉ có một đường; chọn khoảng (This year · 12 months · Every reading) ở thanh trên. Đường tiền mặt vẫn cấm (#3).
