# TÀI LIỆU HƯỚNG DẪN QUẢN TRỊ & SỬ DỤNG HỆ THỐNG
## (BC FILE ARCHIVING TO AZURE BLOB STORAGE - USER & ADMIN GUIDE)

- **Hệ thống:** Dynamics 365 Business Central Cloud v28 & Azure Blob Storage (REST API v2020-10-02)
- **Phương thức xác thực:** Shared Access Signature (SAS Token) mã hóa lưu trong `IsolatedStorage` (Không phụ thuộc Azure Entra ID App Registration)
- **Phạm vi đối tượng:** Quản trị viên hệ thống (BC Admin), Kế toán trưởng, Kế toán viên
- **Dải Object AL:** `50140 .. 50189`
- **Tài liệu so sánh & thiết kế:**
  - [Thiết Kế Kỹ Thuật Azure Blob Storage](TECHNICAL_DESIGN_AZURE_BLOB.md)
  - [Báo Cáo So Sánh Lưu Trữ SharePoint vs Azure Blob](STORAGE_COMPARISON_SHAREPOINT_VS_AZURE_BLOB.md)

---

## MỤC LỤC
1. [Tổng Quan Kiến Trúc Nghiệp Vụ](#1-tổng-quan-kiến-trúc-nghiệp-vụ)
2. [Chi Tiết Cấu Hình: Azure Blob Archive Setup (Page 50140)](#2-chi-tiết-cấu-hình-azure-blob-archive-setup-page-50140)
3. [Chi Tiết Vận Hành: Azure Blob Archive Queue (Page 50141)](#3-chi-tiết-vận-hành-azure-blob-archive-queue-page-50141)
4. [Nhật Ký Kiểm Toán: Azure Blob Archive Audit Logs (Page 50142)](#4-nhật-ký-kiểm-toán-azure-blob-archive-audit-logs-page-50142)
5. [Trải Nghiệm Người Dùng Cuối (End-User Access Links)](#5-trải-nghiệm-người-dùng-cuối-end-user-access-links)
6. [Chính Sách An Toàn & Tuân Thủ (WORM, Date Basis, Purge Lock)](#6-chính-sách-an-toàn--tuân-thủ-worm-date-basis-purge-lock)

---

## 1. TỔNG QUAN KIẾN TRÚC NGHIỆP VỤ

Module **BC File Archiving to Azure Blob Storage** được thiết kế để giải quyết triệt để bài toán chi phí và giới hạn dung lượng lưu trữ đắt đỏ của Business Central Cloud ($5–10/GB/tháng) bằng cách di chuyển tệp đính kèm sang **Azure Blob Storage** ($0.00099–0.018/GB/tháng, tiết kiệm >95–99.5%):

- **Xác thực trực tiếp & tối giản:** Xác thực thông qua SAS Token (Shared Access Signature) lưu trữ an toàn trong `IsolatedStorage`, loại bỏ hoàn toàn nhu cầu cấu hình Entra ID App Registration, phân quyền API permission phức tạp hay quản lý vòng đời Client Secret.
- **Không mất dấu vết nghiệp vụ:** Người dùng trên Business Central vẫn nhìn thấy tên file, kích thước, định dạng và mở file bình thường qua nút bấm `Open from Blob` (hệ thống tự động gắn SAS token tạm thời để xem an toàn).
- **Phân tầng lưu trữ linh hoạt (Access Tiers):** Hỗ trợ Hot, Cool, Cold và Archive tier tùy theo nhu cầu truy xuất thực tế của từng doanh nghiệp.
- **An toàn tuyệt đối (Hard-Locked Purge):** Tính năng xóa dữ liệu vật lý (Purge) trên Business Central được **khóa cứng hoàn toàn** ở cả giao diện người dùng và tầng mã nguồn AL. Dữ liệu gốc trên BC được bảo toàn nguyên vẹn 100%.

---

## 2. CHI TIẾT CẤU HÌNH: AZURE BLOB ARCHIVE SETUP (PAGE 50140)

Màn hình cấu hình chính gồm 4 nhóm thông tin (FastTabs):

```
+-----------------------------------------------------------------------------------+
|                           AZURE BLOB ARCHIVE SETUP                                |
+-----------------------------------------------------------------------------------+
| [1] Azure Storage Connection (Storage Account, Container, SAS Token, Is Confirmed) |
| [2] Storage Policy (Base Folder Path, Default Access Tier, Immutability/WORM)     |
| [3] Archiving & Cut-Off Date Policy (Date Basis, Batch Size, Chunk Size)          |
| [4] Approval & Safety Controls (Secondary Approval, Approver Role, Expiry Days)  |
+-----------------------------------------------------------------------------------+
```

### 2.1. FastTab 1: Azure Storage Connection (Kết Nối Azure Blob)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Storage Account Name** | Text[63] | Tên Azure Storage Account đã được khởi tạo trên Azure Portal (ví dụ: `stapssbcarchiveprod`). |
| **Container Name** | Text[63] | Tên Blob Container chỉ định để lưu file đính kèm: <br>- Môi trường Sandbox: `bc-file-archive-dev` <br>- Môi trường Production: `bc-file-archive-prod`. |
| **SAS Token** | Masked (Text) | Chuỗi SAS Token có quyền `Read`, `Add`, `Create`, `Write`, `List`. Để đảm bảo an toàn cấp doanh nghiệp, giá trị này **không lưu vào Database**, mà được mã hóa lưu riêng trong `IsolatedStorage` của Business Central. |
| **Is Configured** | Boolean | Cờ chỉ đọc. Tự động bật sang `Yes` khi người dùng nhập đủ thông tin và thực hiện hành động **Test Connection** thành công. |

> **Thao tác Test Connection:** Trên Action Bar, bấm nút **Test Connection**. Hệ thống sẽ gửi một request `GET` đến endpoint container kèm SAS Token (`?restype=container&comp=list&maxresults=1`). Nếu phản hồi HTTP 200 OK, hệ thống đánh dấu `Is Configured = Yes`.

> [!IMPORTANT]
> **Cơ Chế Phân Tách Môi Trường An Toàn (Environment Guard):**
> Hệ thống tích hợp sẵn rào chắn an toàn (Environment Guard) tự động nhận diện môi trường Business Central đang chạy:
> - Khi đang chạy trên môi trường **Sandbox** (`June9`), hệ thống chỉ cho phép kết nối đến Container dành riêng cho Dev/Test (`bc-file-archive-dev`) và sẽ **chặn hoàn toàn** nếu cấu hình trỏ sang container Production (`...-prod`).
> - Khi chạy trên môi trường **Production**, hệ thống sẽ yêu cầu kết nối đúng container Production (`bc-file-archive-prod`) để chống việc lưu dữ liệu nhầm lẫn giữa các môi trường.

---

### 2.2. FastTab 2: Storage Policy (Chính Sách Lưu Trữ & Thư Mục)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Base Folder Path** | Text[250] | Thư mục ảo gốc bên trong container (mặc định: `bc-archive`). Cấu trúc đường dẫn tệp được tự động chuẩn hóa: `[Base Folder] / [Company Name] / [Document Type] / [Document No] / [File Name]`. |
| **Default Access Tier** | Enum | Tầng lưu trữ mặc định khi đẩy tệp lên Azure Blob: <br>- `Hot`: Dành cho tài liệu thường xuyên đọc. <br>- `Cool`: Dành cho tài liệu ít đọc (> 30 ngày, tối ưu chi phí). <br>- `Cold`: Tài liệu rất hiếm khi đọc (> 90 ngày). <br>- `Archive`: Tài liệu lưu trữ pháp lý dài hạn (> 180 ngày). |
| **Immutability (WORM)** | Text / Note | Cấu hình chính sách bất biến WORM (Write Once, Read Many). Trong giai đoạn PoC, chính sách luôn ở trạng thái **Unlocked Policy** để đảm bảo khả năng tinh chỉnh trước khi ký duyệt pháp lý. |

---

### 2.3. FastTab 3: Archiving & Cut-Off Date Policy (Chính Sách Quét & Ngày Đánh Giá)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Cut-Off Date Basis** | Enum | Tiêu chí ngày do Quản trị viên chỉ định cố định theo loại chứng từ để so khớp với Cut-Off Date: <br>- `Posting Date`: Ngày ghi sổ (chuẩn mực kế toán & kiểm toán tài chính). <br>- `Document Date`: Ngày chứng từ thực tế. <br>- `Creation Date`: Ngày tạo bản ghi đính kèm. |
| **Batch Size (per Job Run)** | Integer | Số lượng tệp tối đa xử lý trong mỗi mẻ (mặc định: `50`). Giúp phân bổ tài nguyên và chống nghẽn đường truyền mạng. |
| **Chunk Size (MB)** | Integer | Kích thước mỗi khối dữ liệu khi upload tệp lớn $> 4\text{ MB}$ (mặc định: `4 MB`). Hệ thống tự động chia nhỏ thành các block (`Put Block`) và hoàn tất bằng `Put Block List`. |

> [!IMPORTANT]
> **Quy Tắc Quản Trị Cut-Off Date (Strict No-Fallback):**
> End-user khi chạy quét chỉ nhập duy nhất giá trị **Cut-off Date**, không được tự ý đổi trường ngày. Nếu chứng từ thiếu ngày cấu hình (ngày bị trống), hệ thống **ngay lập tức bỏ qua (Skip)** và ghi cảnh báo vào Audit Log, tuyệt đối **không tự ý fallback** sang ngày khác để đảm bảo tính nhất quán kiểm toán.

---

### 2.4. FastTab 4: Approval & Safety Controls (Kiểm Soát Phê Duyệt An Toàn)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Require Secondary Approval for Purge** | Boolean | Áp dụng nguyên tắc "Bốn mắt" (Four-Eyes Principle). |
| **Approver Permission Role ID** | Code[20] | Mã quyền (Role ID) được phép duyệt (ví dụ: `BLOB-ARCHIVE-ADMIN`). |
| **Approval Expiry (Days)** | Integer | Thời hạn hiệu lực của lệnh duyệt (mặc định: `7` ngày). |

> [!CAUTION]
> **Cơ chế Khóa Cứng Purge (Hard-Locked):**
> Toàn bộ logic Purge trên Business Central hiện được khóa cứng `Rec."Purge Status" := Rec."Purge Status"::NotEligible`. Tất cả các nút bấm liên quan đến xóa tệp gốc đều bị ẩn/vô hiệu hóa.

---

## 3. CHI TIẾT VẬN HÀNH: AZURE BLOB ARCHIVE QUEUE (PAGE 50141)

Trang Hàng đợi là trung tâm chỉ huy điều phối toàn bộ vòng đời lưu trữ của từng file.

### 3.1. Các Nút Chức Năng Trên Thanh Công Cụ (Action Bar)
1. **`Run Preview / Dry Run` (Chạy thử / Quét thống kê):**
   - Quét qua bảng 1173 (`Document Attachment`) và bảng 133 (`Incoming Document Attachment`).
   - Yêu cầu nhập **Cut-Off Date** và áp dụng quy tắc ngày do Admin đã cấu hình.
   - Đưa danh sách vào hàng đợi với trạng thái `Draft / Preview`, tính mã SHA-256 Checksum Proof và Deterministic Key.
   - **An toàn tuyệt đối:** Hoàn toàn không upload và không xóa dữ liệu trên BC.
2. **`Upload Selected` (Upload dòng đang chọn):**
   - Thực hiện upload thủ công 1 file đang được chọn.
   - Tệp $\le 4\text{ MB}$: Upload bằng `PUT Blob` (BlockBlob).
   - Tệp $> 4\text{ MB}$: Upload phân khối bằng `PUT Block` và `PUT Block List`.
   - Thực hiện bước đối soát byte-exact hai chiều qua request `HEAD Blob` (`Content-Length`, `ETag`, `Content-MD5`).
   - Cập nhật `Archive Status = Verified` và tự động cập nhật bảng `Archive Link Mapping`.
3. **`Process Batch` (Xử lý theo mẻ):**
   - Kích hoạt xử lý hàng loạt theo mẻ cho các bản ghi đang ở trạng thái `Draft / Pending Upload / Failed (Retry < 3)`.
4. **`Open in Azure Blob` (Mở tệp trên Azure Blob):**
   - Sáng lên khi bản ghi đã upload thành công (`Archive Status = Verified` và đã có `Blob Full URL`).
   - Sinh URL bảo mật tạm thời kèm SAS Token và mở tab trình duyệt để xem/tải tệp.
5. **`Audit Trail` (Xem lịch sử kiểm toán):**
   - Mở nhanh bảng `Archive Audit Logs` được lọc riêng cho dòng tệp đang chọn.

---

### 3.2. Từ Điển Dữ Liệu Các Cột (Field Dictionary)
| Tên Cột | Tên Tiếng Anh | Diễn Giải Chi Tiết |
| :--- | :--- | :--- |
| **Số thứ tự** | `Entry No.` | Khóa chính tự tăng định danh duy nhất của từng dòng trong hàng đợi. |
| **Pháp nhân** | `Company Name` | Tên công ty sở hữu chứng từ (e.g. `APSS-SG`). Giúp phân tách dữ liệu đa pháp nhân. |
| **Bảng nguồn** | `Source Table ID` | Bảng lưu tệp trong BC: `1173` (Document Attachment) hoặc `133` (Incoming Document Attachment). |
| **Loại chứng từ** | `Document Type` | Phân loại nghiệp vụ: `QUOTE`, `ORDER`, `INVOICE`,... |
| **Số chứng từ** | `Document No.` | Số hiệu chứng từ gốc trên Business Central (e.g. `APSS-PO-2...`, `P-INV-2512...`). |
| **Tên tệp gốc** | `File Name` | Tên tệp tin đính kèm ban đầu. |
| **Định dạng** | `File Extension` | Đuôi mở rộng của tệp (`pdf`, `jpg`, `png`, `xlsx`,...). |
| **Dung lượng (Bytes)** | `Original File Size (Bytes)` | Kích thước tệp chính xác đến từng byte, dùng đối soát byte-exact với Azure Blob. |
| **Trạng thái lưu trữ** | `Archive Status` | Vòng đời upload: `Draft` $\rightarrow$ `PendingUpload` $\rightarrow$ `Uploading` $\rightarrow$ `Verified` / `Failed`. |
| **Trạng thái xóa** | `Purge Status` | Vòng đời xóa trên BC: Mặc định luôn là `NotEligible` (Khóa cứng an toàn). |
| **Tầng lưu trữ** | `Blob Access Tier` | Tầng lưu trữ của tệp trên Azure (`Hot`, `Cool`, `Cold`, `Archive`). |
| **Đường dẫn tương đối** | `Blob Relative Path` | Đường dẫn ảo trong container (e.g. `bc-archive/APSS-SG/SalesInvoice/INV102/inv.pdf`). |
| **Đường dẫn Azure Blob** | `Blob Full URL` | URL gốc trỏ tới blob trên Azure Storage Account. |
| **ETag** | `Blob ETag` | Mã định danh phiên bản tệp do Azure trả về. |
| **Mã Content-MD5** | `Blob Content MD5` | Mã băm MD5 do Azure tính toán để đối soát toàn vẹn. |
| **Khóa khử trùng lặp** | `Deterministic Archive Key` | Mã SHA-256 sinh từ `Company + Table ID + Attachment GUID + File Size`. |
| **Bản ghi chạy thử** | `Is Dry Run Record` | Đánh dấu bản ghi thuộc đợt quét thử nghiệm (Dry-Run). |

---

## 4. NHẬT KÝ KIỂM TOÁN: AZURE BLOB ARCHIVE AUDIT LOGS (PAGE 50142)

Trang `Azure Blob Archive Audit Logs` là bảng ghi vết bất biến (Immutable Audit Trail) phục vụ công tác thanh tra và kiểm toán tài chính:

- **`Log Entry No.`**: Số thứ tự log tự tăng.
- **`Queue Entry No.`**: Mã dòng hàng đợi tương ứng (bằng `0` nếu là thao tác ở mức hệ thống như đợt quét Dry-Run tổng thể).
- **`Company Name`**: Pháp nhân thực hiện thao tác.
- **`Event Date Time`**: Thời gian chính xác đến từng giây.
- **`User ID`**: Tài khoản người dùng kích hoạt thao tác.
- **`Action Type`**: Loại hành động (`Scan`, `Dry Run`, `UploadStarted`, `UploadCompleted`, `VerifySucceeded`, `ErrorRetry`, `ConfigurationChange`).
- **`Old Status` & `New Status`**: Ghi vết sự chuyển dịch trạng thái của bản ghi.
- **`Log Message`**: Chi tiết kết quả thực hiện, tham số quét hoặc lỗi kỹ thuật nếu có.
- **`Verification Proof`**: Bằng chứng đối soát kỹ thuật (ETag, Content-Length, Content-MD5).

---

## 5. TRẢI NGHIỆM NGƯỜI DÙNG CUỐI (END-USER ACCESS LINKS)

Người dùng thông thường (kế toán viên, nhân viên bán hàng/mua hàng) không cần phải vào màn hình Quản trị hàng đợi mà vẫn thao tác trực tiếp trên các chứng từ hàng ngày:

1. **Trên trang Document Attachment Details (Page 1173):**
   - Hiển thị cột mới **`Archived to Azure Blob`**: Nhận biết ngay tệp này đã được lưu trữ an toàn trên Azure Blob Storage hay chưa (Yes / No).
   - Action **`Open from Azure Blob`**: Nằm cạnh nút `Preview` chuẩn của Business Central. Khi click, hệ thống tự động sinh URL kèm SAS token tạm thời và mở tệp trực tiếp trên tab mới của trình duyệt.
2. **Trên trang Incoming Documents & Attachments (Page 193 / Page 194):**
   - Factbox và danh sách chứng từ đầu vào hiển thị cột **`Archived to Azure Blob`**.
   - Action **`Open from Azure Blob`** (Promoted cạnh nút Export) cho phép 1-click mở chứng từ thanh toán/hóa đơn gốc an toàn và tốc độ cao.

---

## 6. CHÍNH SÁCH AN TOÀN & TUÂN THỦ (WORM, DATE BASIS, PURGE LOCK)

| Hạng Mục | Quy Định & Thiết Kế Triển Khai |
| :--- | :--- |
| **Chính sách WORM** | Thiết lập ở chế độ **Configurable & Unlocked Policy** trong giai đoạn PoC. Chưa bật Locked Policy trên môi trường Production cho đến khi bộ phận Tài chính/Pháp chế ký duyệt chính thức thời hạn lưu trữ (retention period) và quy trình xử lý file trùng lặp/upload nhầm. |
| **Quy tắc Cut-Off Date** | Quản trị viên cấu hình **Date Basis** theo từng loại chứng từ (`Posting Date` / `Document Date` / `Creation Date`). Người dùng cuối chỉ nhập giá trị **Cut-off Date**. Áp dụng nguyên tắc **Strict No-Fallback**: Nếu trường ngày bị trống, hệ thống bỏ qua tệp và ghi log cảnh báo, không tự ý fallback. |
| **Khóa Cứng Purge** | Khóa cứng 100% (Hard-Locked) ở cả giao diện và codeunit AL. Không có bất kỳ lệnh xóa nhị phân nào được thực thi trên cơ sở dữ liệu Business Central. |
