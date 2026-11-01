# Màn rộng: iPhone gập và iPad — Design doc

Trạng thái: **đã triển khai** (2026-10-02, làm lại 2026-10-25 theo decision #41) · Code: `DesignSystem/Layout.swift` (`AdaptiveColumns`, `ListDetail`, `readableWidth`, `wideSheet`), `DesignSystem/Containers.swift` (`SheetScaffold` trong cột), `App/MochiApp.swift` (`RootTabView`) · Canvas: `iPad*` (ngang), `iPad*Portrait` (dọc), `FoldInner*`, `FoldOuter*` · Plan: `.planboard/wide-layout/`

## Context and motivation

App chạy trên iPhone, iPhone gập (màn ngoài hẹp, màn trong gần vuông) và iPad. Bản đầu (2026-10-02) chỉ chia 2 cột ở các màn tổng quan; danh sách và form là một cột 680 pt giữa màn. Người dùng thấy phí chỗ: trên iPad và máy gập mở, mọi màn phải có ít nhất 2 cột, cả khi dọc lẫn ngang, theo cách các app của Apple làm (Mail, Notes, Cài đặt).

Goals:
- Mọi màn dùng được ở 3 độ rộng: hẹp (màn ngoài), điện thoại, rộng (màn trong, iPad dọc và ngang).
- Rộng: mọi màn ít nhất 2 cột. Danh sách mở dòng đang chọn bên cạnh, không đẩy sang màn khác.
- iPhone không đổi.

Non-goals:
- Không có nhiều cửa sổ, không có menu bàn phím.
- Widget không đổi.

## Implementation considerations

- **Thứ đã bị bỏ liên quan:** quy tắc "danh sách và form giữ một cột đọc được" (bản 2026-10-02). Mở sẵn thanh bên: ở iPad dọc nó che nửa màn, nên thanh tab vẫn ở trên cùng.
- **Tương thích lưu trữ:** không có field mới.
- Chia theo `horizontalSizeClass`, không theo máy: iPad chia màn hẹp về compact và dùng bố cục iPhone, giống app của Apple.

| Lựa chọn | Được | Mất |
|---|---|---|
| `NavigationSplitView` cho từng tab | Đúng API của Apple | Phải viết lại điều hướng của 5 tab; ở dọc cột trái thành lớp phủ |
| **`ListDetail` tự dựng trong `NavigationStack` của tab (chọn)** | Hai cột luôn hiện ở dọc lẫn ngang; điện thoại giữ nguyên đường đi | Trang mở trong cột phải không có thanh điều hướng riêng: tự vẽ hàng tiêu đề |
| Mọi form 2 cột toàn màn | Một kiểu | Form 4 ô cũng phải chia đôi |
| **Form ngắn 1 cột trong form sheet; form có ảnh hoặc dài 2 cột trong sheet cỡ trang (chọn)** | Đúng cách Apple | Hai kiểu sheet |

## High-level behavior

1. `AdaptiveColumns { trái } trailing: { phải }`: compact → một cột (trái rồi phải, nên thứ tự trên điện thoại là đọc hai cột từ trên xuống); regular → hai cột, mỗi cột tự cao. Trong cột của `ListDetail` hoặc sheet đã đo (`measuresPaneWidth`), dưới 720 pt vẫn là một cột.
2. `ListDetail { danh sách } detail: { chi tiết }`: danh sách 42% bề ngang (340–460 pt), chi tiết phần còn lại, mỗi bên cuộn riêng. Chưa chọn dòng nào: `DetailPlaceholder` hoặc phần tổng quan.
3. Từng màn:
   - Home: thẻ phải trả, nút nhập | 4 ô số.
   - Transactions: danh sách | giao dịch đang chọn (form sửa ngay đó). Spending: chỗ tiền đi | so sánh 6 tháng.
   - Wallet: Net worth, Accounts, Invested | Cards and plans; không có ba tab.
   - Belongings: chip, search, danh sách | món đang chọn (tự 2 cột khi cột ≥ 720 pt); chưa chọn: Buy advice và các ô số.
   - Plan: Budget, Goals | Recurring; không có chọn phần.
   - Settings: menu (các trang và cấu hình của sổ) | trang đang chọn.
   - Net worth: ô số, đường | có và nợ. Profit: năm và cột | từng tháng, các vụ. People, Investments: tổng | danh sách.
   - Check and save: ảnh hoá đơn | các trường. Thêm/sửa món: mua | bán và thuộc tính. Import items: dán sheet | xem trước.
   - Form ngắn (thẻ, ví, giao dịch mới…): một cột trong form sheet.
4. Màn ngoài hẹp (≤ 360 pt): bố cục iPhone; dòng dài xuống dòng thay vì cắt.

## Test

- Build cho iPhone và iPad simulator; chụp mỗi tab ở iPad dọc và ngang, iPhone 17.
- design-check so với các artboard `iPad*`, `iPad*Portrait`, `FoldInner*`.
