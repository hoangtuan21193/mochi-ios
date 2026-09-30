<!--
Khung design doc cho Mochi — cỡ L trong docs/sdlc.md.
Copy sang docs/design/<feature>.md. Bỏ section không cần, thêm section riêng nếu cần.
Mục tiêu: đọc hết trong 5 phút. Bullet và bảng, không đoạn văn quá 3–4 dòng.
Xoá các comment hướng dẫn khi viết xong.
-->

# <Tên feature> — Design doc

Trạng thái: **nháp** | duyệt | đã triển khai · Code: `<file / hàm>` · Test: `<suite>`

## Context and motivation

<!-- 1–2 câu nêu vấn đề. Vì sao làm bây giờ. -->

Goals:
- <!-- kết quả đo được, không phải task -->

Non-goals (v1):
- <!-- chặn scope creep — quan trọng ngang goals -->

## Nằm ở màn hình nào

<!-- Mỗi con số sống ở đúng một màn hình (docs/product.md). Xoá section nếu không có con số mới. -->

| Con số / UI | Màn hình | Vì sao ở đó (thì: tương lai / hiện tại / quá khứ) |
|---|---|---|
| | | |

## Implementation considerations

<!-- Constraint, principle, trade-off kèm lý do. Kiểm tra docs/decisions.md trước. -->

- **Thứ đã bị bỏ liên quan:** <!-- mục nào trong decisions.md, hoặc "không có" -->
- **Tương thích lưu trữ:** <!-- field mới? Optional hay decodeIfPresent ?? default? -->

| Lựa chọn | Được | Mất |
|---|---|---|
| A | | |
| **B (chọn)** | | |

## High-level behavior

<!-- End-to-end, cho người mới đọc hiểu. Bullet mỗi bước. Cả happy path lẫn edge case. -->

1.
2.

## Công thức (nếu có)

<!-- Mọi con số mới: hàm trong Finance, chỉ nhận AppData + Date. -->

```swift
static func <tên>(_ data: AppData, today: Date = .now) -> Int
// = <công thức bằng chữ>
```

- Đếm: <!-- … -->
- **Không** đếm: <!-- điểm? khoản vay đồng? recurring tương lai? -->

## Dữ liệu lưu trữ (nếu có)

| Field | Kiểu | Mặc định khi book cũ không có | Ghi ở |
|---|---|---|---|
| | `T?` | `nil` | `Models/<file>.swift` |

## Ledger & undo

- Tiền di chuyển? → `LedgerEntry` kind `<…>`.
- Undo trả lại: <!-- chính xác những gì thao tác đã lấy -->

## Error handling and UX

| Loại | Ví dụ | Xử lý / copy |
|---|---|---|
| Người dùng nhập sai | | |
| Hệ thống | | |

- Dòng preview trước nút: <!-- "¥30,000 goes onto card debt now · in 5 days" -->
- Thao tác phá huỷ: alert nói gì?

## Future-proofing

<!-- Chỉ ghi thứ đã nghĩ tới thật. -->

## Implementation outline

1. Models + decode tương thích
2. `Finance` + test
3. `Store` property / action + ledger + undo
4. View (component `DesignSystem/`, không phép tính)
5. String Catalog, `CLAUDE.md` / `docs/` cập nhật

## Testing approach

- Unit (`FinanceTests`, today cố định):
- Integration (`Store`):
- Manual (`-demo 1 -tab N`):

## Acceptance criteria

<!-- Given / When / Then, test được, có case âm. Map về High-level behavior. -->

- [ ] Given …, when …, then …
- [ ] Given …, when …, then **không** …
