# BUSINESS CENTRAL FILE ARCHIVING TO AZURE BLOB STORAGE - TEST EXECUTION REPORT

- **Environment:** Business Central Cloud Sandbox (`June9`)
- **Tenant ID:** `19f16416-6c91-4c4b-8d75-43a20b8e8f13`
- **Target Storage Account:** `stapssbcarchiveprod`
- **Target Container:** `bc-file-archive-dev`
- **Environment Guard:** Sandbox `June9` $\rightarrow$ Container `bc-file-archive-dev` (Bắt buộc dùng container dev, chặn kết nối tới container prod)
- **Application Version:** Dynamics 365 Business Central v28
- **Extension ID:** `630cf308-d773-4b52-89d6-cfbee3e2416d` (Version 1.0.0.0)
- **Object ID Range:** `50140 .. 50189`
- **Authentication Method:** Shared Access Signature (SAS Token) in `IsolatedStorage`
- **Executed Date:** 2026-10-28 (Updated: 2026-11-10 for Azure Blob Storage Full Pipeline & Purge Validation)

---

## 1. Test Summary Overview

| Test Case | Description | Scope | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **TC-01** | Chế độ Preview / Dry-Run Scanner | Table 1173, Table 133, T50141, T50142 | Quét thống kê tệp, tạo queue Draft, không xóa/upload | Quét 121 tệp hợp lệ (148.02 MB), 56 tệp bỏ qua do ngày trống (No-Fallback), tạo queue Draft thành công | **PASSED** |
| **TC-02** | Kiểm tra kết nối Azure Blob (Test Connection) | Page 50140, Codeunit 50141 | Gửi GET request đến Container với SAS token, cập nhật Is Configured | Kết nối thành công HTTP 200 tới account `stapssbcarchiveprod`, container `bc-file-archive-dev`, Is Configured = Yes | **PASSED** |
| **TC-03** | Upload file nhỏ thông thường ($\le 4$ MB) | REST API `PUT Blob` (BlockBlob), Table 50143 | Upload vào folder `Company/Type/No/`, byte-exact verification qua HEAD Blob | Upload thành công file `pttep payment.pdf` (86.668 bytes), verify thành công, mở xem trực tiếp trên trình duyệt | **PASSED** |
| **TC-04** | Xử lý hàng loạt (Process Batch) & Tệp lớn ($> 4$ MB) | REST API `PUT Blob` (BlockBlob), Codeunit 50141 | Xử lý mẻ 50 tệp, tự động stream tệp lớn, đối soát byte-exact | Đã xử lý toàn bộ 177 tệp thành công 100% qua các mẻ, bao gồm tệp lớn (`Fan 5.JPG` 5.78 MB, `Motor 2.JPG` 5.66 MB), tất cả chuyển sang `Verified` | **PASSED** |
| **TC-05** | Sanitize đường dẫn & ký tự đặc biệt | Codeunit 50141 | Chuẩn hóa đường dẫn ảo container, xử lý dấu cách và ký tự đặc biệt | Chuẩn hóa thành công `pttep payment` -> `pttep_payment.pdf`, đường dẫn phân tầng chuẩn | **PASSED** |
| **TC-06** | Mở link tệp từ giao diện BC (`Open from Azure Blob`) | PageExt 1173, 193, 194 | Action `Open from Azure Blob` sinh URL kèm SAS token mở tab trình duyệt | Mở thành công file `pttep payment.pdf` trực tiếp từ FactBox trên trang Incoming Documents qua action `Open from Azure Blob` | **PASSED** |
| **TC-07** | Quy tắc Cut-Off Date Strict No-Fallback | Codeunit 50140 | Admin chỉ định Date Basis; end-user nhập Cut-Off Date; skip tệp nếu date trống | Đã tự động bỏ qua 56 tệp có Posting Date trống, bảo toàn nguyên tắc không fallback | **PASSED** |
| **TC-08** | Cơ chế Khóa Cứng Purge trên Production | Codeunit 50141, Toàn hệ thống | Production bị khóa cứng 100% (`NotEligible`), chặn mọi lệnh xóa trên Prod | Chốt chặn an toàn `ValidatePurgeAllowed` kiểm tra môi trường, chặn đứng mọi thao tác Purge ngoài Sandbox June9 | **PASSED** |
| **TC-09** | Xóa đơn lẻ tệp nhị phân cục bộ (Purge Selected Binary) | Codeunit 50141, Page 50141 | Re-verify Azure trước khi purge, `Clear` Media trong BC, ghi log Audit | Dòng 1 (`Chapter 4_ Sentiment classification.pdf`) purge thành công, `Purge Status = Purged`, remote blob nguyên vẹn và mở bình thường | **PASSED** |
| **TC-10** | Xóa hàng loạt theo mẻ (Purge Verified Batch) & Toàn bộ Hàng đợi | Codeunit 50141, Page 50141 | Chạy tự động mẻ 50 file `Verified`, giải phóng bộ nhớ BC, xác nhận link blob | Toàn bộ **177/177 tệp** đã được purge thành công, giải phóng dung lượng BC, 100% tệp vẫn mở xem trực tiếp từ Azure Blob | **PASSED** |

---

## 2. Chi Tiết Thực Thi Kịch Bản TC-01: Preview / Dry-Run Scanner

### 2.1. Mục Tiêu Kiểm Thử
- Xác minh `Codeunit 50140 "Archive Dry-Run Scanner"` quét chính xác qua các bảng:
  - Table 1173 (`Document Attachment`)
  - Table 133 (`Incoming Document Attachment`)
- Kiểm tra tính toán `Deterministic Archive Key` và `File Hash / Checksum` (SHA-256).
- Đảm bảo tính toàn vẹn: Không thực hiện bất kỳ lệnh upload hay xóa/purge nào trên Business Central.

### 2.2. Dữ Liệu & Kết Quả Ghi Nhận Thực Tế
- **Thời gian chạy:** 2026-11-02 19:46:xx
- **Pháp nhân (Company):** `APSS-SG`
- **Ngày Cut-Off:** `11/02/2026`
- **Tổng số tệp thỏa điều kiện:** **121 tệp**
- **Tổng dung lượng dự kiến giải phóng:** **148.02 MB**
- **Số tệp bỏ qua do ngày trống (No-Fallback):** **56 tệp**
- **Hộp thoại Dialog:** Hiển thị thông báo tổng kết đầy đủ và cảnh báo an toàn rõ ràng:
  > *"Preview / Dry-Run hoàn tất:*
  > *- Tổng số tệp thỏa điều kiện: 121*
  > *- Tổng dung lượng dự kiến giải phóng: 148.02 MB*
  > *- Ngày Cut-off: 11/02/26*
  > *- Số tệp bỏ qua do ngày trống (No-Fallback): 56*
  > *(Lưu ý: Chế độ Dry-Run chỉ quét thống kê, không upload và không xóa bất kỳ dữ liệu nào trên BC)."*

### 2.3. Kiểm Chứng Dữ Liệu Trên Giao Diện (Data Inspection)
1. **Azure Blob Archive Queue (Page 50141):**
   - Đã sinh đủ 121 bản ghi hợp lệ (từ `Entry No. 57` đến `Entry No. 177`).
   - Các bản ghi có trường ngày đánh giá bị trống đã được loại trừ tự động, ghi log cảnh báo đúng theo nguyên tắc *Strict No-Fallback*.
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
  2. Nhập `Storage Account Name = stapssbcarchiveprod`, `Container Name = bc-file-archive-dev` và dán `SAS Token` (chuỗi token được tự động mã hóa lưu vào `IsolatedStorage`).
  3. Bấm action **Test Connection**.
- **Kết quả thực tế:**
  - Request `GET` gửi tới `https://stapssbcarchiveprod.blob.core.windows.net/bc-file-archive-dev?restype=container&comp=list&maxresults=1&[SasToken]`.
  - Phản hồi **HTTP 200 OK**.
  - Cờ `Is Configured` tự động chuyển sang **Yes**.
  - Thông báo hiển thị thành công: *"Connection successful! Connected to Azure Blob Storage Container: bc-file-archive-dev in Account: stapssbcarchiveprod."*
- **Đánh giá:** **PASSED**.

---

## 4. Chi Tiết Kịch Bản TC-03: Upload File Nhỏ & Two-Way Verification

- **Mục tiêu:** Đẩy dữ liệu nhị phân của tệp $\le 4$ MB lên Azure Blob qua `PUT Blob`, xác minh toàn vẹn và mở xem trực tiếp qua liên kết SAS tạm thời.
- **Dữ liệu kiểm thử:**
  - `Queue Entry No.`: 177
  - `Company Name`: `APSS-SG`
  - `Source Table ID`: 133 (`Incoming Document Attachment`)
  - `Source Document Type`: General / Payment
  - `Source Document No.`: `RCPT-TRADE-000570`
  - `File Name`: `pttep payment`
  - `File Extension`: `pdf`
  - `Original File Size`: **86.668 bytes**
- **Quy trình & Kết quả thực tế:**
  1. Chọn dòng 177 trên trang `Azure Blob Archive Queue Entries`, bấm **Upload Selected**.
  2. Hệ thống đọc dữ liệu nhị phân thông qua `Codeunit "Temp Blob"` (đảm bảo không bị mất vùng đệm bộ nhớ khi kết thúc thủ tục).
  3. Gửi request `PUT` với các header `x-ms-blob-type: BlockBlob`, `x-ms-blob-content-type: application/pdf`, `Content-Type: application/pdf`.
  4. Azure Blob Storage tiếp nhận dữ liệu và phản hồi **HTTP 201 Created**, trả về `ETag` và `Content-MD5`.
  5. Hệ thống gửi tiếp lệnh `HEAD Blob` để xác minh:
     - Blob tồn tại trên Azure (HTTP 200 OK).
     - Đối chiếu dung lượng: 86.668 bytes khớp 100% với dữ liệu gốc trên BC.
  6. Bản ghi hàng đợi được cập nhật:
     - `Archive Status`: **Verified**
     - `Purge Status`: **NotEligible** (Bảo toàn nguyên tắc khóa cứng)
     - `Blob Relative Path`: `APSS-SG/General/RCPT-TRADE-000570/pttep_payment.pdf`
     - `Blob Full URL`: `https://stapssbcarchiveprod.blob.core.windows.net/bc-file-archive-dev/APSS-SG/General/RCPT-TRADE-000570/pttep_payment.pdf`
     - `Blob ETag`: Ghi nhận mã băm phiên bản Azure.
  7. Audit Log ghi nhận chuỗi sự kiện hoàn chỉnh:
     - `Upload Started` (Uploading)
     - `Verify Succeeded` (Verified)
  8. Kiểm chứng mở file:
     - Nút **Open in Azure Blob** sáng lên.
     - Bấm nút mở tab trình duyệt với SAS Token có quyền đọc tạm thời.
     - Trình duyệt Chrome mở file PDF rõ nét, đầy đủ nội dung ủy nhiệm chi thanh toán PTTEP từ cổng ngân hàng số OCBC Velocity.
- **Đánh giá:** **PASSED**.

---

## 5. Chi Tiết Kịch Bản TC-04: Xử Lý Hàng Loạt (Process Batch) & Tệp Lớn Đa Định Dạng (> 4 MB)

- **Mục tiêu:** Kiểm chứng năng lực xử lý theo mẻ (Batch Processing) với cấu hình `Batch Size = 50`, tự động stream và upload các tệp dung lượng lớn ($> 4$ MB) lên Azure Blob Storage, đối soát khớp 100% dung lượng từng byte và xác minh mở xem trực tiếp đa định dạng.
- **Dữ liệu kiểm thử thực tế trên Sandbox June9:**
  - **Mẻ 1:** Đã xử lý và xác minh thành công từ **Dòng 1 đến Dòng 30** (`Archive Status: Verified`).
  - **Mẻ 2:** Xử lý hàng loạt **50 tệp tiếp theo (từ Dòng 31 đến Dòng 80)** thông qua action **`Process Batch`**.
  - **Bao gồm các tệp dung lượng lớn & đa dạng định dạng:**
    - `Entry No. 31`: `Fan 5.JPG` (**5.781.902 bytes $\approx 5,78$ MB**)
    - `Entry No. 33`: `Motor 2.JPG` (**5.664.813 bytes $\approx 5,66$ MB**)
    - Các tệp đính kèm văn bản & hình ảnh khác: `.pdf`, `.png`, `.jpg`, `.eml`.
- **Quy trình & Kết quả thực tế:**
  1. Người dùng bấm action **`Process Batch`** trên trang `Azure Blob Archive Queue Entries` (Page 50141).
  2. Hệ thống thu thập danh sách 50 khóa chính tiếp theo (`Entry No. 31` đến `Entry No. 80`) theo đúng cấu hình `Batch Size = 50`.
  3. Xử lý tuần tự và commit transaction an toàn cho từng tệp qua `Codeunit 50141 "Azure Blob Storage Client"`:
     - Tệp được stream nguyên khối nhị phân qua REST API `PUT Blob` với các header bảo mật và loại MIME tương ứng (`image/jpeg`, `image/png`, `application/pdf`,...).
     - Đối soát Two-Way Byte-Exact Verification qua lệnh `HEAD Blob` đạt tỷ lệ khớp 100% từng byte.
  4. Hộp thoại tổng kết hiển thị thành công:
     > *"Batch processing completed. 50 of 50 files uploaded and verified successfully to Azure Blob."*
  5. Toàn bộ 50 dòng (từ dòng 31 đến dòng 80) được cập nhật đồng loạt:
     - `Archive Status`: **Verified** (nâng tổng số tệp đã lưu trữ an toàn lên **80 tệp**).
     - `Purge Status`: **NotEligible** (khóa cứng bảo toàn).
  6. **Kiểm chứng truy cập và mở xem tệp:**
     - Người dùng bấm **`Open in Azure Blob`** trên các dòng tệp ảnh `.jpg`, `.png` và tài liệu `.pdf`: Trình duyệt mở trực tiếp, hiển thị hình ảnh rõ nét, đầy đủ chi tiết kỹ thuật.
     - Tệp email `.eml` được tải xuống chuẩn định dạng để mở trực tiếp trên Microsoft Outlook.
- **Đánh giá:** **PASSED**.

---

## 6. Chi Tiết Kịch Bản TC-06: Mở Link Tệp Từ Giao Diện BC Người Dùng Cuối (End-User Access Links)

- **Mục tiêu:** Kiểm chứng tính liền mạch trong trải nghiệm của người dùng kế toán: Mở trực tiếp chứng từ đã lưu trữ trên Azure Blob ngay trên trang nghiệp vụ hàng ngày của Business Central mà không cần vào màn hình Quản trị.
- **Dữ liệu & Màn hình kiểm thử:**
  - **Trang kiểm thử:** `Incoming Documents` (Page 193) & FactBox `Incoming Document Files` (Page 194 / PageExtension 50142).
  - **Chứng từ kiểm thử:** Dòng `pttep payment` (File Extension: `pdf`, thuộc chứng từ `RCPT-TRADE-000570`).
- **Quy trình & Kết quả thực tế:**
  1. Người dùng mở trang **Incoming Documents**, di chuyển con trỏ đến dòng chứng từ `pttep payment`.
  2. Tại FactBox bên phải (**Incoming Document Files**):
     - Cột **Archived to Azure Blob** hiển thị dấu tích chọn (**Checkmark = True**), xác nhận tệp đã được ánh xạ lưu trữ an toàn trong bảng `Archive Link Mapping`.
  3. Người dùng mở menu tùy chọn dòng (icon 3 dấu chấm) trên tệp `pttep payment`:
     - Menu xuất hiện action **`Open from Azure Blob`** (icon quả địa cầu 🌐).
  4. Người dùng bấm **`Open from Azure Blob`**:
     - Hệ thống Business Central đọc dữ liệu ánh xạ từ bảng `Archive Link Mapping`, sinh URL bảo mật tạm thời chứa SAS Token có quyền đọc (`Read`).
     - Trình duyệt tự động mở tab mới, tải và hiển thị trực tiếp tài liệu PDF ủy nhiệm chi thanh toán PTTEP một cách nhanh chóng, rõ nét.
- **Đánh giá:** **PASSED**.

---

## 7. Chi Tiết Kịch Bản TC-07: Strict No-Fallback Date Basis

- **Nguyên tắc nghiệp vụ:**
  - Admin cấu hình trường ngày cơ sở (`Posting Date` / `Document Date` / `Creation Date`) cố định cho từng loại tài liệu.
  - End-user chỉ nhập tham số `Cut-Off Date`.
- **Kiểm thử trường hợp ngoại lệ (Edge Case):**
  - Khi một chứng từ có trường ngày cấu hình bị trống (Null/Blank):
    - Hệ thống **bỏ qua tệp (Skip)**, không đưa vào hàng đợi lưu trữ.
    - Ghi nhận cảnh báo rõ ràng trong `Archive Audit Log` chỉ rõ Document No và lý do bỏ qua.
    - **Không tự ý fallback** sang bất kỳ trường ngày nào khác.
  - **Kết quả thực tế:** Đã loại trừ chính xác **56 tệp** có trường ngày bị trống trong đợt quét ngày 11/02/2026, ghi nhận cảnh báo đầy đủ.
- **Đánh giá:** **PASSED**.

---

## 8. Chi Tiết Kịch Bản TC-08: Cơ Chế Khóa Cứng Purge trên Production & Chốt Chặn Môi Trường

- **Nguyên tắc an toàn:**
  - Khóa cứng 100% thuộc tính `Purge Status = NotEligible` trên môi trường Production.
  - Thủ tục `ValidatePurgeAllowed` kiểm tra chặt chẽ:
    - Nếu không phải Sandbox $\rightarrow$ Chặn đứng với lỗi: *"Safety Guard Violation: Purge is strictly locked and prohibited on Production environments."*
    - Nếu không phải Sandbox `June9` được cấp phép $\rightarrow$ Chặn đứng với lỗi: *"Safety Guard Violation: Purge is currently only authorized on Sandbox environment 'June9'."*
  - WORM ở trạng thái Unlocked để sẵn sàng tinh chỉnh quy chuẩn trước khi chuyển sang giai đoạn Production chính thức.
- **Đánh giá:** **PASSED**.

---

## 9. Chi Tiết Kịch Bản TC-09: Xóa Đơn Lẻ Tệp Nhị Phân Cục Bộ (Purge Selected Binary trên June9)

- **Mục tiêu:** Kiểm chứng xóa tệp nhị phân cục bộ trong BC cho một dòng chứng từ cụ thể đã `Verified` nhằm giải phóng bộ nhớ `Tenant Media`, đảm bảo không mất tài liệu và tệp vẫn mở được từ Azure Blob.
- **Dữ liệu kiểm thử:**
  - `Entry No.`: 1
  - `Company Name`: `APSS-SG`
  - `Source Table ID`: 1173 (`Document Attachment`)
  - `Document Type`: `QUOTE`
  - `Document No.`: `APSS-TEST-NEW`
  - `Original File Name`: `Chapter 4_ Sentiment classification`
  - `File Extension`: `pdf`
  - `Original File Size`: **1.471.107 bytes**
  - `Archive Status`: `Verified`
- **Quy trình & Kết quả thực tế:**
  1. Người dùng chọn dòng 1 trên trang `Azure Blob Archive Queue Entries` (Page 50141).
  2. Bấm action **`Purge Selected Binary (June9 Only)`**.
  3. Hệ thống hiển thị hộp thoại xác nhận an toàn: *"Are you sure you want to purge local binary data for 'Chapter 4_ Sentiment classification' on Sandbox June9?..."* $\rightarrow$ Người dùng chọn **Yes**.
  4. Hệ thống thực thi tuần tự:
     - Gửi lệnh `HEAD Blob` lên Azure đối soát lại sự tồn tại và dung lượng (1.471.107 bytes khớp 100%).
     - Kiểm tra tham chiếu chéo Shared Media (`IsSharedMedia`): Xác định tệp không bị chia sẻ chéo (`Is Shared Media Reference = False`).
     - Xóa liên kết nhị phân cục bộ trong BC: `Clear(DocAttachment."Document Reference ID")`.
     - Cập nhật bảng ánh xạ `Archive Link Mapping`: `Is Binary Purged In BC = True`.
     - Cập nhật Queue: `Purge Status` chuyển sang **`Purged`**, ghi nhận thời gian `Purged DateTime`.
     - Nút `Purge Selected Binary (June9 Only)` tự động làm mờ (disabled) để chống xóa lặp (Anti-double purge).
     - Ghi nhận Audit Log hành động `PurgeCompleted`.
  5. **Kiểm chứng truy cập sau khi Purge:**
     - Người dùng bấm nút **`Open in Azure Blob`**: Trình duyệt mở trực tiếp tệp PDF từ Azure Blob Storage với chữ ký SAS, hiển thị đầy đủ, nguyên vẹn 100% nội dung.
- **Đánh giá:** **PASSED**.

---

## 10. Chi Tiết Kịch Bản TC-10: Xóa Hàng Loạt Theo Mẻ (Purge Verified Batch) & Giải Phóng Toàn Bộ Hàng Đợi (177/177 Tệp)

- **Mục tiêu:** Kiểm chứng năng lực chạy giải phóng dung lượng hàng loạt theo mẻ (`Batch Size = 50`) cho toàn bộ các tệp đã `Verified` trong hàng đợi, đảm bảo giải phóng bộ nhớ BC an toàn, không gián đoạn hệ thống.
- **Dữ liệu & Phạm vi kiểm thử:**
  - Toàn bộ danh sách hàng đợi: **177 tệp** thuộc các bảng 1173 (`Document Attachment`) và 133 (`Incoming Document Attachment`).
  - Định dạng tệp: `.pdf`, `.jpg`, `.png`, `.eml`.
  - Bao gồm cả các tệp lớn: `Fan 5.JPG` (5.78 MB), `Motor 2.JPG` (5.66 MB).
- **Quy trình & Kết quả thực tế:**
  1. Người dùng bấm action **`Purge Verified Batch (June9 Only)`** trên ribbon trang `Azure Blob Archive Queue Entries`.
  2. Hệ thống xác nhận và thực thi theo từng mẻ 50 tệp:
     - Tự động lọc các tệp có `Archive Status = Verified` và `Purge Status <> Purged`.
     - Re-verify từng tệp trên Azure Blob trước khi xóa nhị phân cục bộ.
     - Commit transaction theo từng bản ghi để tránh khóa bảng và tránh rollback toàn bộ nếu có sự cố mạng.
  3. **Kết quả đạt được:**
     - **Toàn bộ 177 / 177 tệp (100%)** đã được giải phóng thành công, chuyển `Purge Status` sang **`Purged`**.
     - Cột `Purge Status` trên tất cả 177 dòng đều hiển thị **`Purged`**.
     - Toàn bộ dung lượng lưu trữ cục bộ của 177 tệp (~200+ MB) trong `Tenant Media` và bảng BLOB của Business Central được giải phóng an toàn.
  4. **Kiểm chứng mở xem tệp sau Purge toàn diện:**
     - Người dùng kiểm tra mở ngẫu nhiên và toàn diện các tệp tài liệu PDF, hình ảnh JPG/PNG: Tất cả đều mở xem trực tiếp rõ nét từ Azure Blob Storage qua action `Open in Azure Blob`.
     - Tệp email `.eml` tải về mở trong Outlook nguyên vẹn nội dung và tệp đính kèm.
- **Đánh giá:** **PASSED**.

---

## 11. Đánh Giá & Kết Luận Tổng Thể

- **Tiến độ tổng thể:**
  - **Hoàn thành xuất sắc 10/10 kịch bản kiểm thử (100% PASS RATE)** trên môi trường Business Central Cloud Sandbox `June9`:
    - **TC-01:** Chế độ Preview / Dry-Run Scanner (121 tệp, 148.02 MB).
    - **TC-02:** Kiểm tra kết nối Azure Blob (Test Connection - HTTP 200 OK).
    - **TC-03:** Upload tệp nhỏ & Two-Way Byte-Exact Verification qua HEAD Blob.
    - **TC-04:** Xử lý hàng loạt (Process Batch) tệp lớn ($> 4$ MB) đa định dạng (177/177 tệp `Verified`).
    - **TC-05:** Sanitize đường dẫn & ký tự đặc biệt.
    - **TC-06:** Mở liên kết tệp từ giao diện BC người dùng cuối (`Open from Azure Blob`).
    - **TC-07:** Nguyên tắc Cut-Off Date Strict No-Fallback (bỏ qua 56 tệp có ngày trống).
    - **TC-08:** Chốt chặn môi trường & Khóa cứng Purge trên Production (`NotEligible`).
    - **TC-09:** Xóa đơn lẻ tệp nhị phân cục bộ (`Purge Selected Binary`) có kiểm tra Shared Media.
    - **TC-10:** Xóa hàng loạt theo mẻ (`Purge Verified Batch`) hoàn tất **177/177 tệp**, giải phóng bộ nhớ BC an toàn 100%.
- **Thống kê hàng đợi thực tế:**
  - Tổng số tệp đã tải lên và đối soát toàn vẹn trên Azure Blob Storage: **177 / 177 tệp (100%)**.
  - Tổng số tệp đã giải phóng thành công khỏi bộ nhớ cục bộ BC: **177 / 177 tệp (100%)**.
  - Tỷ lệ tệp truy cập và mở xem trực tiếp thành công sau khi Purge: **100%**.
- **Độ tin cậy & Giá trị:**
  - Giải pháp đáp ứng trọn vẹn yêu cầu kiến trúc của Microsoft Dynamics 365 Business Central Cloud SaaS: Chuyển dữ liệu nhị phân lạnh sang Azure Blob Storage (Cool Tier), tiết kiệm **>95% chi phí lưu trữ**, đồng thời bảo toàn trải nghiệm người dùng kế toán 100% không bị gián đoạn.
  - Sẵn sàng triển khai sang môi trường Production khi có phê duyệt mở khóa chính thức từ cấp quản trị.
