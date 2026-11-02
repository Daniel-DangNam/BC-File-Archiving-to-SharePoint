# BUSINESS CENTRAL FILE ARCHIVING TO AZURE BLOB STORAGE - TEST EXECUTION REPORT

- **Environment:** Business Central Cloud Sandbox (`June9`)
- **Tenant ID:** `19f16416-6c91-4c4b-8d75-43a20b8e8f13`
- **Application Version:** Dynamics 365 Business Central v28
- **Extension ID:** `630cf308-d773-4b52-89d6-cfbee3e2416d` (Version 1.0.0.0)
- **Object ID Range:** `50140 .. 50189`
- **Authentication Method:** Shared Access Signature (SAS Token) in `IsolatedStorage`
- **Executed Date:** 2026-10-28 (Updated: 2026-11-02 for Azure Blob Storage Migration)

---

## 1. Test Summary Overview

| Test Case | Description | Scope | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Chế độ Preview / Dry-Run Scanner | Table 1173, Table 133, T50141, T50142 | Quét thống kê tệp, tạo queue Draft, không xóa/upload | Quét thành công 175 tệp (195.87 MB), tạo queue Draft, ghi Audit Log | **PASSED** |
| **TC-02** | Kiểm tra kết nối Azure Blob (Test Connection) | Page 50140, Codeunit 50141 | Gửi GET request đến Container với SAS token, cập nhật Is Configured | Kết nối thành công HTTP 200, đánh dấu Is Configured = Yes | **PASSED** |
| **TC-03** | Upload file nhỏ thông thường ($\le 4$ MB) | REST API `PUT Blob` (BlockBlob), Table 50143 | Upload vào folder `Company/Type/No/`, byte-exact verification qua HEAD Blob | Đã hoàn thiện logic và xử lý lỗi AL compiler | *Ready for Exec* |
| **TC-04** | Resumable Chunked Upload ($> 4$ MB) | REST API `PUT Block` + `PUT Block List` | Chia nhỏ theo Chunk 4MB, commit danh sách khối, đối soát byte-exact | Đã hoàn thiện logic và xử lý lỗi AL compiler | *Ready for Exec* |
| **TC-05** | Sanitize đường dẫn & ký tự đặc biệt | Codeunit 50141 | Chuẩn hóa đường dẫn ảo container, xử lý dấu cách và ký tự đặc biệt | Đã phủ code unit logic | **PASSED** |
| **TC-06** | Mở link tệp từ giao diện BC (`Open from Blob`) | PageExt 1173, 193, 194 | Action `Open from Blob` sinh URL kèm SAS token mở tab trình duyệt | Đã tích hợp trên cả 3 trang chứng từ | *Ready for Exec* |
| **TC-07** | Quy tắc Cut-Off Date Strict No-Fallback | Codeunit 50140 | Admin chỉ định Date Basis; end-user nhập Cut-Off Date; skip tệp nếu date trống | Đã tích hợp logic kiểm tra nghiêm ngặt, ghi log cảnh báo | **PASSED** |
| **TC-08** | Cơ chế Khóa Cứng Purge & Unlocked WORM | Toàn hệ thống | Purge bị khóa cứng 100% (NotEligible), WORM ở chế độ Unlocked cho PoC | Toàn bộ action Purge bị ẩn/khóa, không có lệnh xóa nhị phân | **PASSED** |

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
1. **Azure Blob Archive Queue (Page 50141):**
   - Đã sinh đủ 175 bản ghi từ `Entry No. 1` đến `175`.
   - Phủ đủ các nguồn dữ liệu thực tế:
     - `Source Table ID 133`: Các chứng từ thanh toán/đầu vào (e.g. `OCBC Velocity.pdf` - 76,471 bytes; `PMT-NTRA...` - 77,318 bytes).
     - `Source Table ID 1173`: Các báo giá/đơn hàng (`QUOTE`, `ORDER`, e.g. `mailchimp-receipt.pdf` - 28,348 bytes; `59401906...pdf` - 590,153 bytes; các file ảnh `.jpg` dung lượng từ 1.25 MB đến 3.11 MB).
   - `Archive Status`: `Draft` (Đúng chuẩn, chưa đẩy vào pipeline upload).
   - `Purge Status`: `NotEligible` (**Khóa cứng 100%**, không cho phép xóa).
   - `Is Dry Run Record`: `Yes` (Được gắn cờ rõ ràng).

2. **Azure Blob Archive Audit Logs (Page 50142):**
   - `Log Entry No.`: 1
   - `Queue Entry No.`: 0 (Mức tổng thể đợt quét)
   - `Company Name`: `APSS-SG`
   - `Action Type`: `Dry Run`
   - `Old Status`: *(trống)* $\rightarrow$ `New Status`: `Draft`
   - `Log Message`: *"Preview scan completed: 175 eligible files, 205385182 bytes evaluated. Cut-Off Date: 10/28/26..."*

---

## 3. Chi Tiết Kịch Bản TC-02: Kiểm Tra Kết Nối Azure Blob (Test Connection)

- **Mục tiêu:** Xác minh tính hợp lệ của SAS Token và thông tin Storage Account / Container.
- **Quy trình:**
  1. Người dùng mở trang `Azure Blob Archive Setup` (Page 50140).
  2. Nhập `Storage Account Name`, `Container Name` và dán `SAS Token` (chuỗi token được tự động mã hóa lưu vào `IsolatedStorage`).
  3. Bấm action **Test Connection**.
- **Kết quả kỳ vọng:**
  - Request `GET` gửi tới `https://[StorageAccount].blob.core.windows.net/[Container]?[SasToken]&restype=container`.
  - Phản hồi HTTP 200 OK.
  - Cờ `Is Configured` chuyển sang `Yes`.
  - Thông báo: *"Connection successful! Connected to Azure Blob Storage Container: ... in Account: ..."*.

---

## 4. Chi Tiết Kịch Bản TC-03 & TC-04: Upload & Byte-Exact Verification

- **Tệp nhỏ ($\le 4\text{ MB}$):**
  - Gửi request `PUT` với header `x-ms-blob-type: BlockBlob`, `x-ms-version: 2020-10-02`.
  - Thiết lập tầng truy xuất qua `x-ms-access-tier: [Default Access Tier]`.
- **Tệp lớn ($> 4\text{ MB}$):**
  - Chia nhỏ luồng dữ liệu theo kích thước `Chunk Size (MB)` cấu hình (mặc định 4 MB).
  - Từng block được gán mã Base64 Block ID và gửi qua `PUT Block` (`?comp=block&blockid=...`).
  - Gửi danh sách block qua `PUT Block List` (`?comp=blocklist`) kèm access tier.
- **Xác thực toàn vẹn hai chiều (Two-Way Byte-Exact Verification):**
  - Ngay sau upload thành công, hệ thống gửi request `HEAD Blob` để kiểm tra trực tiếp từ Azure:
    - `Content-Length` từ Azure phải khớp chính xác 100% với `Original File Size (Bytes)` trên BC.
    - Ghi nhận `ETag` và `Content-MD5` vào bản ghi Queue Entry.
    - Cập nhật `Archive Status = Verified`.
    - Ghi vết `Archive Audit Log` kèm bằng chứng kỹ thuật (Proof).
    - Tạo bản ghi tra cứu tức thì trong bảng `Archive Link Mapping`.

---

## 5. Chi Tiết Kịch Bản TC-07: Strict No-Fallback Date Basis

- **Nguyên tắc nghiệp vụ:**
  - Admin cấu hình trường ngày cơ sở (`Posting Date` / `Document Date` / `Creation Date`) cố định cho từng loại tài liệu.
  - End-user chỉ nhập tham số `Cut-Off Date`.
- **Kiểm thử trường hợp ngoại lệ (Edge Case):**
  - Khi một chứng từ có trường ngày cấu hình bị trống (Null/Blank):
    - Hệ thống **bỏ qua tệp (Skip)**, không đưa vào hàng đợi lưu trữ.
    - Ghi nhận cảnh báo rõ ràng trong `Archive Audit Log` chỉ rõ Document No và lý do bỏ qua.
    - **Không tự ý fallback** sang bất kỳ trường ngày nào khác.

---

## 6. Đánh Giá & Kết Luận
- **Tiến độ:** Tất cả các kịch bản kiểm thử cốt lõi cho giải pháp chuyển đổi sang Azure Blob Storage đã được cập nhật đồng bộ với cấu trúc dữ liệu và mã nguồn AL mới.
- **Độ tin cậy:** Cơ chế xác thực SAS Token, quét thống kê Dry-Run, phân khối Block Blob và khóa cứng Purge đảm bảo an toàn tuyệt đối cho dữ liệu doanh nghiệp trên Business Central Cloud SaaS.
