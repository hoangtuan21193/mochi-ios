# Cài đặt Xcode cho máy thật

Simulator chạy được ngay. Máy thật cần team và ba capability. Làm một lần.

## 1. Team và bundle id

| Target | Bundle id | Entitlements |
|---|---|---|
| Mochi | `com.hoangtuan.mochi` | `Resources/Mochi.entitlements` (App Group) · `Resources/Mochi-iCloud.entitlements` (App Group + iCloud, chỉ team trả phí) |
| MochiWidgets | `com.hoangtuan.mochi.widgets` | `Resources/MochiWidgets.entitlements` |

- Xcode → target → Signing & Capabilities → chọn Team cho **cả hai** target.
- Đổi bundle id thì đổi cả App Group và container bên dưới, và `CloudSync.containerID`, `WidgetSnapshot` group id trong code.

## 2. App Group (widget đọc Safe to spend)

- Cả hai target: + Capability → App Groups → `group.com.hoangtuan.mochi`.
- App ghi `widget.json` vào group mỗi lần save; widget chỉ đọc file đó, không mở sổ.
- Thiếu group: widget hiện "Open Mochi once".

## 3. iCloud (chia sẻ sổ — tắt mặc định)

**Team cá nhân (Apple ID miễn phí) không có iCloud**: Xcode báo "Personal development teams … do not support the iCloud capability". Vì vậy `Mochi.entitlements` không có iCloud, app vẫn ký và chạy được trên máy; chỉ phần chia sẻ sổ không có. Khi có Apple Developer Program:

0. Build Settings của target Mochi → `CODE_SIGN_ENTITLEMENTS` = `Resources/Mochi-iCloud.entitlements`.
1. Target Mochi: + Capability → iCloud → CloudKit → container `iCloud.com.hoangtuan.mochi`.
2. Chạy một lần trên máy thật đã đăng nhập iCloud để tạo schema (record type `Book`, zone `Book`).
3. CloudKit Console: deploy schema lên Production trước khi phát hành.
4. Bật: thêm vào `Resources/Info.plist`
   ```xml
   <key>MochiCloudSyncEnabled</key><true/>
   ```
- **Bật cờ mà chưa có entitlement iCloud thì app crash** khi chạm CloudKit — hai thứ đi cùng nhau.
- Chưa bật cờ → `CloudSync.isEnabled` false, Household nói "not invited yet", không gọi mạng.

## 4. Apple Pay → To review (người dùng tự làm trên máy)

1. Shortcuts → Automation → + → **Transaction** (Wallet) → chọn thẻ → Run immediately.
2. Action: **Log an Apple Pay payment** (Mochi). Amount = Amount, Merchant = Merchant, Card = Card.
3. Mỗi lần chạm Apple Pay: giao dịch vào To review, luật tự điền category.

## 5. Kiểm tra

- Widget: giữ màn hình chính → + → Mochi → Safe to spend.
- Siri: "How much can I spend in Mochi".
- Control Center (iOS 18+): nút Scan receipt.
- Thông báo: Settings → Notifications → bật; iOS hỏi quyền lần đầu.
