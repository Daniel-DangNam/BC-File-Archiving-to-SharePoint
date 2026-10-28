# TÀI LIỆU HƯỚNG DẪN QUẢN TRỊ & SỬ DỤNG HỆ THỐNG
## (BC FILE ARCHIVING TO SHAREPOINT - USER & ADMIN GUIDE)

- **Hệ thống:** Dynamics 365 Business Central Cloud v28 & Microsoft SharePoint Online
- **Phạm vi đối tượng:** Quản trị viên hệ thống (BC Admin), Kế toán trưởng, Kế toán viên
- **Dải Object AL:** `50140 .. 50189`

---

## MỤC LỤC
1. [Tổng Quan Kiến Trúc Nghiệp Vụ](#1-tổng-quan-kiến-trúc-nghiệp-vụ)
2. [Chi Tiết Cấu Hình: SharePoint Archive Setup (Page 50140)](#2-chi-tiết-cấu-hình-sharepoint-archive-setup-page-50140)
3. [Chi Tiết Vận Hành: SharePoint Archive Queue Entries (Page 50141)](#3-chi-tiết-vận-hành-sharepoint-archive-queue-entries-page-50141)
4. [Nhật Ký Kiểm Toán: SharePoint Archive Audit Logs (Page 50142)](#4-nhật-ký-kiểm-toán-sharepoint-archive-audit-logs-page-50142)
5. [Trải Nghiệm Người Dùng Cuối (End-User Access Links)](#5-trải-nghiệm-người-dùng-cuối-end-user-access-links)

---

## 1. TỔNG QUAN KIẾN TRÚC NGHIỆP VỤ

Module **BC File Archiving to SharePoint** được thiết kế để giải quyết bài toán tối ưu hóa dung lượng lưu trữ trên Business Central Cloud bằng cách di chuyển tệp đính kèm sang Microsoft SharePoint Online thông qua Microsoft Graph API:
- **Tập trung hóa:** Lưu trữ an toàn các tệp hóa đơn, báo giá, đơn hàng tại một Document Library duy nhất trên SharePoint của công ty.
- **Không mất dấu vết:** Người dùng trên BC vẫn nhìn thấy tên file, kích thước và mở file bình thường qua nút bấm `Open from SharePoint`.
- **An toàn tuyệt đối:** Giai đoạn 1 áp dụng cơ chế **Khóa cứng tính năng Purge (Hard-Locked)** để kiểm thử đối soát 100% trước khi cho phép giải phóng dung lượng vật lý.

---

## 2. CHI TIẾT CẤU HÌNH: SHAREPOINT ARCHIVE SETUP (PAGE 50140)

Màn hình cấu hình chính gồm 4 nhóm thông tin (FastTabs):

```
+-----------------------------------------------------------------------------------+
|                            SHAREPOINT ARCHIVE SETUP                               |
+-----------------------------------------------------------------------------------+
| [1] Microsoft Entra ID Connection (Tenant ID, Client ID, Secret, Is Configured)    |
| [2] SharePoint Storage Target (Site ID, Drive ID, Base Folder Path)              |
| [3] Archiving & Upload Policy (Cut-Off Date Rule, Batch Size, Chunk Size)         |
| [4] Approval & Safety Controls (Secondary Approval, Approver Role, Expiry Days)  |
+-----------------------------------------------------------------------------------+
```

### 2.1. FastTab 1: Microsoft Entra ID Connection (Xác thực Azure)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Microsoft Entra Tenant ID** | Text[50] | Directory (Tenant) ID của tổ chức trên Microsoft Entra ID (Azure AD). |
| **App Registration Client ID** | Text[50] | Application (Client) ID của ứng dụng được đăng ký trên Azure AD đại diện cho BC. |
| **Client Secret** | Masked (Text) | Giá trị khóa bí mật (Secret Value). Để đảm bảo an toàn cấp doanh nghiệp, giá trị này **không lưu vào Database**, mà được mã hóa lưu riêng trong `IsolatedStorage` của BC. |
| **Is Configured** | Boolean | Cờ chỉ đọc. Tự động bật sang `Yes` khi người dùng nhập đủ thông tin và bấm nút **Test Connection** thành công. |

### 2.2. FastTab 2: SharePoint Storage Target (Nơi Lưu Trữ Trên SharePoint)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **SharePoint Site ID (Graph)** | Text[250] | ID của SharePoint Site Collection do Microsoft Graph cấp. |
| **Document Library (Drive ID)** | Text[250] | ID của Thư viện tài liệu (Drive) trên SharePoint chỉ định để lưu file. |
| **Base Folder Path** | Text[250] | Đường dẫn thư mục gốc trên thư viện (ví dụ: `BC_Archive`). Bên trong thư mục này, hệ thống tự động phân loại theo cấu trúc chuẩn: `[Base Folder] / [Company Name] / [Document Type] / [Document No] / [File Name]`. |

### 2.3. FastTab 3: Archiving & Upload Policy (Chính Sách Quét & Upload)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Cut-Off Date Evaluation Rule** | Enum | Tiêu chí so khớp ngày của chứng từ để quyết định đưa vào lưu trữ: <br>- `Posting Date`: Ngày ghi sổ (chuẩn mực kế toán/kiểm toán tài chính). <br>- `Document Date`: Ngày chứng từ thực tế. |
| **Batch Size (per Job Run)** | Integer | Số lượng tệp tối đa xử lý trong mỗi mẻ chạy ngầm (mặc định: `50`). Giúp phân tải hệ thống và chống nghẽn băng thông Microsoft Graph (HTTP 429). |
| **Chunk Size for Resumable Upload (MB)** | Integer | Kích thước mỗi khối dữ liệu khi upload tệp lớn $> 4\text{ MB}$ (mặc định: `4 MB`). Cho phép tự động khôi phục (Resume) điểm ngắt nếu mạng gặp sự cố. |

### 2.4. FastTab 4: Approval & Safety Controls (Kiểm Soát Phê Duyệt An Toàn)
| Tên Trường (Field) | Kiểu Dữ Liệu | Mục Đích & Hướng Dẫn Sử Dụng |
| :--- | :--- | :--- |
| **Require Secondary Approval for Purge** | Boolean | Áp dụng nguyên tắc "Bốn mắt" (Four-Eyes Principle). Bắt buộc phải có người thứ 2 phê duyệt thì lệnh dọn dẹp dung lượng mới hợp lệ. |
| **Approver Permission Role ID** | Code[20] | Mã quyền (Role ID) được phép thực hiện phê duyệt (ví dụ: `SP-ARCHIVE-ADMIN`). |
| **Approval Expiry (Days)** | Integer | Thời hạn hiệu lực của lệnh duyệt (mặc định: `7` ngày). Quá hạn, trạng thái tự hủy và phải đối soát lại từ đầu. |

---

## 3. CHI TIẾT VẬN HÀNH: SHAREPOINT ARCHIVE QUEUE ENTRIES (PAGE 50141)

Trang Hàng đợi là trung tâm chỉ huy điều phối toàn bộ vòng đời lưu trữ của từng file.

### 3.1. Các Nút Chức Năng Trên Thanh Công Cụ (Action Bar)
1. **`Run Preview / Dry Run` (Chạy thử / Quét thống kê):**
   - Quét qua bảng 1173 (`Document Attachment`) và bảng 133 (`Incoming Document Attachment`).
   - Đưa danh sách vào hàng đợi với trạng thái `Draft / Preview`, tính mã SHA-256 Checksum Proof và Deterministic Key.
   - **An toàn tuyệt đối:** Hoàn toàn không upload và không xóa bất kỳ dữ liệu nào trên BC.
2. **`Upload Selected` (Upload dòng đang chọn):**
   - Thực hiện upload thủ công 1 file đang được chọn để kiểm thử hoặc xử lý ưu tiên.
   - Kiểm tra kết nối, gửi file lên SharePoint, đối soát kích thước từng byte và cập nhật `Archive Status = Verified`.
3. **`Process Batch` (Xử lý theo mẻ):**
   - Kích hoạt xử lý hàng loạt theo mẻ cho các bản ghi đang ở trạng thái `Pending Upload` theo đúng tham số `Batch Size`.
4. **`Open in SharePoint` (Mở tệp trên SharePoint):**
   - Sáng lên khi bản ghi đã upload thành công (`Archive Status = Verified`).
   - Mở tab trình duyệt xem file trực tiếp từ SharePoint Online.
5. **`Audit Trail` (Xem lịch sử kiểm toán):**
   - Mở nhanh bảng `Archive Audit Logs` được lọc riêng cho dòng tệp đang chọn.

### 3.2. Từ Điển Dữ Liệu Các Cột (Field Dictionary)
| Tên Cột | Tên Tiếng Anh | Diễn Giải Chi Tiết |
| :--- | :--- | :--- |
| **Số thứ tự** | `Entry No.` | Khóa chính tự tăng định danh duy nhất của từng dòng trong hàng đợi. |
| **Pháp nhân** | `Company Name` | Tên công ty sở hữu chứng từ (e.g. `APSS-SG`). Đảm bảo dữ liệu đa pháp nhân không bị lẫn lộn thư mục trên SharePoint. |
| **Bảng nguồn** | `Source Table ID` | Bảng lưu tệp trong BC: `1173` (Document Attachment) hoặc `133` (Incoming Document Attachment). |
| **Loại chứng từ** | `Document Type` | Phân loại nghiệp vụ: `QUOTE` (Báo giá), `ORDER` (Đơn hàng), `INVOICE` (Hóa đơn),... |
| **Số chứng từ** | `Document No.` | Số hiệu chứng từ gốc trên Business Central (e.g. `APSS-PO-2...`, `P-INV-2512...`). |
| **Tên tệp gốc** | `Original File Name` | Tên tệp tin đính kèm ban đầu. |
| **Định dạng** | `File Extension` | Đuôi mở rộng của tệp (`pdf`, `jpg`, `png`, `xlsx`,...). |
| **Dung lượng (Bytes)** | `Original File Size (Bytes)` | Kích thước tệp chính xác đến từng byte. Dùng để đối soát byte-exact với tệp trên SharePoint. |
| **Trạng thái lưu trữ** | `Archive Status` | Vòng đời upload: `Draft / Preview` $\rightarrow$ `Pending Upload` $\rightarrow$ `Uploading` $\rightarrow$ `Verified` / `Failed`. |
| **Trạng thái xóa** | `Purge Status` | Vòng đời dọn dẹp dung lượng trên BC: `Not Eligible` (khóa cứng) $\rightarrow$ `Pending Approval` $\rightarrow$ `Approved` $\rightarrow$ `Purged`. |
| **Tham chiếu dùng chung** | `Is Shared Media Reference` | Cờ nhận diện file dùng chung Media giữa nhiều chứng từ (ví dụ: chuyển từ Quote sang Order), giúp chống việc xóa làm hỏng chứng từ liên quan. |
| **Bản ghi chạy thử** | `Is Dry Run Record` | Đánh dấu bản ghi thuộc đợt quét thử nghiệm (Dry-Run). |
| **Đường dẫn SharePoint** | `SharePoint Web URL` | Đường dẫn trực tiếp để mở file trên giao diện Web SharePoint. |
| **ID tài sản SharePoint** | `SharePoint Drive Item ID` | ID duy nhất của tệp do Microsoft Graph API trả về sau khi upload thành công. |
| **Khóa khử trùng lặp** | `Deterministic Archive Key` | Mã SHA-256 sinh từ `Company + Table ID + Attachment GUID + File Size`. Đảm bảo quét lại nhiều lần không tạo file trùng lặp trên SharePoint. |
| **Mã kiểm tra toàn vẹn** | `File Hash / Checksum` | Mã băm SHA-256 của nội dung file dùng làm bằng chứng đối soát toàn vẹn. |

---

## 4. NHẬT KÝ KIỂM TOÁN: SHAREPOINT ARCHIVE AUDIT LOGS (PAGE 50142)

Trang `SharePoint Archive Audit Logs` là bảng ghi vết bất biến (Immutable Audit Trail) phục vụ công tác thanh tra, kiểm toán tài chính và bảo mật:
- **`Log Entry No.`**: Số thứ tự log tự tăng.
- **`Queue Entry No.`**: Mã dòng hàng đợi tương ứng (bằng `0` nếu là thao tác ở mức hệ thống như đợt quét Dry-Run tổng thể).
- **`Company Name`**: Pháp nhân thực hiện thao tác.
- **`Event Date Time`**: Thời gian chính xác đến từng giây.
- **`User ID`**: Tài khoản người dùng kích hoạt thao tác.
- **`Action Type`**: Loại hành động (`Scan`, `Dry Run`, `Upload`, `Verify`, `Purge`, `Approve`, `Error Retry`).
- **`Old Status` & `New Status`**: Ghi vết sự chuyển dịch trạng thái của bản ghi.
- **`Log Message`**: Chi tiết kết quả thực hiện.
- **`Verification Proof`**: Bằng chứng đối soát kích thước byte và mã định danh Drive Item.

---

## 5. TRẢI NGHIỆM NGƯỜI DÙNG CUỐI (END-USER ACCESS LINKS)

Người dùng thông thường (kế toán viên, nhân viên bán hàng/mua hàng) không cần phải vào màn hình Quản trị hàng đợi mà vẫn thao tác trực tiếp trên các chứng từ hàng ngày:

1. **Trên trang Document Attachment Details (Page 1173):**
   - Hiển thị cột mới **`Archived to SharePoint`**: Nhận biết ngay tệp này đã được lưu trữ an toàn trên SharePoint hay chưa.
   - Action **`Open from SharePoint`**: Nằm cạnh nút `Preview` chuẩn của BC. Khi click, hệ thống lập tức mở tệp trên tab mới của trình duyệt.
2. **Trên trang Incoming Documents (Page 193 / Page 194):**
   - Factbox và danh sách chứng từ đầu vào hiển thị trạng thái lưu trữ SharePoint.
   - Cho phép 1-click mở hóa đơn gốc mà không cần tải lại file về máy tính.
