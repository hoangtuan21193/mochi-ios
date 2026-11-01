# Share từ Mercari (và shop khác) vào Mochi — Design doc

Trạng thái: **đã triển khai** (2026-10-12) · Code: `MochiShare/` (extension), `Engine/ListingReader.swift`, `Models/SharedEntry.swift`, `Store+Share.swift` · Test: `ListingReaderTests`, `ShareInboxTests` · Canvas: ShareItem, ShareItemReading, ShareItemFailed (+ Dark), Export (Your data)

## Context and motivation

Mua một món trên Mercari xong, muốn ghi vào Mochi thì phải mở app, Belongings, +, gõ lại tên và giá. Bấm Share trong Mercari không thấy Mochi, vì app chưa có Share Extension. Nhập tay là lý do số 1 người ta bỏ app tài chính (#16).

Goals:
- Từ trang item trên Mercari: Share → Mochi → Save là ghi xong một belonging, không cần mở Mochi. Tên và giá điền sẵn.
- Belonging đó có transaction asset trên thẻ hoặc ví đã trả, nên hiện ở Transactions ("Belonging · not spending").
- Shop khác có meta giá chuẩn (Yahoo!フリマ, ヤフオク!, ラクマ, Rakuten…) dùng chung đường này.

Non-goals (v1):
- Share listing của chính mình để đánh dấu đã bán. Để v2, khớp theo `Item.link`.
- Tải ảnh sản phẩm vào sổ. `Item` chưa có ảnh; extension chỉ hiện ảnh nhỏ để nhận ra món.
- Giá ngoại tệ (eBay…): ô giá để trống, người dùng tự gõ.
- Đọc giá từ ảnh chụp màn hình Mercari: đó là đường Scan, không làm ở đây.
- Mở app Mochi từ extension. Share extension không có `openURL` chính thức.

## Nằm ở màn hình nào

| Con số / UI | Màn hình | Vì sao ở đó |
|---|---|---|
| Sheet "Add to Mochi" (tên, giá, trả bằng, giữ / để bán / chỉ là chi tiêu) | Share sheet của iOS, nằm trên Mercari | ghi ngay lúc vừa mua, không rời app đang dùng |
| Món vừa ghi | Belongings (như mọi món) + Transactions (dòng asset) | không thêm con số mới |
| "Read links you share" | Settings › Your data, cạnh các công tắc lookUp khác | mọi thứ hỏi mạng đều tắt ở cùng một chỗ |

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** không có. Liên quan **#19 / #31** (chỉ được hỏi mạng ở vài chỗ, tắt được). Feature này mở thêm một chỗ: quyết định **#39**. Liên quan **#16** (automation vào To review): chế độ "Just a spend" đi vào To review như Apple Pay.
- **Tương thích lưu trữ:** `Item.link: String?` (nil), `AppData.lookUpListings: Bool?` (nil = bật). Cả hai Optional và có trong CodingKeys / `init(from:)`. `version1BookDecodes` (FinanceTests) có thêm kỳ vọng `lookUpListings == nil`, `link == nil`.
- **Đã thử thật (2026-10-12):** `GET https://jp.mercari.com/item/m42404194676` với UA Safari iPhone trả HTML render sẵn, gồm:
  - `<meta name="product:price:amount" content="105000">` và `product:price:currency` = `JPY`
  - `og:title` = "SONY α7III ILCE-7M3 ボディ **by メルカリ**" (phải bỏ đuôi)
  - `og:site_name` = メルカリ, `og:image` = ảnh đầu tiên
  - JSON-LD `Product` / `Offer` có `price` (đường dự phòng)

  Không cần đăng nhập hay chạy JS. Mercari có thể đổi trang bất cứ lúc nào, nên đọc không ra thì ô để trống, không bao giờ đoán.

### Extension ghi thẳng vào sổ hay để vào hộp chờ?

| Lựa chọn | Được | Mất |
|---|---|---|
| A. Extension mở `Store` và ghi `mochi.json` | ghi xong là có ngay | hai process cùng ghi một file (app có thể đang mở) → mất dữ liệu; extension chỉ có ~120 MB RAM, nạp cả sổ thì nặng |
| **B. Hộp chờ trong App Group (chọn)** | chỉ app ghi sổ, nên không có race; extension nhẹ | món chỉ vào sổ khi app mở hoặc quay lại foreground (vài giây sau, nếu mở app ngay) |

### Đọc trang ở đâu?

| Lựa chọn | Được | Mất |
|---|---|---|
| **A. Trong extension, lúc sheet mở (chọn)** | thấy giá ngay, sửa trước khi Save | thêm ~1 s chờ; sheet phải có trạng thái "Reading…" |
| B. Trong app, lúc nhận hộp chờ | extension đơn giản | lưu xong mới biết đọc sai; ghi sổ phụ thuộc vào mạng lúc mở app |

## High-level behavior

1. Trên Mercari: Share → **Mochi**. `NSExtensionActivationRule` nhận 1 URL web hoặc text có chứa URL (Mercari có thể share dạng text kèm link, hoặc link rút gọn; cần thử trên máy thật).
2. Extension lấy URL `https` đầu tiên và đọc `share.json` trong App Group. App ghi file này cùng lúc với `widget.json`, gồm: tên tài khoản (ví trước, thẻ sau), tài khoản dùng lần cuối ở mỗi shop, `lookUpListings`, ký hiệu tiền.
3. Nếu `lookUpListings` bật: `URLSession` GET đúng URL đó, UA Safari, timeout 6 s, đọc tối đa 3 MB. `ListingReader.read(html:url:)` trả về `Listing(title, price, currency, shop, imageURL)`.
   - Giá: `product:price:amount` → JSON-LD `Offer.price` → nil. Chỉ nhận khi currency là `JPY` (hoặc tiền của sổ).
   - Tên: `og:title` bỏ đuôi đã biết (" by メルカリ", " - Yahoo!フリマ", "| ラクマ"…); không có `og:title` thì lấy `<title>`.
   - Shop: `og:site_name` qua bảng alias (メルカリ → Mercari, ヤフオク! → Yahoo! Auctions…), khớp tên shop đã có trong sổ (`boughtFrom`); không có thì lấy host.
4. Sheet hiện: ảnh nhỏ + tên (FormField, sửa được), **To sell · To use · Just a spend** (mặc định To sell nếu lần cuối mua ở shop này là để bán, không thì To use), giá (`MoneyField`), Bought at, **Paid with** (`ChipPicker`, mặc định là tài khoản dùng lần cuối ở shop này).
5. Preview trước nút (rule 7): "Added as a belonging, not as spending: ¥105,000 on Rakuten card. It reaches your book the next time Mochi opens."
6. Save → ghi `share-inbox/<id>.json` (`SharedEntry`: id, ngày, tên, giá, shop, tài khoản, mode, link), đóng sheet.
7. App mở hoặc quay lại foreground → `Store.takeSharedEntries()`:
   - To use / To sell: `addItem` với `id` = id của entry, `link`, `keep` / `boughtToResell`, `estimatedPrice` = giá mua. `bookPurchase` tự tạo transaction asset, nên món hiện ở Transactions.
   - Just a spend: `Transaction(.spend, needsReview: true)`, chờ chọn category ở To review.
   - Ghi xong mới xoá file. Nếu id đã có trong sổ thì bỏ qua, nên nhận hai lần cũng chỉ ra một món.
8. Trùng: nếu link đã có trong `share.json` (app ghi kèm danh sách link đã lưu), sheet nói "Already in your book: <name>, bought <date>" và nút đổi thành "Add again".

## Công thức

Không có con số mới. `ListingReader` là hàm thuần (String → Listing), nằm trong Engine để có test.

## Dữ liệu lưu trữ

| Field | Kiểu | Mặc định khi book cũ không có | Ghi ở |
|---|---|---|---|
| `Item.link` | `String?` | `nil` | `Models/Item.swift` |
| `AppData.lookUpListings` | `Bool?` | `nil` = bật | `Models/AppData.swift` |
| `share.json`, `share-inbox/*.json` | file trong App Group, không thuộc sổ | — | `Store+Share.swift` |

## Ledger & undo

- Belonging: `addItem` → `bookPurchase` (asset) + `LedgerEntry` kind "x", y như thêm tay. Mua trước `ledgerStart` hoặc không có tài khoản thì không có transaction (luật cũ).
- Spend: `Store.add(transaction)` như Apple Pay.
- Undo: xoá item thì xoá luôn transaction của nó (`deleteItem`, đã có). Không cần thêm undo riêng.

## Error handling and UX

| Loại | Ví dụ | Xử lý / copy |
|---|---|---|
| Không có mạng / timeout | đi tàu điện | tên lấy từ text được share (nếu có), giá trống: "Couldn't read the page. Type the price." |
| Trang không có giá | Amazon chặn bot, trang đã xoá | như trên; Save chỉ bật khi giá > 0 |
| Giá không phải yên | eBay USD | giá trống: "This page is in USD. Type what you paid in yen." |
| Tắt lookUpListings | Settings › Your data | không gửi request nào, sheet nói "Reading links is off in Mochi › Settings" |
| Tài khoản bị xoá trước khi app nhận | đổi tên thẻ giữa chừng | món vào sổ không có tài khoản, nên không có transaction (như thêm tay không chọn tài khoản). Spend vẫn vào To review |
| Chưa từng mở app (không có share.json) | cài mới | sheet: "Open Mochi once first." |
| Giá trên trang ≠ giá trả | coupon, điểm メルペイ | dòng phụ dưới ô: "Listed at ¥105,000. Change it if you paid less." |

## Quyết định #39 (đã ghi vào decisions.md)

- **Bối cảnh:** muốn ghi đồ mua từ Mercari nhanh nhất; trang item có giá trong meta.
- **Quyết định:** link người dùng tự share được đọc **một lần, từ máy, đúng URL đó**, chỉ để lấy tên, giá, shop và ảnh. Không gửi gì từ sổ đi. Tắt bằng `AppData.lookUpListings` ở Your data. Đọc không ra thì để trống, không đoán.
- **Hệ quả:** CLAUDE.md, mục "Capture reads on the phone; only…", thêm "a link the user shares".

## Future-proofing

- `Item.link` mở đường cho v2: share listing của mình lúc bán → khớp `link` → mở sheet Sell với giá đã điền.
- `ListingReader` có thể dùng lại cho "Bought it" trong Buy advice (dán link).

## Implementation outline

1. `Item.link`, `AppData.lookUpListings` + decode + fixture tương thích.
2. `Engine/ListingReader.swift` + `ListingReaderTests` (fixture: chỉ phần `<head>` của trang Mercari, không lưu cả trang).
3. `Store+Share.swift`: ghi `share.json` (gọi cùng chỗ với widget snapshot), `takeSharedEntries()` lúc launch / active, `ShareInboxTests`.
4. Target `MochiShare` (`com.hoangtuan.mochi.share`, App Group `group.com.hoangtuan.mochi`): `ShareViewController` → `UIHostingController(ShareSheetView)`. Synchronized folder `MochiShare/`; DesignSystem, `ListingReader`, `SharedEntry` được thêm vào target qua membership exception (cần sửa pbxproj một lần).
5. Settings › Your data: công tắc "Read links you share".
6. Canvas: artboard `ShareItem`, `ShareItemReading`, `ShareItemFailed` (mỗi cái có bản Dark) + sửa artboard Your data (`Export`). Rồi code view, String Catalog, CLAUDE.md, decisions.md #39.
7. `MoneyField` lấy tiền của sổ từ `\.bookCurrency` thay vì `Store`; `KeyboardDismiss` có nhánh `SHARE_EXTENSION` (extension không có `UIApplication.shared`).

## Testing approach

- Unit `ListingReaderTests`: Mercari meta → 105000 / tên bỏ đuôi / Mercari; chỉ có JSON-LD → vẫn ra giá; không có giá → nil; USD → price nil; `<title>` dự phòng; HTML rác → Listing rỗng, không crash.
- `ShareInboxTests` (today cố định, sổ có `ledgerStart`): Keep → 1 item + 1 asset tx trên đúng thẻ; Spend → 1 tx `needsReview`; cùng file nhận hai lần → 1 món; mua trước `ledgerStart` → item, không có tx.
- Manual: simulator, Safari mở trang Mercari → Share → Mochi; máy thật với app Mercari (để biết Mercari share URL hay text, có link rút gọn không); bật Airplane mode; tắt công tắc.

## Acceptance criteria

- [x] Given trang item Mercari, when Share → Mochi, then tên (không có "by メルカリ") và giá được điền trong ≤ 2 s khi có mạng.
- [x] Given đã Save ở chế độ To use, when mở Mochi, then món có ở Belongings và dòng "Belonging · not spending" có ở Transactions, trên đúng thẻ.
- [x] Given Just a spend, when mở Mochi, then một spend nằm ở To review và **không** có belonging.
- [x] Given offline hoặc trang không có giá, then ô giá trống, Save tắt tới khi gõ giá, và **không** có giá đoán.
- [ ] Given `lookUpListings` tắt, then extension **không** gửi request nào.
- [x] Given cùng một entry bị nhận hai lần, then sổ **không** có món trùng.

## Câu hỏi đã chốt

1. Tài khoản bị xoá trước khi app nhận entry: món vào sổ **không có tài khoản**, không đoán. Không đưa vào To review: To review là danh sách giao dịch, còn món này không có giao dịch nào; sửa tài khoản trên trang của món sẽ tạo giao dịch (`syncPurchase`).
2. "To sell": `estimatedPrice` mặc định = giá mua (giống thêm tay).

## Đã kiểm / chưa kiểm

- Simulator (iOS 26.5, Safari): trang Mercari thật → Share → Mochi → tên, giá, shop, ảnh điền đúng; Save → mở Mochi → món ở Belongings, dòng "Mercari · Belonging · not spending −¥105,000" ở Transactions. Share lại cùng trang → banner "Already in your book". example.com → "Couldn't read the page", Save tắt. Sáng và tối.
- **Chưa:** app Mercari trên máy thật (share URL hay text, link rút gọn `merc.li`); tắt công tắc "Read links you share" (logic có, chưa bấm thử); Airplane mode.
