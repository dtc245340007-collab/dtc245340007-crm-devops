-- ====================================================================
-- DATABASE INITIALIZATION SCRIPT FOR CRM SYSTEM
-- ====================================================================

-- 1. Create ENUM types
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('manager', 'staff');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'customer_status') THEN
        CREATE TYPE customer_status AS ENUM ('lead', 'active', 'inactive');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interaction_type') THEN
        CREATE TYPE interaction_type AS ENUM ('call', 'email', 'meeting', 'note');
    END IF;
END $$;

-- 2. Tables Schema

-- Table 1: users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role user_role NOT NULL DEFAULT 'staff',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Table 2: customers
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    customer_code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(30),
    company VARCHAR(150),
    address TEXT,
    status customer_status NOT NULL DEFAULT 'lead',
    assigned_to INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Table 3: contacts
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    full_name VARCHAR(100) NOT NULL,
    position VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(30),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Constraint: Mỗi khách hàng có tối đa 1 contact is_primary = true
CREATE UNIQUE INDEX IF NOT EXISTS unique_primary_contact_per_customer 
ON contacts (customer_id) WHERE is_primary = TRUE;

-- Table 4: interactions
CREATE TABLE IF NOT EXISTS interactions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    contact_id INTEGER REFERENCES contacts(id) ON DELETE SET NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    type interaction_type NOT NULL,
    subject VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    interaction_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    next_follow_up DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_assigned_to ON customers(assigned_to);
CREATE INDEX IF NOT EXISTS idx_customers_status ON customers(status);
CREATE INDEX IF NOT EXISTS idx_contacts_customer_id ON contacts(customer_id);
CREATE INDEX IF NOT EXISTS idx_interactions_customer_id ON interactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_interactions_interaction_time ON interactions(interaction_time);
CREATE INDEX IF NOT EXISTS idx_interactions_user_id ON interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_next_follow_up ON interactions(next_follow_up);

-- 4. Seed Data

-- 4.1 Users (1 manager, 2 staff - mật khẩu được hash bằng Werkzeug scrypt mạnh: Admin@CRM2026!, Staff@CRM2026!)
INSERT INTO users (id, username, password_hash, full_name, role, is_active) VALUES
(1, 'admin', 'scrypt:32768:8:1$HlpJOpxz1zUZR2Za$4604f65cdafbe007be8ab4d18d6f573fee97fde3da1eda80753a7d56bf067a88801035f4c1f60314de39bf77eaf3402ae9481bc99571c56d356997f355ca9902', 'Nguyễn Văn Quản Lý', 'manager', true),
(2, 'nhanvien01', 'scrypt:32768:8:1$ZAzlBnHN7k6D6Z78$468d9589ddf32687532638634ee15091a9bdd14514c6949f4fcb4440128a48c2957fff22431836bbb687d1ab283ce1437ecd9bf5d47ef8d3d1b78123faf1e87b', 'Trần Thị Lan', 'staff', true),
(3, 'nhanvien02', 'scrypt:32768:8:1$ZAzlBnHN7k6D6Z78$468d9589ddf32687532638634ee15091a9bdd14514c6949f4fcb4440128a48c2957fff22431836bbb687d1ab283ce1437ecd9bf5d47ef8d3d1b78123faf1e87b', 'Lê Văn Hoàng', 'staff', true)
ON CONFLICT (id) DO NOTHING;

SELECT setval('users_id_seq', (SELECT GREATEST(MAX(id), 1) FROM users));

-- 4.2 Customers (15 sample customers: 5 lead, 7 active, 3 inactive)
INSERT INTO customers (id, customer_code, name, email, phone, company, address, status, assigned_to) VALUES
(1, 'KH-001', 'Công ty Cổ phần Công nghệ Sao Mai', 'contact@saomai.vn', '02438889999', 'Sao Mai Tech JSC', 'Tòa nhà Sao Mai, Cầu Giấy, Hà Nội', 'lead', 2),
(2, 'KH-002', 'Công ty TNHH Phần mềm Á Châu', 'info@achau-soft.com', '02839998888', 'Á Châu Software Co., Ltd', 'Quận 1, TP. Hồ Chí Minh', 'lead', 2),
(3, 'KH-003', 'Doanh nghiệp Vận tải Hoàng Long', 'hoanglong@vantai.vn', '02253887766', 'Vận tải Hoàng Long', 'Lê Thánh Tông, Hải Phòng', 'lead', 3),
(4, 'KH-004', 'Ông Nguyễn Anh Tuấn', 'tuan.nguyen@gmail.com', '0912345678', 'Cá nhân đầu tư', 'Ba Đình, Hà Nội', 'lead', 3),
(5, 'KH-005', 'Công ty TNHH Dịch vụ Đại Phát', 'daiphat@daiphatcorp.com', '02363778899', 'Đại Phát Services', 'Hải Châu, Đà Nẵng', 'lead', 2),
(6, 'KH-006', 'Tập đoàn Địa ốc Thăng Long', 'bds@thanglongcorp.com', '02437776655', 'Thăng Long Group', 'Nam Từ Liêm, Hà Nội', 'active', 2),
(7, 'KH-007', 'Công ty Cổ phần Dược phẩm Hoa Sen', 'duoc@hoasenpharma.vn', '02838887711', 'Hoa Sen Pharma', 'Quận Tân Bình, TP. Hồ Chí Minh', 'active', 3),
(8, 'KH-008', 'Bà Phạm Thị Minh Nguyệt', 'nguyet.pham@outlook.com', '0987654321', 'Thẩm mỹ viện Nguyệt Nga', 'Đống Đa, Hà Nội', 'active', 2),
(9, 'KH-009', 'Công ty Logistics Đông Dương', 'ops@dongduonglog.com', '02253665544', 'Đông Dương Logistics', 'Ngô Quyền, Hải Phòng', 'active', 3),
(10, 'KH-010', 'Chuỗi Nhà hàng Ẩm thực Quê Hương', 'fnb@quehuong.vn', '02835554433', 'Quê Hương F&B Group', 'Quận 3, TP. Hồ Chí Minh', 'active', 2),
(11, 'KH-011', 'Công ty Năng lượng Xanh Việt', 'info@greenenergy.vn', '02436665522', 'Green Energy Vietnam', 'Thanh Xuân, Hà Nội', 'active', 3),
(12, 'KH-012', 'Ông Đỗ Hùng Cường', 'cuong.dohung@gmail.com', '0903456789', 'Chuỗi bán lẻ Cường Phát', 'Hà Đông, Hà Nội', 'active', 2),
(13, 'KH-013', 'Công ty TNHH Thương mại Thái Bình', 'tb@thaibinhcorp.com', '02273881122', 'Thái Bình Trading', 'TP. Thái Bình', 'inactive', 3),
(14, 'KH-014', 'Công ty Cơ khí Tân Tiến', 'kinhdoanh@tantien.com.vn', '02439992211', 'Tân Tiến Machinery', 'Long Biên, Hà Nội', 'inactive', 2),
(15, 'KH-015', 'Doanh nghiệp Xuất nhập khẩu Hải Nam', 'hainam@hainamexport.vn', '02363554422', 'Hải Nam Export Co.', 'Sơn Trà, Đà Nẵng', 'inactive', 3)
ON CONFLICT (id) DO NOTHING;

SELECT setval('customers_id_seq', (SELECT GREATEST(MAX(id), 1) FROM customers));

-- 4.3 Contacts (20 contacts)
INSERT INTO contacts (id, customer_id, full_name, position, email, phone, is_primary) VALUES
(1, 1, 'Nguyễn Văn Minh', 'Giám đốc Công nghệ (CTO)', 'minh.nv@saomai.vn', '0912111222', true),
(2, 1, 'Trần Thu Hà', 'Trưởng phòng Mua hàng', 'ha.tt@saomai.vn', '0912111333', false),
(3, 2, 'Lê Quốc Bảo', 'Tổng Giám đốc', 'bao.le@achau-soft.com', '0988222333', true),
(4, 2, 'Vũ Mai Phương', 'Kế toán trưởng', 'phuong.vm@achau-soft.com', '0988222444', false),
(5, 3, 'Hoàng Đình Long', 'Chủ doanh nghiệp', 'long@vantaihoanglong.vn', '0904333444', true),
(6, 4, 'Nguyễn Anh Tuấn', 'Nhà đầu tư cá nhân', 'tuan.nguyen@gmail.com', '0912345678', true),
(7, 5, 'Phan Văn Đại', 'Giám đốc Điều hành', 'dai.pv@daiphatcorp.com', '0935444555', true),
(8, 6, 'Nguyễn Đức Thắng', 'Phó Tổng Giám đốc Dự án', 'thang.nd@thanglongcorp.com', '0903555666', true),
(9, 6, 'Đặng Thị Thu Thảo', 'Thư ký Ban Tổng Giám đốc', 'thao.dt@thanglongcorp.com', '0903555777', false),
(10, 7, 'Bùi Thị Sen', 'Giám đốc R&D', 'sen.bt@hoasenpharma.vn', '0918666777', true),
(11, 7, 'Ngô Thanh Tùng', 'Trưởng phòng Kỹ thuật', 'tung.nt@hoasenpharma.vn', '0918666888', false),
(12, 8, 'Phạm Thị Minh Nguyệt', 'Chủ thẩm mỹ viện', 'nguyet.pham@outlook.com', '0987654321', true),
(13, 9, 'Trương Quốc Hùng', 'Giám đốc Vận hành', 'hung.tq@dongduonglog.com', '0904777888', true),
(14, 10, 'Lê Vĩnh Quế', 'Giám đốc Chuỗi', 'que.lv@quehuong.vn', '0989888999', true),
(15, 10, 'Phạm Ngọc Ánh', 'Quản lý Thu mua Nguyên liệu', 'anh.pn@quehuong.vn', '0989888000', false),
(16, 11, 'Vũ Thành Đạt', 'Kỹ sư Trưởng Năng lượng', 'dat.vt@greenenergy.vn', '0913999000', true),
(17, 12, 'Đỗ Hùng Cường', 'Chủ chuỗi', 'cuong.dohung@gmail.com', '0903456789', true),
(18, 13, 'Bùi Văn Bình', 'Chủ tịch HĐQT', 'binh.bv@thaibinhcorp.com', '0905111222', true),
(19, 14, 'Tạ Quang Tiến', 'Giám đốc Nhà máy', 'tien.tq@tantien.com.vn', '0914222333', true),
(20, 15, 'Trần Hải Nam', 'Giám đốc Xuất nhập khẩu', 'nam.th@hainamexport.vn', '0938333444', true)
ON CONFLICT (id) DO NOTHING;

SELECT setval('contacts_id_seq', (SELECT GREATEST(MAX(id), 1) FROM contacts));

-- 4.4 Interactions (40 sample interactions in the last 60 days)
INSERT INTO interactions (id, customer_id, contact_id, user_id, type, subject, content, interaction_time, next_follow_up) VALUES
(1, 1, 1, 2, 'call', 'Tư vấn giải pháp CRM', 'Gọi điện thoại trao đổi về nhu cầu quản lý khách hàng của Sao Mai Tech. Khách quan tâm gói doanh nghiệp.', NOW() - INTERVAL '58 days', CURRENT_DATE - INTERVAL '50 days'),
(2, 1, 1, 2, 'meeting', 'Demo tính năng phần mềm', 'Gặp mặt trực tiếp tại trụ sở khách hàng để demo các phân hệ CRM.', NOW() - INTERVAL '49 days', CURRENT_DATE - INTERVAL '40 days'),
(3, 1, 2, 2, 'email', 'Gửi báo giá chính thức', 'Gửi báo giá chi tiết và dự thảo hợp đồng qua email cho phòng Mua hàng.', NOW() - INTERVAL '39 days', CURRENT_DATE - INTERVAL '30 days'),
(4, 1, 1, 2, 'call', 'Hỏi thăm phản hồi báo giá', 'Khách hàng đang trình HĐQT phê duyệt ngân sách dự toán.', NOW() - INTERVAL '28 days', CURRENT_DATE + INTERVAL '2 days'),
(5, 2, 3, 2, 'meeting', 'Khảo sát quy trình nghiệp vụ', 'Trao đổi với TGĐ Bảo về luồng chăm sóc khách hàng của Á Châu Soft.', NOW() - INTERVAL '55 days', CURRENT_DATE - INTERVAL '45 days'),
(6, 2, 4, 2, 'call', 'Xác nhận thông tin xuất hóa đơn', 'Liên hệ kế toán Phương để xin thông tin MST và đăng ký kinh doanh.', NOW() - INTERVAL '44 days', CURRENT_DATE - INTERVAL '35 days'),
(7, 2, 3, 2, 'email', 'Gửi tài liệu giải pháp kỹ thuật', 'Email tài liệu API và sơ đồ tích hợp hệ thống nội bộ.', NOW() - INTERVAL '33 days', CURRENT_DATE + INTERVAL '1 day'),
(8, 3, 5, 3, 'call', 'Giới thiệu dịch vụ vận tải', 'Gọi điện chào gói hỗ trợ số hóa điều vận xe tải Bắc Nam.', NOW() - INTERVAL '52 days', CURRENT_DATE - INTERVAL '42 days'),
(9, 3, 5, 3, 'meeting', 'Gặp mặt tại Hải Phòng', 'Trao đổi cụ thể với anh Long về việc trang bị GPS và quản lý khách vận tải.', NOW() - INTERVAL '41 days', CURRENT_DATE - INTERVAL '25 days'),
(10, 3, 5, 3, 'note', 'Ghi chú ngân sách', 'Khách dự kiến triển khai vào Quý 4, hiện ưu tiên nâng cấp đội xe.', NOW() - INTERVAL '24 days', CURRENT_DATE + INTERVAL '5 days'),
(11, 4, 6, 3, 'call', 'Tư vấn danh mục đầu tư', 'Tư vấn thông tin thị trường và danh mục cổ phiếu tiềm năng.', NOW() - INTERVAL '48 days', CURRENT_DATE - INTERVAL '38 days'),
(12, 4, 6, 3, 'email', 'Báo cáo phân tích vĩ mô', 'Gửi báo cáo phân tích ngành bán lẻ và công nghệ.', NOW() - INTERVAL '35 days', CURRENT_DATE - INTERVAL '20 days'),
(13, 4, 6, 3, 'call', 'Nhắc lịch tái cơ cấu vốn', 'Khách hàng dự định giải ngân thêm 500 triệu vào tuần tới.', NOW() - INTERVAL '15 days', CURRENT_DATE),
(14, 5, 7, 2, 'call', 'Tiếp cận khách hàng mới', 'Gọi điện chào dịch vụ qua số hotline công ty.', NOW() - INTERVAL '50 days', CURRENT_DATE - INTERVAL '40 days'),
(15, 5, 7, 2, 'email', 'Catalogue giới thiệu năng lực', 'Gửi hồ sơ năng lực công ty và các dự án tiêu biểu.', NOW() - INTERVAL '38 days', CURRENT_DATE - INTERVAL '25 days'),
(16, 5, 7, 2, 'call', 'Hẹn lịch họp trực tiếp', 'Khách bận công tác Đà Nẵng, hẹn liên hệ lại vào đầu tháng tới.', NOW() - INTERVAL '20 days', CURRENT_DATE + INTERVAL '4 days'),
(17, 6, 8, 2, 'meeting', 'Đàm phán hợp đồng cung cấp', 'Họp với PTGĐ Thắng chốt các điều khoản bảo mật và tiến độ thanh toán.', NOW() - INTERVAL '45 days', CURRENT_DATE - INTERVAL '35 days'),
(18, 6, 9, 2, 'email', 'Gửi biên bản nghiệm thu đợt 1', 'Đã hoàn thành triển khai thử nghiệm tại 2 chi nhánh.', NOW() - INTERVAL '30 days', CURRENT_DATE - INTERVAL '15 days'),
(19, 6, 8, 2, 'call', 'Chăm sóc định kỳ', 'Kiểm tra độ hài lòng của người dùng tại các chi nhánh. Đánh giá tốt.', NOW() - INTERVAL '12 days', CURRENT_DATE + INTERVAL '3 days'),
(20, 7, 10, 3, 'meeting', 'Ký kết thỏa thuận hợp tác', 'Ký hợp đồng dịch vụ giám sát chất lượng dược phẩm với chị Sen.', NOW() - INTERVAL '42 days', CURRENT_DATE - INTERVAL '30 days'),
(21, 7, 11, 3, 'call', 'Hỗ trợ kỹ thuật cấu hình', 'Hướng dẫn kỹ sư Tùng kết nối cổng API.', NOW() - INTERVAL '26 days', CURRENT_DATE - INTERVAL '10 days'),
(22, 7, 10, 3, 'email', 'Gửi báo cáo hiệu năng tháng', 'Báo cáo thời gian phản hồi hệ thống đạt 99.98% uptime.', NOW() - INTERVAL '8 days', CURRENT_DATE + INTERVAL '6 days'),
(23, 8, 12, 2, 'call', 'Tư vấn nâng cấp phần mềm CRM', 'Chị Nguyệt muốn bổ sung tính năng gửi SMS Brandname đặt lịch cho khách.', NOW() - INTERVAL '36 days', CURRENT_DATE - INTERVAL '22 days'),
(24, 8, 12, 2, 'meeting', 'Demo module SMS Marketing', 'Khách hàng rất hài lòng và đồng ý chi thêm ngân sách tích hợp.', NOW() - INTERVAL '18 days', CURRENT_DATE - INTERVAL '5 days'),
(25, 8, 12, 2, 'note', 'Theo dõi thanh toán hóa đơn', 'Kế toán báo đã nhận được tiền đặt cọc 50%.', NOW() - INTERVAL '4 days', CURRENT_DATE),
(26, 9, 13, 3, 'call', 'Trao đổi về giá cước vận tải biển', 'Thảo luận với anh Hùng về việc tích hợp biểu phí vận tải tự động.', NOW() - INTERVAL '34 days', CURRENT_DATE - INTERVAL '20 days'),
(27, 9, 13, 3, 'email', 'Gửi tài liệu đặc tả kỹ thuật', 'Email tài liệu kết nối EDI với hệ thống cảng biển.', NOW() - INTERVAL '19 days', CURRENT_DATE - INTERVAL '7 days'),
(28, 9, 13, 3, 'meeting', 'Họp nghiệm thu hệ thống giai đoạn 1', 'Hai bên đã ký biên bản nghiệm thu kỹ thuật.', NOW() - INTERVAL '6 days', CURRENT_DATE + INTERVAL '8 days'),
(29, 10, 14, 2, 'meeting', 'Đánh giá phần mềm quản lý bán', 'Khảo sát thực tế tại nhà hàng chi nhánh Quận 1.', NOW() - INTERVAL '32 days', CURRENT_DATE - INTERVAL '18 days'),
(30, 10, 15, 2, 'call', 'Hỗ trợ nhập liệu kho nguyên liệu', 'Chị Ánh cần hỗ trợ import file Excel tồn kho thực tế.', NOW() - INTERVAL '16 days', CURRENT_DATE - INTERVAL '2 days'),
(31, 10, 14, 2, 'note', 'Ghi chú yêu cầu tùy chỉnh', 'Khách yêu cầu bổ sung báo cáo tiêu hao gia vị theo công thức nấu.', NOW() - INTERVAL '5 days', CURRENT_DATE + INTERVAL '2 days'),
(32, 11, 16, 3, 'meeting', 'Ký hợp đồng bảo trì năm', 'Hợp đồng bảo trì hệ thống SCADA điện mặt trời áp mái.', NOW() - INTERVAL '29 days', CURRENT_DATE - INTERVAL '14 days'),
(33, 11, 16, 3, 'call', 'Cảnh báo biến tần quá nhiệt', 'Thông báo sự cố cảm biến tại dàn mái nhà xưởng Bình Dương.', NOW() - INTERVAL '14 days', CURRENT_DATE - INTERVAL '1 day'),
(34, 11, 16, 3, 'email', 'Gửi biên bản xử lý sự cố', 'Đội kỹ thuật đã thay thế quạt tản nhiệt, hệ thống bình thường.', NOW() - INTERVAL '3 days', CURRENT_DATE + INTERVAL '10 days'),
(35, 12, 17, 2, 'call', 'Tư vấn mở rộng điểm bán', 'Anh Cường có kế hoạch mở thêm 3 cửa hàng bán lẻ tiện lợi.', NOW() - INTERVAL '22 days', CURRENT_DATE - INTERVAL '8 days'),
(36, 12, 17, 2, 'email', 'Báo giá thiết bị POS thu ngân', 'Gửi báo giá trọn gói combo máy in + máy quét mã vạch.', NOW() - INTERVAL '10 days', CURRENT_DATE),
(37, 13, 18, 3, 'call', 'Hỏi thăm tình hình kinh doanh', 'Doanh nghiệp tạm ngừng nhập hàng do thị trường trầm lắng.', NOW() - INTERVAL '45 days', NULL),
(38, 14, 19, 2, 'email', 'Thông báo kết thúc hợp đồng', 'Khách hàng chuyển đổi mô hình gia công, không gia hạn gói dịch vụ.', NOW() - INTERVAL '50 days', NULL),
(39, 15, 20, 3, 'call', 'Liên hệ chăm sóc sau thanh lý', 'Khách hàng chuyển trụ sở sang địa điểm mới, lưu thông tin để tiếp cận sau.', NOW() - INTERVAL '40 days', NULL),
(40, 6, 8, 1, 'note', 'Đánh giá khách hàng VIP (Quản lý)', 'Khách hàng chiến lược của công ty năm 2026. Chỉ đạo nhân viên ưu tiên hỗ trợ 24/7.', NOW() - INTERVAL '2 days', CURRENT_DATE + INTERVAL '15 days')
ON CONFLICT (id) DO NOTHING;

SELECT setval('interactions_id_seq', (SELECT GREATEST(MAX(id), 1) FROM interactions));

-- 5. Grant permissions to non-superuser application role: crm_app
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO crm_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO crm_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO crm_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO crm_app;

-- ====================================================================
-- SEEDING COMPLETED
-- ====================================================================
