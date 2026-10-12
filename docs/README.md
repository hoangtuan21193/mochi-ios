# Mochi — tài liệu

App tài chính cá nhân cho người ở Nhật mua đồ rồi bán lại (máy ảnh, điện thoại, áo mặc thử…) và cả chi tiêu gia đình quanh nó: đang giữ gì, bán được bao nhiêu, thẻ và trả góp còn nợ bao nhiêu, tiền mặt có đủ trả kỳ tới không.

Mỗi file đọc hết trong 5 phút. Template trong `templates/` sửa thoải mái.

## Đọc gì, khi nào

| Bạn đang… | Đọc |
|---|---|
| Mới vào, cần hiểu app làm gì | [why.md](why.md), rồi [product.md](product.md) |
| Bắt đầu một thay đổi (người hoặc agent) | [sdlc.md](sdlc.md) |
| Sửa code, cần biết lớp nào làm gì | [architecture.md](architecture.md) |
| Đụng tới một con số trên màn hình | [finance-engine.md](finance-engine.md) |
| Viết test / verify trước khi xong | [testing.md](testing.md) |
| Định thêm lại thứ đã bị bỏ | [decisions.md](decisions.md) — **đọc trước** |
| Quyết định hướng sản phẩm, giá, thị trường | [research/2026-09-market.md](research/2026-09-market.md) |
| Viết design doc cho feature mới | [templates/design-doc.md](templates/design-doc.md) |

## Cấu trúc

```
docs/
  README.md             mục lục (file này)
  sdlc.md               quy trình phát triển AI-native: phase, gate, Definition of Done
  product.md            vấn đề, người dùng, goals / non-goals, 5 màn hình, thuật ngữ
  architecture.md       Models → Finance → Store → Views, lưu trữ, backup, tương thích
  finance-engine.md     mọi công thức: 4 con số, chu kỳ thẻ, trả góp, điểm, snapshot
  testing.md            chiến lược test, lệnh build/test, checklist kiểm tay
  decisions.md          nhật ký quyết định (ADR-lite): cái gì đã bỏ và vì sao
  design/               design doc từng feature (viết theo template)
    sheet-import.md
    card-cycle.md
    local-backups.md
  roadmap.md            16 tính năng đã chọn, thứ tự phase, rủi ro
  research/             nghiên cứu thị trường, pháp lý, đối thủ (có ngày, có nguồn)
    2026-09-market.md
    2026-09-user-pains.md
  templates/            khung để copy
    design-doc.md
    task-brief.md
    decision.md
```

## Nguồn sự thật — thứ tự ưu tiên

1. **Code + test** — `Finance.swift` và `FinanceTests` quyết định con số đúng.
2. **`CLAUDE.md`** (gốc repo) — luật bắt buộc cho agent và người. Mâu thuẫn với `docs/` thì `CLAUDE.md` thắng, rồi sửa `docs/`.
3. **`design.md`** (gốc repo) — design system "Organic", component catalogue.
4. **`docs/`** — giải thích *vì sao*, quy trình, design doc từng feature.

`docs/` không chép lại `CLAUDE.md` / `design.md`; nó trỏ tới và bổ sung.

## Quy ước viết

- Tiếng Việt, giữ nguyên tên type / hàm / màn hình / chuỗi UI bằng tiếng Anh.
- Bullet và bảng thay đoạn văn. Đoạn văn tối đa 3–4 dòng.
- Con số cụ thể: "giữ 30 bản", không phải "giữ một ít bản".
- Tham chiếu code dạng `Finance.safeToSpend`, `Store.commitImport`.
- Doc lỗi thời là bug: đổi rule trong code thì sửa doc trong cùng thay đổi.
