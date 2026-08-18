# Phase 0.5: Real Device Acceptance Test Guide (iOS & Android)

> Mục tiêu: Kiểm thử thực tế các tương tác hệ điều hành (EventKit, Notification lock screen, Zoom app deep link, Background kill) trên iPhone/Android thật mà không thể giả lập hoàn toàn qua Unit Test.

---

## 📋 Checklist 12 Ca Kiểm thử Thực tế (Phase 0.5)

### 1. Calendar Permission (iOS 17+ Full Access & Android)
- [ ] **TC-01 (Lần đầu mở app):** App hiển thị pop-up xin quyền truy cập Lịch với đúng thông điệp: *"AutoZoom cần quyền truy cập lịch để tìm các buổi học và tự động nhắc bạn trước giờ học."*
- [ ] **TC-02 (Từ chối quyền):** Người dùng bấm "Từ chối" $\rightarrow$ App hiển thị `PermissionRequestCard` với nút `[Cho phép truy cập Calendar]` $\rightarrow$ Bấm nút mở đúng trang Cài đặt (Settings) của iOS/Android.
- [ ] **TC-03 (Cấp quyền từ Settings):** Sau khi bật quyền trong Settings và quay lại AutoZoom $\rightarrow$ App tự động phát hiện quyền mới và đồng bộ danh sách lịch.

---

### 2. Đồng bộ Google Calendar qua iPhone Calendar (Zero-OAuth Sync)
- [ ] **TC-04 (Lịch Google sync vào iOS):** Tạo một event trên Google Calendar (web hoặc app Google Calendar).
- [ ] **TC-05 (EventKit đọc):** Mở app Apple Calendar trên iPhone để xác nhận event đã sync về máy $\rightarrow$ Mở AutoZoom $\rightarrow$ Event lớp học hiển thị tức thì trên màn hình Home.

---

### 3. Lọc Calendar (School vs. Personal)
- [ ] **TC-06 (Multi-select):** Vào Settings Sheet $\rightarrow$ Bỏ tích chọn "Personal", chỉ tích chọn "School".
- [ ] **TC-07 (Cách ly dữ liệu):** Các sự kiện cá nhân (như "Ăn trưa", "Họp gia đình") hoàn toàn không xuất hiện trên AutoZoom, chỉ các lớp thuộc calendar "School" có Zoom mới được nạp.

---

### 4. Bóc tách Zoom & Validation (Trực tiếp từ Calendar)
- [ ] **TC-08 (Định dạng URL):** Calendar description có `https://zoom.us/j/123456789?pwd=abc` $\rightarrow$ Card hiển thị đúng ID và nút `[Tham gia Zoom]`.
- [ ] **TC-09 (Định dạng text tiếng Việt):** Calendar description có `ID phòng: 123 456 789 \n Mật khẩu: 123456` $\rightarrow$ Card hiển thị đúng ID và nút `[Tham gia Zoom]`.
- [ ] **TC-10 (Event không có Zoom):** Calendar description chỉ có số điện thoại `0901234567` $\rightarrow$ Bị bỏ qua, không nhận diện nhầm thành Zoom meeting.

---

### 5. Local Notification & Lock-Screen Privacy
- [ ] **TC-11 (Đúng giờ & Bảo mật):** Tạo lớp học lúc `HH:mm` (nhắc trước 10 phút). Đến đúng `HH:mm - 10 phút`, notification xuất hiện trên màn hình khóa.
- [ ] **TC-12 (Không lộ password):** Banner hiển thị `🔔 Sắp đến giờ học: [Tên lớp] - Bắt đầu lúc [HH:mm]` (Mật khẩu KHÔNG xuất hiện trên banner).
- [ ] **TC-13 (Action Buttons):** Notification có 2 nút hành động `[Tham gia ngay]` và `[Bỏ qua]`.

---

### 6. Zoom Launcher & Fallback
- [ ] **TC-14 (Khi đã cài Zoom):** Bấm `[Tham gia ngay]` từ notification hoặc nút trên Card $\rightarrow$ Ứng dụng Zoom mở ra và vào thẳng phòng học mà không bắt nhập lại ID/Pass.
- [ ] **TC-15 (Khi chưa cài Zoom):** Xóa app Zoom $\rightarrow$ Bấm `[Tham gia Zoom]` $\rightarrow$ Safari/Chrome tự động mở link `https://zoom.us/j/...` mà không gây crash app.

---

### 7. Reconciliation (Sửa & Xóa lịch trên Calendar)
- [ ] **TC-16 (Đổi giờ học):** Giáo viên dời lịch từ `08:00` sang `09:00` trên Calendar $\rightarrow$ Mở AutoZoom $\rightarrow$ Notification cũ `07:50` bị hủy, notification mới `08:50` được lên lịch.
- [ ] **TC-17 (Hủy buổi học):** Xóa event trên Calendar $\rightarrow$ Mở AutoZoom $\rightarrow$ Notification của buổi học đó bị hủy ngay lập tức.

---

### 8. Background & App Killed Behavior
- [ ] **TC-18 (App bị tắt hoàn toàn):** Mở AutoZoom để sync lịch $\rightarrow$ Vuốt tắt app hoàn toàn (Kill process) $\rightarrow$ Khóa màn hình $\rightarrow$ Đến giờ hẹn, notification của hệ điều hành vẫn reo chuông và hiển thị bình thường.
