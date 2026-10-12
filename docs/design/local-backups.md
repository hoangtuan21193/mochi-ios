# Backup cục bộ — Design doc

Trạng thái: **đã triển khai** · Code: `Store.save/load/replaceBook/exportBookFile` · UI: Settings → Backups, Data

## Context and motivation

Toggle "iCloud backup" cũ chưa bao giờ ghi gì — app không có iCloud container — và đã làm mất một book. Một bản build lỗi hay một lần import sai không được phép xoá bản sao duy nhất.

Goals:
- Mỗi ngày có thay đổi → một bản sao của book **trước** lần ghi đầu tiên trong ngày.
- File không đọc được không bao giờ bị ghi đè.
- Người dùng tự đưa book ra ngoài (Files, AirDrop, iCloud Drive) và mang vào lại.

Non-goals (v1):
- iCloud / CloudKit, đồng bộ nhiều máy.
- Mã hoá file.
- Merge hai book.

## Implementation considerations

- Không entitlements. `autoBackup` / `lastBackup` là field chết, giữ để decode.
- Application Support **không tự tạo** trên iOS; ghi mà chưa tạo thì fail im lặng → book reset mỗi lần mở. `localURL` tạo thư mục trước.
- `save()` bỏ qua khi blob giống lần ghi trước → form phát lại giá trị cũ không tạo bản sao rác.

## High-level behavior

| Sự kiện | Hành vi |
|---|---|
| `save()` lần đầu trong ngày | copy `mochi.json` → `backups/mochi-YYYY-MM-DD.json`, rồi ghi atomic |
| `save()` lần sau trong ngày | chỉ ghi |
| Quá 30 bản | xoá bản cũ nhất |
| `load()` lỗi decode | copy sang `mochi.unreadable.json` (nếu chưa có), `loadFailed = true`, báo lỗi, giữ book trong bộ nhớ |
| Settings → Export | `exportBookFile()` → file tạm `mochi-book-YYYY-MM-DD.json` → share sheet |
| Settings → Import / Earlier copies | `replaceBook(with:)`: copy book hiện tại vào `mochi-YYYY-MM-DD-HHmm.json` rồi thay |

## Error handling and UX

- `saveError` hiện trên UI: không tạo được thư mục, không ghi được, không đọc được.
- File chọn không phải book Mochi → `replaceBook` trả `false`, book không đổi.
- Thay book: có bản timestamp nên chọn nhầm vẫn quay lại được bằng cùng đường đó.

## Future-proofing

- Có iCloud container sau này: `backupsDirectory` là điểm đổi duy nhất.
- `schemaVersion` cho phép một build sau biết đang đọc hình dạng nào.

## Testing approach

- Unit: `CompatibilityTests.version1BookDecodes`, `currentBookRoundTrips`.
- Manual: sửa một thứ → kiểm tra thư mục `backups/` trong container simulator; ghi rác vào `mochi.json` → mở app → có `mochi.unreadable.json`.

## Acceptance criteria

- [ ] Given hôm nay chưa có backup, when sửa một số dư, then `backups/mochi-<hôm nay>.json` chứa book **trước** khi sửa.
- [ ] Given đã có backup hôm nay, when sửa lần nữa, then không tạo file mới.
- [ ] Given 31 bản, then còn 30.
- [ ] Given `mochi.json` hỏng, when mở app, then `mochi.unreadable.json` tồn tại và giống file hỏng, UI báo lỗi.
- [ ] Given chọn file không phải book, when Import, then book không đổi.
