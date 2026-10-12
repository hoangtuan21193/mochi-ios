# Màn rộng: iPhone gập và iPad — Design doc

Trạng thái: **đã triển khai** (2026-10-02) · Code: `DesignSystem/Layout.swift` (`AdaptiveColumns`, `readableWidth`), `App/MochiApp.swift` (`RootTabView`) · Canvas: `FoldOuter*`, `FoldInner*`, `iPad*`

## Context and motivation

App chỉ chạy iPhone dọc. Người dùng muốn dùng trên iPhone gập (màn ngoài hẹp, màn trong gần vuông) và iPad. Trên màn rộng, một cột 390 pt kéo giãn ra cả màn thì dòng quá dài, số tiền cách nhãn cả gang tay.

Goals:
- Mọi màn dùng được ở 3 độ rộng: hẹp (≤ 360 pt, màn ngoài), điện thoại thường, rộng (màn trong, iPad).
- Màn rộng: dashboard chia hai cột; danh sách và form giữ độ rộng đọc được (≤ 680 pt), không kéo giãn.
- iPad: 5 tab thành thanh tab nổi ở trên, có nút mở thanh bên (`.sidebarAdaptable`, iOS 18+); xoay ngang được. Mở sẵn thanh bên đã thử: ở iPad dọc nó che nửa màn.

Non-goals (v1):
- Không có màn chi tiết cạnh danh sách (list-detail) cho Transactions/Belongings: bấm vào vẫn push như iPhone.
- Không có nhiều cửa sổ, không có menu bàn phím.
- Widget không đổi.

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** không có.
- **Tương thích lưu trữ:** không có field mới.
- Chia theo `horizontalSizeClass`, không theo kích thước máy: Apple chưa công bố số đo iPhone gập, và iPad chia đôi màn hình thì về lại compact. Compact = layout iPhone hiện tại; regular = hai cột.

| Lựa chọn | Được | Mất |
|---|---|---|
| Viết riêng màn iPad cho từng tab | Tối ưu từng màn | Gấp đôi code, hai bên lệch nhau |
| **Một layout, đổi theo size class (chọn)** | Một code; màn hẹp, màn rộng cùng một nguồn | Màn rộng chỉ là hai cột, không có list-detail |
| iPad: `NavigationSplitView` tự làm | Có cột thứ ba | Phải viết lại điều hướng của 5 tab |
| **iPad: `TabView` `.sidebarAdaptable` (chọn, iOS 18+)** | Hệ thống tự đổi tab ↔ sidebar | iOS 17 trên iPad vẫn thấy thanh tab |

## High-level behavior

1. `AdaptiveColumns { trái } trailing: { phải }`: compact → một cột (trái rồi phải); regular → hai cột cạnh nhau, mỗi cột tự cao.
2. `.readableWidth()`: regular → nội dung tối đa 680 pt, căn giữa; compact không đổi.
3. Chia cột theo câu hỏi: cột trái là "cần làm gì bây giờ", cột phải là "sắp tới / tổng quan".
   - Home: thẻ phải trả, Safe to spend, nút nhập | Coming up, 4 ô số.
   - Wallet: net worth, tài khoản, điểm | thẻ, kế hoạch trả góp, người, đầu tư.
   - Belongings: Buy advice, số liệu, bộ lọc | danh sách món (hai cột trên iPad ngang).
   - Plan: Budget/Goals/Recurring giữ một cột đọc được.
   - Buy advice: 3 câu hỏi | kết quả, giá shop đòi.
   - Transactions, Spending, Net worth, Settings, mọi sheet: một cột đọc được.
4. Màn ngoài hẹp (≤ 360 pt): layout iPhone; dòng dài xuống dòng thay vì cắt.

## Test

- Build cho iPhone và iPad simulator; chụp mỗi tab ở iPhone 17 Pro, iPad ngang, iPad dọc.
- design-check so với các artboard `FoldInner*` / `iPad*`.
