# AutoZoom - Kế hoạch Đồng bộ Thời khóa biểu PTIT (ptit-sync-plan.md)

> **Task Slug:** `ptit-sync-plan`  
> **Nền tảng:** Flutter (iOS 17+ & Android)  
> **Nguồn dữ liệu:** Cổng Quản lý đào tạo Đại học từ xa PTIT (`https://qldttx.pttc1.edu.vn`)  
> **Kiến trúc cốt lõi:** Device Calendar as Source of Truth + Auto-Sync Pipeline + Silent-Bypassing Alarm

---

## 1. 🧠 Brainstorming & Phân tích các giải pháp kỹ thuật

### Bối cảnh bài toán:
Học viên cần theo dõi thời khóa biểu hàng tuần từ cổng đào tạo PTIT (`https://qldttx.pttc1.edu.vn`). Hiện tại, lịch học được chia theo tuần (Tuần 1 đến Tuần 20+), mỗi buổi học có tên môn, nhóm, phòng học, mã giảng viên, giờ học (19:00 - 21:50) và đường link Zoom kèm Passcode (`pttc1`). 
Mục tiêu là tự động cào toàn bộ các tuần trong học kỳ và đưa vào hệ thống AutoZoom để tự động nhắc giờ và vào phòng Zoom mà không cần nhập tay.

---

### Option A: Direct API / Session Fetching (Đồng bộ trực tiếp qua HTTP)
Gửi HTTP request đăng nhập trực tiếp lấy Bearer Token / Session Cookie, sau đó gọi lấy dữ liệu TKB của tất cả các tuần trong học kỳ theo dạng JSON/HTML.

* ✅ **Ưu điểm:**
  - Tốc độ cực nhanh (chỉ mất ~1-2 giây để sync toàn bộ 20 tuần).
  - Hoàn toàn chạy ngầm, không cần mở trình duyệt/WebView.
  - Trải nghiệm người dùng liền mạch (1 nút bấm "Đồng bộ ngay" hoặc tự sync khi mở app).
* ❌ **Nhược điểm:**
  - Nếu trường thay đổi định dạng token hoặc thêm CAPTCHA thì cần cập nhật parser.
* 📊 **Độ phức tạp:** Trung bình (Medium)

---

### Option B: In-App WebView + JS DOM Scraper (Trình duyệt nhúng)
Mở một cửa sổ `InAppWebView` nhúng trong app, tự động điền tài khoản hoặc cho phép người dùng đăng nhập, sau đó inject JavaScript để duyệt qua từng tuần và trích xuất dữ liệu DOM.

* ✅ **Ưu điểm:**
  - Vượt qua được tất cả các cơ chế bảo vệ web, CAPTCHA, 2FA trong tương lai.
  - Người dùng có thể nhìn thấy giao diện web trường trực tiếp nếu muốn kiểm tra.
* ❌ **Nhược điểm:**
  - Tốn tài nguyên hơn (phải khởi tạo Chromium/WebKit engine).
  - Tốc độ duyệt tuần chậm hơn so với gọi HTTP API trực tiếp.
* 📊 **Độ phức tạp:** Trung bình (Medium)

---

### Option C: 🏆 Hybrid Auto-Sync (Khuyên dùng - Recommended)
Kết hợp sức mạnh của cả hai phương pháp:
1. **Mặc định:** Sử dụng **Direct API Client** để đồng bộ nhanh toàn bộ các tuần trong nền.
2. **Fallback:** Nếu trường yêu cầu CAPTCHA hoặc hết hạn phiên phức tạp, tự động mở **In-App WebView** để hỗ trợ xác thực.
3. **Lưu trữ:** Tự động tạo một cuốn lịch riêng mang tên **"Lịch học PTIT"** trên Apple Calendar / Google Calendar của máy (thông qua `device_calendar`). 
4. **Vận hành:** Toàn bộ hệ thống `NotificationReconciler`, `AlarmService`, và `ZoomLauncher` hiện có của AutoZoom sẽ tự động nhận diện và kích hoạt chuông báo thức mà không cần thay đổi kiến trúc cốt lõi.

---

## 2. Kiến trúc & Thiết kế Module mới

```
lib/
├── services/
│   ├── ptit/
│   │   ├── ptit_client.dart               # Quản lý Đăng nhập & Gọi API lấy TKB
│   │   ├── ptit_parser.dart               # Bóc tách TKB tuần, môn học, Zoom URL, ID, Pass
│   │   └── ptit_sync_service.dart         # Điều phối ghi lịch vào Device Calendar
│   │
│   └── calendar/
│       └── device_calendar_service.dart   # (Bổ sung hàm createOrUpdatePTITEvents)
│
├── features/
│   ├── ptit_sync/
│   │   ├── ptit_sync_controller.dart      # Quản lý trạng thái đồng bộ & lưu credentials
│   │   ├── ptit_sync_sheet.dart           # Modal nhập tài khoản & tiến độ đồng bộ các tuần
│   │   └── widgets/
│   │       └── sync_progress_bar.dart     # Hiển thị thanh tiến độ (Tuần 1/20 -> 20/20)
```

---

## 3. Kế hoạch triển khai chi tiết theo từng Phase

### Phase 1: Xây dựng PTIT Client & Parser Engine
- [ ] Tạo `PtitClient`: Quản lý HTTP request đăng nhập với `username` và `password`, duy trì token.
- [ ] Tạo `PtitParser`: Bóc tách cấu trúc thời khóa biểu theo tuần từ web trường:
  - Trích xuất: Tên môn, mã môn, nhóm lớp, giảng viên.
  - Trích xuất: Thứ trong tuần $\rightarrow$ chuyển đổi thành `DateTime` chính xác theo ngày bắt đầu của tuần.
  - Trích xuất: Giờ học (`19:00 - 21:50`).
  - Trích xuất: Zoom ID, Passcode, và link Zoom trực tiếp `https://zoom.us/j/...`.
- [ ] Viết Unit Test cho `PtitParser` với dữ liệu thực tế đã trích xuất (Tuần 1 và Tuần 10).

### Phase 2: Dịch vụ Ghi Lịch vào Device Calendar (PTIT Calendar Sync)
- [ ] Bổ sung tính năng tự động tạo danh mục Calendar `Lịch học PTIT` trên điện thoại nếu chưa có.
- [ ] Cơ chế Idempotent Sync (Chống trùng lặp):
  - Xóa hoặc cập nhật các sự kiện cũ của `Lịch học PTIT`.
  - Ghi toàn bộ các buổi học của học kỳ vào lịch máy với đầy đủ ghi chú Zoom URL & ID phòng.
- [ ] Sau khi ghi xong, kích hoạt `homeControllerProvider.syncCalendar()` để AutoZoom nạp lịch và hẹn giờ chuông báo thức tức thì.

### Phase 3: Giao diện Người dùng (PTIT Sync UI & Settings)
- [ ] Thêm nút **[Đồng bộ TKB PTIT]** trên AppBar / Home Screen.
- [ ] Tạo BottomSheet `PtitSyncSheet`:
  - Form lưu tài khoản `K26DTCN210` (lưu an toàn trong SharedPreferences).
  - Nút **[Bắt đầu đồng bộ tất cả tuần]**.
  - Hiển thị tiến trình: *"Đang đồng bộ Tuần 1.. Tuần 10.. Xong! Đã nạp 24 buổi học vào lịch."*
- [ ] Tùy chọn tự động làm mới lịch mỗi khi mở ứng dụng.

### Phase 4: Kiểm thử & Xác minh chất lượng (Verification)
- [ ] **Unit Tests:** Đảm bảo 100% test case cho PTIT Parser và Reconciler đều PASS.
- [ ] **Acceptance Test:**
  1. Bấm Đồng bộ $\rightarrow$ Ứng dụng nạp toàn bộ các lớp của Tuần 1, Tuần 10 và các tuần còn lại.
  2. Mở ứng dụng Lịch (Apple Calendar trên iPhone) $\rightarrow$ Thấy đầy đủ các buổi học với link Zoom.
  3. Màn hình Home của AutoZoom hiển thị danh sách lớp hôm nay & sắp tới kèm nút bấm vào Zoom 1-chạm.
  4. Đến giờ học $\rightarrow$ Chuông báo thức reo to bỏ qua chế độ im lặng.

---

## 4. Bàn giao & Bước tiếp theo

1. Xem lại bản kế hoạch chi tiết này.
2. Xác nhận phê duyệt để tiến hành triển khai mã nguồn.
