# BUSINESS CENTRAL FILE ARCHIVING TO SHAREPOINT - TEST EXECUTION REPORT

- **Environment:** Business Central Cloud Sandbox (`June9`)
- **Tenant ID:** `19f16416-6c91-4c4b-8d75-43a20b8e8f13`
- **Application Version:** Dynamics 365 Business Central v28
- **Extension ID:** `630cf308-d773-4b52-89d6-cfbee3e2416d` (Version 1.0.0.0)
- **Object ID Range:** `50140 .. 50189`
- **Executed Date:** 2026-10-28

---

## 1. Test Summary Overview

| Test Case | Description | Scope | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Chế độ Preview / Dry-Run Scanner | Table 1173, Table 133, T50141, T50142 | Quét thống kê file, tạo queue Draft, không xóa/upload | Quét thành công 175 tệp (195.87 MB), tạo queue Draft, ghi Audit Log | **PASSED** |
| **TC-02** | Upload file nhỏ thông thường ($\le 4$ MB) | Graph API Simple PUT, Table 50143 | Upload vào folder `Company/Type/No/`, byte-exact verification | *Chờ thực hiện (Bước 2/3)* | *Pending* |
| **TC-03** | Resumable Chunked Upload ($> 4$ MB) | Graph Upload Session (Chunk 4MB) | Upload file lớn theo chunk, đối soát size | *Chờ thực hiện* | *Pending* |
| **TC-04** | Sanitize ký tự cấm & URL dài | SP Archive Graph Client | Đổi ký tự cấm thành `_`, kiểm soát URL $\le 400$ | Đã phủ code unit logic | *Pending* |
| **TC-05** | Mở link từ giao diện BC | PageExt 1173, 193, 194 | Action `Open from SharePoint` mở tab trình duyệt | *Chờ thực hiện sau TC-02* | *Pending* |

---

## 2. Chi Tiết Thực Thi Kịch Bản TC-01: Preview / Dry-Run Scanner

### 2.1. Mục Tiêu Kiểm Thử
- Xác minh `Codeunit 50140 "Archive Dry-Run Scanner"` quét chính xác qua các bảng:
  - Table 1173 (`Document Attachment`)
  - Table 133 (`Incoming Document Attachment`)
- Kiểm tra tính toán `Deterministic Archive Key` và `File Hash / Checksum` (SHA-256).
- Đảm bảo tính toàn vẹn: Không thực hiện bất kỳ lệnh upload hay xóa/purge nào trên Business Central.

### 2.2. Dữ Liệu & Kết Quả Ghi Nhận Thực Tế
- **Thời gian chạy:** 2026-10-28 10:13:xx
- **Pháp nhân (Company):** `APSS-SG`
- **Ngày Cut-Off:** `10/28/2026`
- **Tổng số tệp thỏa điều kiện:** **175 tệp**
- **Tổng dung lượng dự kiến giải phóng:** **195.87 MB** (205,385,182 bytes)
- **Hộp thoại Dialog:** Hiển thị thông báo tổng kết đầy đủ và cảnh báo an toàn rõ ràng:
  > *"Preview / Dry-Run hoàn tất:*
  > *- Tổng số tệp thỏa điều kiện: 175*
  > *- Tổng dung lượng dự kiến giải phóng: 195.87 MB*
  > *- Ngày Cut-off: 10/28/26*
  > *(Lưu ý: Chế độ Dry-Run chỉ quét thống kê, không upload và không xóa bất kỳ dữ liệu nào trên BC)."*

### 2.3. Kiểm Chứng Dữ Liệu Trên Giao Diện (Data Inspection)
1. **SharePoint Archive Queue (Page 50141):**
   - Đã sinh đủ 175 bản ghi từ `Entry No. 1` đến `175`.
   - Phủ đủ các nguồn dữ liệu thực tế:
     - `Source Table ID 133`: Các chứng từ thanh toán/đầu vào (e.g. `OCBC Velocity.pdf` - 76,471 bytes; `PMT-NTRA...` - 77,318 bytes).
     - `Source Table ID 1173`: Các báo giá/đơn hàng (`QUOTE`, `ORDER`, e.g. `mailchimp-receipt.pdf` - 28,348 bytes; `59401906...pdf` - 590,153 bytes; các file ảnh `.jpg` dung lượng từ 1.25 MB đến 3.11 MB).
   - `Archive Status`: `Draft / Preview` (Đúng chuẩn, chưa đẩy vào pipeline upload).
   - `Purge Status`: `Not Eligible` (**Khóa cứng 100%**, không cho phép xóa).
   - `Is Dry Run Record`: `Yes` (Được gắn cờ rõ ràng).

2. **SharePoint Archive Audit Logs (Page 50142):**
   - `Log Entry No.`: 1
   - `Queue Entry No.`: 0 (Mức tổng thể đợt quét)
   - `Company Name`: `APSS-SG`
   - `Action Type`: `Dry Run`
   - `Old Status`: *(trống)* $\rightarrow$ `New Status`: `Draft / Preview`
   - `Log Message`: *"Preview scan completed: 175 eligible files, 205385182 bytes evaluated. Cut-Off Date: 10/28/26..."*

### 2.4. Đánh Giá & Kết Luận
- **Kết quả:** **ĐẠT (PASSED 100%)**.
- Toàn bộ cơ chế quét đa nguồn, tính toán dung lượng, cơ chế ghi nhận queue và ghi vết audit log hoạt động chính xác theo đúng tài liệu đặc tả kiến trúc.
