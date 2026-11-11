# Báo Cáo Phân Tích Dung Lượng Cơ Sở Dữ Liệu (Capacity & Table Storage Analysis)
**Dự án:** Microsoft Dynamics 365 Business Central Cloud SaaS v28 - File Archiving to Azure Blob Storage  
**Ngày phân tích:** 11/11/2026  
**Nguồn dữ liệu:** Page 8700 `Table Information` trên 3 môi trường thực tế (`Sandbox20260304`, `Sandbox20260305`, `Production - APSS`).

---

## 1. Tóm Tắt Tổng Quan (Executive Summary)

Qua việc đối chiếu số liệu trích xuất trực tiếp từ trang **Table Information** trên 3 môi trường, báo cáo ghi nhận các điểm trọng tâm:
1. **Nguyên nhân cốt lõi gây tiêu hao dung lượng hệ thống:**
   - Trên Production, **`Tenant Media` (Table 2000000184)** chiếm tới **85.81 GB** với **198,652 files nhị phân**, chiếm hơn **85%** tổng dung lượng lưu trữ của toàn hệ thống.
   - Khi hoàn thành quy trình Upload, Verify và Purge sang Azure Blob Storage, hệ thống sẽ giải phóng được phần lớn khối lượng 85+ GB này.
2. **Sự khác biệt thực tế giữa các môi trường:**
   - **Sandbox20260304:** Bản môi trường nhẹ, `Tenant Media` chỉ có 5.12 GB (39,798 files). Tại Company kiểm tra, Table 1173 chỉ có 14 file và đều trống `Posting Date` nên kết quả kiểm tra sơ bộ (Dry-run) trả về 0 file thỏa điều kiện.
   - **Sandbox20260305:** Bản clone tải nặng (~100.83 GB), `Tenant Media` chiếm 81.68 GB (183,141 files), tập trung ở Table 133 tại các Company `APSS-SG`, `TEST_BASE`, `SG_TEST`.
   - **Production (APSS):** Tải thật nặng nhất, `Tenant Media` chiếm 85.81 GB (198,652 files), tập trung chủ yếu tại `APSS-SG` và công ty `Test SG08`.
3. **Phân bổ dung lượng ngoài File Attachments:**
   - Các bảng **Log tích hợp** (`Integration Synch. Job Entry` - Table 5339) và **Reminder tùy biến** (`APSS Opp. Reminder`, `VLE Reminder`...) đang chiếm thêm khoảng **6 - 7 GB** trên Production.

---

## 2. Bảng So Sánh Đối Chiếu 3 Môi Trường

| Tiêu chí | Sandbox20260304 (Sandbox 04) | Sandbox20260305 (Sandbox 05) | Production (APSS) |
| :--- | :--- | :--- | :--- |
| **Tổng tệp Tenant Media (Table 2000000184)** | 39,798 files | 183,141 files | **198,652 files** |
| **Dung lượng Tenant Media (Table 2000000184)** | 5,124,368 KB (~**5.12 GB**) | 81,678,352 KB (~**81.68 GB**) | 85,807,576 KB (~**85.81 GB**) |
| **Tenant Media Thumbnails (Table 2000000185)** | 25,505 records / ~**680 MB** | 49,722 records / ~**1.29 GB** | 43,602 records / ~**1.14 GB** |
| **Incoming Document Attachment (Table 133)** | Không đáng kể | **~9.78 GB** (45,925 records ở 4 công ty) | **~8.23 GB** (39,419 records ở 3 công ty) |
| **Integration Synch. Job Entry (Table 5339)** | ~1.20 GB | ~1.20 GB | **~2.34 GB** (chủ yếu E-Store, VN, US, ID...) |
| **Custom Reminder Tables (50012, 50018...)** | ~270 MB | ~560 MB | **~1.50 GB** (APSS-SG, Test SG08) |
| **Job Queue Log Entry (Table 474)** | ~350 MB | ~340 MB | **~480 MB** |
| **Email Message & Notification (1514, 8900)** | ~440 MB | ~550 MB | **~600 MB** |
| **Tổng % dung lượng do File Media chiếm** | ~60% | **> 82%** | **> 85%** |

---

## 3. Chi Tiết Từng Môi Trường

### 3.1. Môi Trường Production (APSS)

Dữ liệu ghi nhận từ màn hình `Table Information` sắp xếp theo `Size (KB)` giảm dần:

#### Top 15 Bảng Chiếm Dung Lượng Lớn Nhất trên Production:
| Company Name | Table Name | Table No. | Record Count | Size (KB) | Data Size (KB) | Index Size (KB) | Dung Lượng (GB / MB) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| *(System)* | **Tenant Media** | **2000000184** | **198,652** | **85,807,576** | 85,770,088 | 37,488 | **~85.81 GB** |
| APSS-SG | **Incoming Document Attachment** | 133 | 20,002 | 4,168,128 | 4,166,384 | 1,744 | **~4.17 GB** |
| Test SG08 | **Incoming Document Attachment** | 133 | 18,820 | 3,956,256 | 3,955,304 | 952 | **~3.96 GB** |
| *(System)* | **Tenant Media Thumbnails** | 2000000185 | 43,602 | 1,139,592 | 1,134,360 | 5,232 | **~1.14 GB** |
| E-Store | Integration Synch. Job Entry | 5339 | 575,753 | 779,528 | 658,664 | 120,864 | ~780 MB |
| APSS-VN NEW | Integration Synch. Job Entry | 5339 | 238,042 | 354,952 | 302,744 | 52,208 | ~355 MB |
| APSS-US | Integration Synch. Job Entry | 5339 | 217,001 | 343,936 | 297,640 | 46,296 | ~344 MB |
| APSS-SG | APSS Opp. Reminder | 50012 | 864,869 | 340,536 | 300,464 | 40,072 | ~341 MB |
| APSS-ID | Integration Synch. Job Entry | 5339 | 484,675 | 300,632 | 205,728 | 94,904 | ~301 MB |
| APSS France | Integration Synch. Job Entry | 5339 | 255,555 | 264,632 | 216,744 | 47,888 | ~265 MB |
| Test SG08 | APSS Opp. Reminder | 50012 | 669,401 | 263,416 | 232,808 | 30,608 | ~263 MB |
| APSS-AU | Job Queue Log Entry | 474 | 525,154 | 234,184 | 156,160 | 78,024 | ~234 MB |
| APSS-MY | Integration Synch. Job Entry | 5339 | 211,624 | 227,704 | 183,080 | 44,624 | ~228 MB |
| *(System)* | Agent Task File Data | 2000000272 | 411 | 227,224 | 227,152 | 72 | ~227 MB |
| APSS-SG | Workflow Step Argument | 1531 | 690,441 | 200,920 | 158,488 | 42,432 | ~201 MB |

#### Phân tích trọng tâm Production:
- **Tập trung file:** 2 công ty `APSS-SG` (20,002 file) và `Test SG08` (18,820 file) là nguồn phát sinh toàn bộ 85.8 GB nhị phân trong `Tenant Media`.
- **Dữ liệu công ty Test SG08:** Công ty `Test SG08` đang chứa gần 4 GB tệp đính kèm và hàng triệu bản ghi nhật ký phát sinh.

---

### 3.2. Môi Trường Sandbox20260305 (Sandbox 05 - Database Clone ~100 GB)

Môi trường này được clone từ Production nhằm mục đích kiểm thử giải pháp tải nặng:

#### Top Bảng Chiếm Dung Lượng Lớn Nhất trên Sandbox 05:
| Company Name | Table Name | Table No. | Record Count | Size (KB) | Dung Lượng (GB / MB) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *(System)* | **Tenant Media** | **2000000184** | **183,141** | **81,678,352** | **~81.68 GB** |
| APSS-SG | **Incoming Document Attachment** | 133 | 15,306 | 3,256,872 | **~3.26 GB** |
| TEST_BASE | **Incoming Document Attachment** | 133 | 15,306 | 3,253,016 | **~3.25 GB** |
| SG_TEST | **Incoming Document Attachment** | 133 | 14,801 | 3,180,024 | **~3.18 GB** |
| *(System)* | **Tenant Media Thumbnails** | 2000000185 | 49,722 | 1,289,032 | **~1.29 GB** |
| APSS-US | Integration Synch. Job Entry | 5339 | 217,000 | 343,872 | ~344 MB |
| APSS France | Integration Synch. Job Entry | 5339 | 255,555 | 264,632 | ~265 MB |
| APSS-AU | Job Queue Log Entry | 474 | 518,329 | 231,136 | ~231 MB |
| APSS-MY | Integration Synch. Job Entry | 5339 | 211,624 | 227,704 | ~228 MB |
| APSS-SG | Workflow Step Argument | 1531 | 495,555 | 144,216 | ~144 MB |
| APSS-SG | Sent Notification Entry | 1514 | 58,591 | 132,376 | ~132 MB |
| APSS-AU | Incoming Document Attachment | 133 | 512 | 94,544 | ~95 MB |

#### Phân tích trọng tâm Sandbox 05:
- Dữ liệu Table 133 chia đều qua 3 công ty: `APSS-SG`, `TEST_BASE`, và `SG_TEST`.
- Đã được kiểm chứng thực tế: Quá trình quét sơ bộ (Dry-Run) xác định 35,281 file eligible (~17.1 GB) tại công ty chỉ định; Upload & Verify Job Queue (Codeunit 50141) đã hoàn tất upload toàn bộ 35,281 file lên Azure Blob Storage.

---

### 3.3. Môi Trường Sandbox20260304 (Sandbox 04)

Môi trường kiểm thử độc lập:

#### Top Bảng Chiếm Dung Lượng Lớn Nhất trên Sandbox 04:
| Company Name | Table Name | Table No. | Record Count | Size (KB) | Dung Lượng (GB / MB) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| *(System)* | **Tenant Media** | **2000000184** | **39,798** | **5,124,368** | **~5.12 GB** |
| *(System)* | **Tenant Media Thumbnails** | 2000000185 | 25,505 | 679,448 | **~680 MB** |
| APSS-US | Integration Synch. Job Entry | 5339 | 217,000 | 347,040 | ~347 MB |
| APSS France | Integration Synch. Job Entry | 5339 | 255,555 | 281,968 | ~282 MB |
| APSS-MY | Integration Synch. Job Entry | 5339 | 211,624 | 240,496 | ~240 MB |
| APSS-AU | Job Queue Log Entry | 474 | 517,276 | 228,160 | ~228 MB |
| APSS-VN NEW | Integration Synch. Job Entry | 5339 | 94,848 | 147,480 | ~147 MB |
| APSS-SG | Workflow Step Argument | 1531 | 495,613 | 142,536 | ~143 MB |
| APSS-SG | Sent Notification Entry | 1514 | 58,577 | 132,440 | ~132 MB |
| SG_TEST | Sent Notification Entry | 1514 | 55,882 | 126,600 | ~127 MB |

#### Phân tích trọng tâm Sandbox 04:
- Table 133 không nằm trong danh sách bảng lớn của Sandbox 04.
- Table 1173 tại Company đang chọn có 14 bản ghi và cả 14 bản ghi đều có `Posting Date` bị trống. Do chính sách **Strict No-Fallback** (không tự động lấy ngày chứng từ khác để đảm bảo tính toàn vẹn dữ liệu kế toán), hệ thống ghi nhận bỏ qua 14 tệp này.
