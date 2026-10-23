# BC File Archiving to SharePoint

Extension dành cho **Microsoft Dynamics 365 Business Central** (AL Language) hỗ trợ lưu trữ (archive), đồng bộ hóa và quản lý các tệp tin đính kèm (Attachments / Incoming Documents) từ Business Central lên **Microsoft SharePoint** (thông qua Microsoft Graph API hoặc SharePoint REST API).

---

## 📁 Cấu trúc thư mục dự án

`	ext
BC File Archiving to SharePoint/
├── .alpackages/               # Chứa các file symbol (.app) tải về từ Business Central
├── .vscode/
│   ├── extensions.json       # Gợi ý extension AL cần thiết cho VS Code
│   ├── launch.json           # Cấu hình kết nối Sandbox Cloud / Docker container
│   └── settings.json         # Quy tắc phân tích mã nguồn (CodeCop, PerTenantExtensionCop)
├── src/
│   ├── Table/                # Chứa bảng cấu hình SharePoint Setup, bảng Log / File Mapping
│   ├── TableExtension/       # Mở rộng bảng đính kèm (Doc. Attachment, Sales Header, v.v.)
│   ├── Page/                 # Trang cài đặt thông số SharePoint (Client ID, Secret, Drive/Folder)
│   ├── PageExtension/        # Nút bấm hành động đẩy file lên SharePoint trên các màn hình BC
│   ├── Codeunit/             # Logic xác thực OAuth2 / Graph API, xử lý upload & download file
│   ├── Enum/                 # Trạng thái đồng bộ, loại lưu trữ
│   ├── Report/               # Báo cáo kiểm tra lịch sử lưu trữ
│   └── PermissionSet/        # Phân quyền cho extension
├── app.json                  # Cấu hình định danh & phiên bản extension
└── .gitignore                # Bỏ qua tệp build và package nhị phân
`

---

## 🚀 Các bước chuẩn bị phát triển

1. **Mở thư mục dự án trong VS Code / IDE**:
   - Đường dẫn: D:\APSS Training\APSS\BC File Archiving to SharePoint
2. **Cài đặt Extension AL Language**:
   - Extension chính thức: **AL Language extension for Microsoft Dynamics 365 Business Central** (ms-dynamics-smb.al).
3. **Cấu hình kết nối Business Central trong .vscode/launch.json**:
   - Điền tên môi trường Sandbox (environmentName) hoặc thông số Docker BC server.
4. **Tải Symbols**:
   - Nhấn Ctrl + Shift + P -> gõ AL: Download Symbols.
   - Đăng nhập tài khoản Business Central để tải các tệp symbol vào .alpackages/.
5. **Biên dịch & Chạy thử**:
   - Ctrl + Shift + B: Build file .app.
   - F5 / Ctrl + F5: Xuất bản (Publish) lên Business Central để test.
