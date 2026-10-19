-- ====================================================================
-- FIX VIETNAMESE UTF-8 DATA FOR CRM DATABASE
-- ====================================================================

BEGIN;

-- 1. Users
UPDATE users SET full_name = 'Nguyễn Văn Quản Lý' WHERE id = 1;
UPDATE users SET full_name = 'Trần Thị Lan' WHERE id = 2;
UPDATE users SET full_name = 'Lê Văn Hoàng' WHERE id = 3;

-- 2. Customers
UPDATE customers SET 
    name = 'Công ty Cổ phần Công nghệ Sao Mai', 
    company = 'Sao Mai Tech JSC', 
    address = 'Tòa nhà Sao Mai, Cầu Giấy, Hà Nội' 
WHERE id = 1;

UPDATE customers SET 
    name = 'Công ty TNHH Phần mềm Á Châu', 
    company = 'Á Châu Software Co., Ltd', 
    address = 'Quận 1, TP. Hồ Chí Minh' 
WHERE id = 2;

UPDATE customers SET 
    name = 'Doanh nghiệp Vận tải Hoàng Long', 
    company = 'Vận tải Hoàng Long', 
    address = 'Lê Thánh Tông, Hải Phòng' 
WHERE id = 3;

UPDATE customers SET 
    name = 'Ông Nguyễn Anh Tuấn', 
    company = 'Cá nhân đầu tư', 
    address = 'Ba Đình, Hà Nội' 
WHERE id = 4;

UPDATE customers SET 
    name = 'Công ty TNHH Dịch vụ Đại Phát', 
    company = 'Đại Phát Services', 
    address = 'Hải Châu, Đà Nẵng' 
WHERE id = 5;

UPDATE customers SET 
    name = 'Tập đoàn Địa ốc Thăng Long', 
    company = 'Thăng Long Group', 
    address = 'Nam Từ Liêm, Hà Nội' 
WHERE id = 6;

UPDATE customers SET 
    name = 'Công ty Cổ phần Dược phẩm Hoa Sen', 
    company = 'Hoa Sen Pharma', 
    address = 'Quận Tân Bình, TP. Hồ Chí Minh' 
WHERE id = 7;

UPDATE customers SET 
    name = 'Bà Phạm Thị Minh Nguyệt', 
    company = 'Thẩm mỹ viện Nguyệt Nga', 
    address = 'Đống Đa, Hà Nội' 
WHERE id = 8;

UPDATE customers SET 
    name = 'Công ty Logistics Đông Dương', 
    company = 'Đông Dương Logistics', 
    address = 'Ngô Quyền, Hải Phòng' 
WHERE id = 9;

UPDATE customers SET 
    name = 'Chuỗi Nhà hàng Ẩm thực Quê Hương', 
    company = 'Quê Hương F&B Group', 
    address = 'Quận 3, TP. Hồ Chí Minh' 
WHERE id = 10;

UPDATE customers SET 
    name = 'Công ty Năng lượng Xanh Việt', 
    company = 'Green Energy Vietnam', 
    address = 'Thanh Xuân, Hà Nội' 
WHERE id = 11;

UPDATE customers SET 
    name = 'Ông Đỗ Hùng Cường', 
    company = 'Chuỗi bán lẻ Cường Phát', 
    address = 'Hà Đông, Hà Nội' 
WHERE id = 12;

UPDATE customers SET 
    name = 'Công ty TNHH Thương mại Thái Bình', 
    company = 'Thái Bình Trading', 
    address = 'TP. Thái Bình' 
WHERE id = 13;

UPDATE customers SET 
    name = 'Công ty Cơ khí Tân Tiến', 
    company = 'Tân Tiến Machinery', 
    address = 'Long Biên, Hà Nội' 
WHERE id = 14;

UPDATE customers SET 
    name = 'Doanh nghiệp Xuất nhập khẩu Hải Nam', 
    company = 'Hải Nam Export Co.', 
    address = 'Sơn Trà, Đà Nẵng' 
WHERE id = 15;

-- 3. Contacts
UPDATE contacts SET full_name = 'Nguyễn Văn Minh', position = 'Giám đốc Công nghệ (CTO)' WHERE id = 1;
UPDATE contacts SET full_name = 'Trần Thu Hà', position = 'Trưởng phòng Mua hàng' WHERE id = 2;
UPDATE contacts SET full_name = 'Lê Quốc Bảo', position = 'Tổng Giám đốc' WHERE id = 3;
UPDATE contacts SET full_name = 'Vũ Mai Phương', position = 'Kế toán trưởng' WHERE id = 4;
UPDATE contacts SET full_name = 'Hoàng Đình Long', position = 'Chủ doanh nghiệp' WHERE id = 5;
UPDATE contacts SET full_name = 'Nguyễn Anh Tuấn', position = 'Nhà đầu tư cá nhân' WHERE id = 6;
UPDATE contacts SET full_name = 'Phan Văn Đại', position = 'Giám đốc Điều hành' WHERE id = 7;
UPDATE contacts SET full_name = 'Nguyễn Đức Thắng', position = 'Phó Tổng Giám đốc Dự án' WHERE id = 8;
UPDATE contacts SET full_name = 'Đặng Thị Thu Thảo', position = 'Thư ký Ban Tổng Giám đốc' WHERE id = 9;
UPDATE contacts SET full_name = 'Bùi Thị Sen', position = 'Giám đốc R&D' WHERE id = 10;
UPDATE contacts SET full_name = 'Ngô Thanh Tùng', position = 'Trưởng phòng Kỹ thuật' WHERE id = 11;
UPDATE contacts SET full_name = 'Phạm Thị Minh Nguyệt', position = 'Chủ thẩm mỹ viện' WHERE id = 12;
UPDATE contacts SET full_name = 'Trương Quốc Hùng', position = 'Giám đốc Vận hành' WHERE id = 13;
UPDATE contacts SET full_name = 'Lê Vĩnh Quế', position = 'Giám đốc Chuỗi' WHERE id = 14;
UPDATE contacts SET full_name = 'Phạm Ngọc Ánh', position = 'Quản lý Thu mua Nguyên liệu' WHERE id = 15;
UPDATE contacts SET full_name = 'Vũ Thành Đạt', position = 'Kỹ sư Trưởng Năng lượng' WHERE id = 16;
UPDATE contacts SET full_name = 'Đỗ Hùng Cường', position = 'Chủ chuỗi' WHERE id = 17;
UPDATE contacts SET full_name = 'Bùi Văn Bình', position = 'Chủ tịch HĐQT' WHERE id = 18;
UPDATE contacts SET full_name = 'Tạ Quang Tiến', position = 'Giám đốc Nhà máy' WHERE id = 19;
UPDATE contacts SET full_name = 'Trần Hải Nam', position = 'Giám đốc Xuất nhập khẩu' WHERE id = 20;

-- 4. Interactions
UPDATE interactions SET 
    subject = 'Tư vấn giải pháp CRM', 
    content = 'Gọi điện thoại trao đổi về nhu cầu quản lý khách hàng của Sao Mai Tech. Khách quan tâm gói doanh nghiệp.' 
WHERE id = 1;

UPDATE interactions SET 
    subject = 'Demo tính năng phần mềm', 
    content = 'Gặp mặt trực tiếp tại trụ sở khách hàng để demo các phân hệ CRM.' 
WHERE id = 2;

UPDATE interactions SET 
    subject = 'Gửi báo giá chính thức', 
    content = 'Gửi báo giá chi tiết và dự thảo hợp đồng qua email cho phòng Mua hàng.' 
WHERE id = 3;

UPDATE interactions SET 
    subject = 'Hỏi thăm phản hồi báo giá', 
    content = 'Khách hàng đang trình HĐQT phê duyệt ngân sách dự toán.' 
WHERE id = 4;

UPDATE interactions SET 
    subject = 'Khảo sát quy trình nghiệp vụ', 
    content = 'Trao đổi với TGĐ Bảo về luồng chăm sóc khách hàng của Á Châu Soft.' 
WHERE id = 5;

UPDATE interactions SET 
    subject = 'Xác nhận thông tin xuất hóa đơn', 
    content = 'Liên hệ kế toán Phương để xin thông tin MST và đăng ký kinh doanh.' 
WHERE id = 6;

UPDATE interactions SET 
    subject = 'Gửi tài liệu giải pháp kỹ thuật', 
    content = 'Email tài liệu API và sơ đồ tích hợp hệ thống nội bộ.' 
WHERE id = 7;

UPDATE interactions SET 
    subject = 'Giới thiệu dịch vụ vận tải', 
    content = 'Gọi điện chào gói hỗ trợ số hóa điều vận xe tải Bắc Nam.' 
WHERE id = 8;

UPDATE interactions SET 
    subject = 'Gặp mặt tại Hải Phòng', 
    content = 'Trao đổi cụ thể với anh Long về việc trang bị GPS và quản lý khách vận tải.' 
WHERE id = 9;

UPDATE interactions SET 
    subject = 'Ghi chú ngân sách', 
    content = 'Khách dự kiến triển khai vào Quý 4, hiện ưu tiên nâng cấp đội xe.' 
WHERE id = 10;

UPDATE interactions SET 
    subject = 'Tư vấn danh mục đầu tư', 
    content = 'Tư vấn thông tin thị trường và danh mục cổ phiếu tiềm năng.' 
WHERE id = 11;

UPDATE interactions SET 
    subject = 'Báo cáo phân tích vĩ mô', 
    content = 'Gửi báo cáo phân tích ngành bán lẻ và công nghệ.' 
WHERE id = 12;

UPDATE interactions SET 
    subject = 'Nhắc lịch tái cơ cấu vốn', 
    content = 'Khách hàng dự định giải ngân thêm 500 triệu vào tuần tới.' 
WHERE id = 13;

UPDATE interactions SET 
    subject = 'Tiếp cận khách hàng mới', 
    content = 'Gọi điện chào dịch vụ qua số hotline công ty.' 
WHERE id = 14;

UPDATE interactions SET 
    subject = 'Catalogue giới thiệu năng lực', 
    content = 'Gửi hồ sơ năng lực công ty và các dự án tiêu biểu.' 
WHERE id = 15;

UPDATE interactions SET 
    subject = 'Hẹn lịch họp trực tiếp', 
    content = 'Khách bận công tác Đà Nẵng, hẹn liên hệ lại vào đầu tháng tới.' 
WHERE id = 16;

UPDATE interactions SET 
    subject = 'Đàm phán hợp đồng cung cấp', 
    content = 'Họp với PTGĐ Thắng chốt các điều khoản bảo mật và tiến độ thanh toán.' 
WHERE id = 17;

UPDATE interactions SET 
    subject = 'Gửi biên bản nghiệm thu đợt 1', 
    content = 'Đã hoàn thành triển khai thử nghiệm tại 2 chi nhánh.' 
WHERE id = 18;

UPDATE interactions SET 
    subject = 'Chăm sóc định kỳ', 
    content = 'Kiểm tra độ hài lòng của người dùng tại các chi nhánh. Đánh giá tốt.' 
WHERE id = 19;

UPDATE interactions SET 
    subject = 'Ký kết thỏa thuận hợp tác', 
    content = 'Ký hợp đồng dịch vụ giám sát chất lượng dược phẩm với chị Sen.' 
WHERE id = 20;

UPDATE interactions SET 
    subject = 'Hỗ trợ kỹ thuật cấu hình', 
    content = 'Hướng dẫn kỹ sư Tùng kết nối cổng API.' 
WHERE id = 21;

UPDATE interactions SET 
    subject = 'Gửi báo cáo hiệu năng tháng', 
    content = 'Báo cáo thời gian phản hồi hệ thống đạt 99.98% uptime.' 
WHERE id = 22;

UPDATE interactions SET 
    subject = 'Tư vấn nâng cấp phần mềm CRM', 
    content = 'Chị Nguyệt muốn bổ sung tính năng gửi SMS Brandname đặt lịch cho khách.' 
WHERE id = 23;

UPDATE interactions SET 
    subject = 'Demo module SMS Marketing', 
    content = 'Khách hàng rất hài lòng và đồng ý chi thêm ngân sách tích hợp.' 
WHERE id = 24;

UPDATE interactions SET 
    subject = 'Theo dõi thanh toán hóa đơn', 
    content = 'Kế toán báo đã nhận được tiền đặt cọc 50%.' 
WHERE id = 25;

UPDATE interactions SET 
    subject = 'Trao đổi về giá cước vận tải biển', 
    content = 'Thảo luận với anh Hùng về việc tích hợp biểu phí vận tải tự động.' 
WHERE id = 26;

UPDATE interactions SET 
    subject = 'Gửi tài liệu đặc tả kỹ thuật', 
    content = 'Email tài liệu kết nối EDI với hệ thống cảng biển.' 
WHERE id = 27;

UPDATE interactions SET 
    subject = 'Họp nghiệm thu hệ thống giai đoạn 1', 
    content = 'Hai bên đã ký biên bản nghiệm thu kỹ thuật.' 
WHERE id = 28;

UPDATE interactions SET 
    subject = 'Đánh giá phần mềm quản lý bán', 
    content = 'Khảo sát thực tế tại nhà hàng chi nhánh Quận 1.' 
WHERE id = 29;

UPDATE interactions SET 
    subject = 'Hỗ trợ nhập liệu kho nguyên liệu', 
    content = 'Chị Ánh cần hỗ trợ import file Excel tồn kho thực tế.' 
WHERE id = 30;

UPDATE interactions SET 
    subject = 'Ghi chú yêu cầu tùy chỉnh', 
    content = 'Khách yêu cầu bổ sung báo cáo tiêu hao gia vị theo công thức nấu.' 
WHERE id = 31;

UPDATE interactions SET 
    subject = 'Ký hợp đồng bảo trì năm', 
    content = 'Hợp đồng bảo trì hệ thống SCADA điện mặt trời áp mái.' 
WHERE id = 32;

UPDATE interactions SET 
    subject = 'Cảnh báo biến tần quá nhiệt', 
    content = 'Thông báo sự cố cảm biến tại dàn mái nhà xưởng Bình Dương.' 
WHERE id = 33;

UPDATE interactions SET 
    subject = 'Gửi biên bản xử lý sự cố', 
    content = 'Đội kỹ thuật đã thay thế quạt tản nhiệt, hệ thống bình thường.' 
WHERE id = 34;

UPDATE interactions SET 
    subject = 'Tư vấn mở rộng điểm bán', 
    content = 'Anh Cường có kế hoạch mở thêm 3 cửa hàng bán lẻ tiện lợi.' 
WHERE id = 35;

UPDATE interactions SET 
    subject = 'Báo giá thiết bị POS thu ngân', 
    content = 'Gửi báo giá trọn gói combo máy in + máy quét mã vạch.' 
WHERE id = 36;

UPDATE interactions SET 
    subject = 'Hỏi thăm tình hình kinh doanh', 
    content = 'Doanh nghiệp tạm ngừng nhập hàng do thị trường trầm lắng.' 
WHERE id = 37;

UPDATE interactions SET 
    subject = 'Thông báo kết thúc hợp đồng', 
    content = 'Khách hàng chuyển đổi mô hình gia công, không gia hạn gói dịch vụ.' 
WHERE id = 38;

UPDATE interactions SET 
    subject = 'Liên hệ chăm sóc sau thanh lý', 
    content = 'Khách hàng chuyển trụ sở sang địa điểm mới, lưu thông tin để tiếp cận sau.' 
WHERE id = 39;

UPDATE interactions SET 
    subject = 'Đánh giá khách hàng VIP (Quản lý)', 
    content = 'Khách hàng chiến lược của công ty năm 2026. Chỉ đạo nhân viên ưu tiên hỗ trợ 24/7.' 
WHERE id = 40;

COMMIT;
