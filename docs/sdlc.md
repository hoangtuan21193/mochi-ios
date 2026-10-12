# Quy trình phát triển — AI-native SDLC

Mochi được viết chủ yếu bởi AI agent (Claude Code), người giữ quyết định. Quy trình này nói ai làm gì ở mỗi bước, bước nào phải có tài liệu, và khi nào một thay đổi được coi là xong.

## Nguyên tắc

- **Người quyết, agent làm.** Người chốt *cái gì* và *vì sao*; agent đề xuất *làm thế nào*, viết code, tự verify.
- **Context là code.** Agent chỉ giỏi bằng context nó đọc: `CLAUDE.md`, `design.md`, `docs/`. Một rule chỉ nằm trong đầu người là rule sẽ bị vi phạm.
- **Spec trước, code sau.** Thay đổi đụng tới con số, dữ liệu lưu trữ, hay một rule → có design doc hoặc task brief trước khi code.
- **Bước nhỏ, verify từng bước.** Sửa → build → test → screenshot → bước tiếp. Không gom 5 màn hình rồi build một lần.
- **Học một lần, ghi lại mãi.** Mỗi lần agent sai hoặc một thứ bị bỏ, ghi vào `decisions.md` hoặc `CLAUDE.md` để không lặp lại.

## Kích cỡ thay đổi quyết định tài liệu

| Cỡ | Ví dụ | Tài liệu bắt buộc |
|---|---|---|
| **S** | sửa copy, căn lề, bug 1 file | không — mô tả trong prompt là đủ |
| **M** | thêm field vào form, đổi sort, màn hình con | [task brief](templates/task-brief.md) (trong prompt hoặc file) |
| **L** | công thức mới trong `Finance`, field lưu trữ mới, màn hình mới, đổi rule trong `CLAUDE.md` | [design doc](templates/design-doc.md) trong `docs/design/` |

Không chắc cỡ nào → chọn cỡ lớn hơn.

## Các phase

| # | Phase | Người | Agent | Artefact | Gate (qua được khi) |
|---|---|---|---|---|---|
| 1 | **Intake** | mô tả vấn đề / mong muốn | đánh giá trước, **chưa sửa** | câu trả lời đánh giá | người nói "làm đi" |
| 2 | **Frame** | chốt goals / non-goals | viết task brief hoặc design doc | `docs/design/<feature>.md` | người duyệt doc |
| 3 | **Plan** | — | chia bước, liệt kê file đụng tới, đọc `decisions.md` | plan trong session | không đụng thứ đã bị bỏ |
| 4 | **Build** | — | code theo thứ tự lớp (xem dưới) | diff | build sạch, 0 warning trong `Mochi/` |
| 5 | **Verify** | — | test + chạy simulator + screenshot | output test, ảnh | mục Definition of Done đủ |
| 6 | **Review** | đọc diff, thử trên máy | tự review theo checklist, `/code-review` | danh sách finding | không còn finding nghiêm trọng |
| 7 | **Ship** | yêu cầu commit | commit (chỉ khi được yêu cầu) | commit | message tả thay đổi người dùng thấy |
| 8 | **Learn** | xác nhận bài học | cập nhật `CLAUDE.md` / `docs/` / `decisions.md` | diff tài liệu | doc khớp code |

### 1. Intake — đánh giá trước, sửa sau

- Người mô tả *vấn đề* → agent trả lời bằng đánh giá (nguyên nhân, lựa chọn, đề xuất). Sửa khi được yêu cầu.
- Người yêu cầu *thay đổi* → agent làm trọn thay đổi, rồi báo: đã làm gì, đã test gì, chưa test gì.

### 2. Frame — viết để chặn scope creep

- Non-goals quan trọng ngang goals.
- Acceptance criteria dạng "Given / When / Then" với **một "today" cố định** — Finance luôn test được như vậy.
- Kiểm tra với [product.md](product.md): con số này thuộc màn hình nào? Mỗi con số sống ở đúng **một** màn hình.

### 3. Plan — đọc trước khi đề xuất

Agent đọc theo thứ tự, trước khi viết dòng code đầu tiên:

1. `CLAUDE.md` — non-negotiables, domain facts.
2. `docs/decisions.md` — thứ đã thử và bỏ (biểu đồ số dư, màn hình Activity, iCloud…).
3. `design.md` nếu đụng view.
4. Design doc của feature, nếu có.

### 4. Build — thứ tự lớp

```
Models  →  Finance (+ test)  →  Store (property / action)  →  View
```

- Công thức mới: vào `Finance` **kèm test** trước khi có property trong `Store`.
- Field lưu trữ mới: Optional hoặc `decodeIfPresent ?? default`, thêm vào fixture `version1BookDecodes`.
- Mỗi lần tiền di chuyển: `Store.log` một `LedgerEntry`.
- View chỉ đọc `store.x`, gọi `store.doY()`. Không tính toán trong view.

### 5. Verify — xem [testing.md](testing.md)

### 6. Review — checklist nhanh

- [ ] Không `.font(.system(size:))`, `Color(hex:)`, chrome vẽ tay trong view
- [ ] Không phép tính tiền trong view
- [ ] Field mới decode được book cũ
- [ ] Undo trả lại đúng thứ đã lấy
- [ ] Nút phá huỷ đi qua `.alert`; form kết thúc bằng dòng preview
- [ ] Không có menu một lựa chọn, picker một chip
- [ ] Chuỗi UI tiếng Anh, sentence case; bản dịch vào String Catalog
- [ ] Comment giải thích *vì sao*

### 7–8. Ship & Learn

- Commit chỉ khi người yêu cầu. Message tả thay đổi người dùng thấy, không liệt kê file.
- Agent sai vì thiếu context → thêm một dòng vào `CLAUDE.md` (luật) hoặc `decisions.md` (lịch sử).

## Agent phải dừng và hỏi khi

- Yêu cầu mâu thuẫn với một non-negotiable trong `CLAUDE.md`.
- Sắp đưa lại thứ có trong `decisions.md` mục "Đã bỏ".
- Đổi tên key lưu trữ, hay xoá field lưu trữ.
- Thiếu con số cụ thể để viết acceptance criteria — không bịa.
- Thao tác khó đảo ngược: xoá dữ liệu simulator ngoài `-demo 1`, force push, commit khi chưa được yêu cầu.

## Definition of Done

Một thay đổi xong khi **tất cả** đúng:

- [ ] Build Debug sạch, 0 warning trong `Mochi/`
- [ ] `FinanceTests` + `ImportOldSheetTests` pass
- [ ] Rule đổi → có test nói điều đó
- [ ] Đổi UI → đã chạy `-demo 1` trên simulator và nhìn màn hình đã sửa
- [ ] Field lưu trữ mới → `version1BookDecodes` cập nhật và pass
- [ ] `CLAUDE.md` / `docs/` khớp code
- [ ] Báo cáo cuối: đã làm, đã test, **chưa** test

## Tầng context cho agent

| Tầng | File | Chứa | Đổi khi |
|---|---|---|---|
| Luật | `CLAUDE.md` | non-negotiables, domain facts, lệnh build | rule đổi |
| Hình thức | `design.md` | token, component, anatomy màn hình | thêm component |
| Vì sao | `docs/decisions.md` | quyết định + thứ đã bỏ | một thứ bị bỏ / chọn |
| Feature | `docs/design/*.md` | design doc từng feature | feature đổi hành vi |
| Bằng chứng | `MochiTests/` | con số đúng với "today" cố định | công thức đổi |
