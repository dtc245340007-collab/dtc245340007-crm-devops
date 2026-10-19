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

-- Constraint: M?i kh?ch h?ng c? t?i ?a 1 contact is_primary = true
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

-- 4.1 Users (1 manager, 2 staff)
-- admin: Admin@CRM2026!Sec
-- nhanvien01: Staff1@CRM2026!
-- nhanvien02: Staff2@CRM2026!
INSERT INTO users (id, username, password_hash, full_name, role, is_active) VALUES
(1, 'admin', 'scrypt:32768:8:1$s3SP9o4YUJkoPqBE$37d4d9299fd70b11e4908dae6ef44782ac49b22e60015cd250153b6715949f6a8e453cbb1110b1ad915b56a7461073a2ce3dab13faf25a252a1243156dab209e', 'Nguy?n V?n Qu?n L?', 'manager', true),
(2, 'nhanvien01', 'scrypt:32768:8:1$TcEGLM5IxxTrbrqe$6d6fcd1b7a1da1ba4168d5aa13eb7f0fbc39f8de3bee7fb4404c2019935d20c9b7783efd5fbfdb0cf78db64f5112def6af26b29fe6349e7925d8dbbb4ae77ea3', 'Tr?n Th? Lan', 'staff', true),
(3, 'nhanvien02', 'scrypt:32768:8:1$djGnBjrUzfFSm7iy$cbb4fe87911995324011433205d20681c00199f32bb6e2ebaecdcd00994d372aaec8233317d702ddc2ea6bd0c03511bc0521114172d8aea1c606f71612543d63', 'L? V?n Ho?ng', 'staff', true)
ON CONFLICT (id) DO NOTHING;

SELECT setval('users_id_seq', (SELECT GREATEST(MAX(id), 1) FROM users));

-- 4.2 Customers (15 sample customers: 5 lead, 7 active, 3 inactive)
INSERT INTO customers (id, customer_code, name, email, phone, company, address, status, assigned_to) VALUES
(1, 'KH-001', 'C?ng ty C? ph?n C?ng ngh? Sao Mai', 'contact@saomai.vn', '02438889999', 'Sao Mai Tech JSC', 'T?a nh? Sao Mai, C?u Gi?y, H? N?i', 'lead', 2),
(2, 'KH-002', 'C?ng ty TNHH Ph?n m?m ? Ch?u', 'info@achau-soft.com', '02839998888', '? Ch?u Software Co., Ltd', 'Qu?n 1, TP. H? Ch? Minh', 'lead', 2),
(3, 'KH-003', 'Doanh nghi?p V?n t?i Ho?ng Long', 'hoanglong@vantai.vn', '02253887766', 'V?n t?i Ho?ng Long', 'L? Th?nh T?ng, H?i Ph?ng', 'lead', 3),
(4, 'KH-004', '?ng Nguy?n Anh Tu?n', 'tuan.nguyen@gmail.com', '0912345678', 'C? nh?n ??u t?', 'Ba ??nh, H? N?i', 'lead', 3),
(5, 'KH-005', 'C?ng ty TNHH D?ch v? ??i Ph?t', 'daiphat@daiphatcorp.com', '02363778899', '??i Ph?t Services', 'H?i Ch?u, ?? N?ng', 'lead', 2),
(6, 'KH-006', 'T?p ?o?n ??a ?c Th?ng Long', 'bds@thanglongcorp.com', '02437776655', 'Th?ng Long Group', 'Nam T? Li?m, H? N?i', 'active', 2),
(7, 'KH-007', 'C?ng ty C? ph?n D??c ph?m Hoa Sen', 'duoc@hoasenpharma.vn', '02838887711', 'Hoa Sen Pharma', 'Qu?n T?n B?nh, TP. H? Ch? Minh', 'active', 3),
(8, 'KH-008', 'B? Ph?m Th? Minh Nguy?t', 'nguyet.pham@outlook.com', '0987654321', 'Th?m m? vi?n Nguy?t Nga', '??ng ?a, H? N?i', 'active', 2),
(9, 'KH-009', 'C?ng ty Logistics ??ng D??ng', 'ops@dongduonglog.com', '02253665544', '??ng D??ng Logistics', 'Ng? Quy?n, H?i Ph?ng', 'active', 3),
(10, 'KH-010', 'Chu?i Nh? h?ng ?m th?c Qu? H??ng', 'fnb@quehuong.vn', '02835554433', 'Qu? H??ng F&B Group', 'Qu?n 3, TP. H? Ch? Minh', 'active', 2),
(11, 'KH-011', 'C?ng ty N?ng l??ng Xanh Vi?t', 'info@greenenergy.vn', '02436665522', 'Green Energy Vietnam', 'Thanh Xu?n, H? N?i', 'active', 3),
(12, 'KH-012', '?ng ?? H?ng C??ng', 'cuong.dohung@gmail.com', '0903456789', 'Chu?i b?n l? C??ng Ph?t', 'H? ??ng, H? N?i', 'active', 2),
(13, 'KH-013', 'C?ng ty TNHH Th??ng m?i Th?i B?nh', 'tb@thaibinhcorp.com', '02273881122', 'Th?i B?nh Trading', 'TP. Th?i B?nh', 'inactive', 3),
(14, 'KH-014', 'C?ng ty C? kh? T?n Ti?n', 'kinhdoanh@tantien.com.vn', '02439992211', 'T?n Ti?n Machinery', 'Long Bi?n, H? N?i', 'inactive', 2),
(15, 'KH-015', 'Doanh nghi?p Xu?t nh?p kh?u H?i Nam', 'hainam@hainamexport.vn', '02363554422', 'H?i Nam Export Co.', 'S?n Tr?, ?? N?ng', 'inactive', 3)
ON CONFLICT (id) DO NOTHING;

SELECT setval('customers_id_seq', (SELECT GREATEST(MAX(id), 1) FROM customers));

-- 4.3 Contacts (20 contacts)
INSERT INTO contacts (id, customer_id, full_name, position, email, phone, is_primary) VALUES
(1, 1, 'Nguy?n V?n Minh', 'Gi?m ??c C?ng ngh? (CTO)', 'minh.nv@saomai.vn', '0912111222', true),
(2, 1, 'Tr?n Thu H?', 'Tr??ng ph?ng Mua h?ng', 'ha.tt@saomai.vn', '0912111333', false),
(3, 2, 'L? Qu?c B?o', 'T?ng Gi?m ??c', 'bao.le@achau-soft.com', '0988222333', true),
(4, 2, 'V? Mai Ph??ng', 'K? to?n tr??ng', 'phuong.vm@achau-soft.com', '0988222444', false),
(5, 3, 'Ho?ng ??nh Long', 'Ch? doanh nghi?p', 'long@vantaihoanglong.vn', '0904333444', true),
(6, 4, 'Nguy?n Anh Tu?n', 'Nh? ??u t? c? nh?n', 'tuan.nguyen@gmail.com', '0912345678', true),
(7, 5, 'Phan V?n ??i', 'Gi?m ??c ?i?u h?nh', 'dai.pv@daiphatcorp.com', '0935444555', true),
(8, 6, 'Nguy?n ??c Th?ng', 'Ph? T?ng Gi?m ??c D? ?n', 'thang.nd@thanglongcorp.com', '0903555666', true),
(9, 6, '??ng Th? Thu Th?o', 'Th? k? Ban T?ng Gi?m ??c', 'thao.dt@thanglongcorp.com', '0903555777', false),
(10, 7, 'B?i Th? Sen', 'Gi?m ??c R&D', 'sen.bt@hoasenpharma.vn', '0918666777', true),
(11, 7, 'Ng? Thanh T?ng', 'Tr??ng ph?ng K? thu?t', 'tung.nt@hoasenpharma.vn', '0918666888', false),
(12, 8, 'Ph?m Th? Minh Nguy?t', 'Ch? th?m m? vi?n', 'nguyet.pham@outlook.com', '0987654321', true),
(13, 9, 'Tr??ng Qu?c H?ng', 'Gi?m ??c V?n h?nh', 'hung.tq@dongduonglog.com', '0904777888', true),
(14, 10, 'L? V?nh Qu?', 'Gi?m ??c Chu?i', 'que.lv@quehuong.vn', '0989888999', true),
(15, 10, 'Ph?m Ng?c ?nh', 'Qu?n l? Thu mua Nguy?n li?u', 'anh.pn@quehuong.vn', '0989888000', false),
(16, 11, 'V? Th?nh ??t', 'K? s? Tr??ng N?ng l??ng', 'dat.vt@greenenergy.vn', '0913999000', true),
(17, 12, '?? H?ng C??ng', 'Ch? chu?i', 'cuong.dohung@gmail.com', '0903456789', true),
(18, 13, 'B?i V?n B?nh', 'Ch? t?ch H?QT', 'binh.bv@thaibinhcorp.com', '0905111222', true),
(19, 14, 'T? Quang Ti?n', 'Gi?m ??c Nh? m?y', 'tien.tq@tantien.com.vn', '0914222333', true),
(20, 15, 'Tr?n H?i Nam', 'Gi?m ??c Xu?t nh?p kh?u', 'nam.th@hainamexport.vn', '0938333444', true)
ON CONFLICT (id) DO NOTHING;

SELECT setval('contacts_id_seq', (SELECT GREATEST(MAX(id), 1) FROM contacts));

-- 4.4 Interactions (40 sample interactions in the last 60 days)
INSERT INTO interactions (id, customer_id, contact_id, user_id, type, subject, content, interaction_time, next_follow_up) VALUES
(1, 1, 1, 2, 'call', 'T? v?n gi?i ph?p CRM', 'G?i ?i?n tho?i trao ??i v? nhu c?u qu?n l? kh?ch h?ng c?a Sao Mai Tech. Kh?ch quan t?m g?i doanh nghi?p.', NOW() - INTERVAL '58 days', CURRENT_DATE - INTERVAL '50 days'),
(2, 1, 1, 2, 'meeting', 'Demo t?nh n?ng ph?n m?m', 'G?p m?t tr?c ti?p t?i tr? s? kh?ch h?ng ?? demo c?c ph?n h? CRM.', NOW() - INTERVAL '49 days', CURRENT_DATE - INTERVAL '40 days'),
(3, 1, 2, 2, 'email', 'G?i b?o gi? ch?nh th?c', 'G?i b?o gi? chi ti?t v? d? th?o h?p ??ng qua email cho ph?ng Mua h?ng.', NOW() - INTERVAL '39 days', CURRENT_DATE - INTERVAL '30 days'),
(4, 1, 1, 2, 'call', 'H?i th?m ph?n h?i b?o gi?', 'Kh?ch h?ng ?ang tr?nh H?QT ph? duy?t ng?n s?ch d? to?n.', NOW() - INTERVAL '28 days', CURRENT_DATE + INTERVAL '2 days'),
(5, 2, 3, 2, 'meeting', 'Kh?o s?t quy tr?nh nghi?p v?', 'Trao ??i v?i TG? B?o v? lu?ng ch?m s?c kh?ch h?ng c?a ? Ch?u Soft.', NOW() - INTERVAL '55 days', CURRENT_DATE - INTERVAL '45 days'),
(6, 2, 4, 2, 'call', 'X?c nh?n th?ng tin xu?t h?a ??n', 'Li?n h? k? to?n Ph??ng ?? xin th?ng tin MST v? ??ng k? kinh doanh.', NOW() - INTERVAL '44 days', CURRENT_DATE - INTERVAL '35 days'),
(7, 2, 3, 2, 'email', 'G?i t?i li?u gi?i ph?p k? thu?t', 'Email t?i li?u API v? s? ?? t?ch h?p h? th?ng n?i b?.', NOW() - INTERVAL '33 days', CURRENT_DATE + INTERVAL '1 day'),
(8, 3, 5, 3, 'call', 'Gi?i thi?u d?ch v? v?n t?i', 'G?i ?i?n ch?o g?i h? tr? s? h?a ?i?u v?n xe t?i B?c Nam.', NOW() - INTERVAL '52 days', CURRENT_DATE - INTERVAL '42 days'),
(9, 3, 5, 3, 'meeting', 'G?p m?t t?i H?i Ph?ng', 'Trao ??i c? th? v?i anh Long v? vi?c trang b? GPS v? qu?n l? kh?ch v?n t?i.', NOW() - INTERVAL '41 days', CURRENT_DATE - INTERVAL '25 days'),
(10, 3, 5, 3, 'note', 'Ghi ch? ng?n s?ch', 'Kh?ch d? ki?n tri?n khai v?o Qu? 4, hi?n ?u ti?n n?ng c?p ??i xe.', NOW() - INTERVAL '24 days', CURRENT_DATE + INTERVAL '5 days'),
(11, 4, 6, 3, 'call', 'T? v?n danh m?c ??u t?', 'T? v?n th?ng tin th? tr??ng v? danh m?c c? phi?u ti?m n?ng.', NOW() - INTERVAL '48 days', CURRENT_DATE - INTERVAL '38 days'),
(12, 4, 6, 3, 'email', 'B?o c?o ph?n t?ch v? m?', 'G?i b?o c?o ph?n t?ch ng?nh b?n l? v? c?ng ngh?.', NOW() - INTERVAL '35 days', CURRENT_DATE - INTERVAL '20 days'),
(13, 4, 6, 3, 'call', 'Nh?c l?ch t?i c? c?u v?n', 'Kh?ch h?ng d? ??nh gi?i ng?n th?m 500 tri?u v?o tu?n t?i.', NOW() - INTERVAL '15 days', CURRENT_DATE),
(14, 5, 7, 2, 'call', 'Ti?p c?n kh?ch h?ng m?i', 'G?i ?i?n ch?o d?ch v? qua s? hotline c?ng ty.', NOW() - INTERVAL '50 days', CURRENT_DATE - INTERVAL '40 days'),
(15, 5, 7, 2, 'email', 'Catalogue gi?i thi?u n?ng l?c', 'G?i h? s? n?ng l?c c?ng ty v? c?c d? ?n ti?u bi?u.', NOW() - INTERVAL '38 days', CURRENT_DATE - INTERVAL '25 days'),
(16, 5, 7, 2, 'call', 'H?n l?ch h?p tr?c ti?p', 'Kh?ch b?n c?ng t?c ?? N?ng, h?n li?n h? l?i v?o ??u th?ng t?i.', NOW() - INTERVAL '20 days', CURRENT_DATE + INTERVAL '4 days'),
(17, 6, 8, 2, 'meeting', '??m ph?n h?p ??ng cung c?p', 'H?p v?i PTG? Th?ng ch?t c?c ?i?u kho?n b?o m?t v? ti?n ?? thanh to?n.', NOW() - INTERVAL '45 days', CURRENT_DATE - INTERVAL '35 days'),
(18, 6, 9, 2, 'email', 'G?i bi?n b?n nghi?m thu ??t 1', '?? ho?n th?nh tri?n khai th? nghi?m t?i 2 chi nh?nh.', NOW() - INTERVAL '30 days', CURRENT_DATE - INTERVAL '15 days'),
(19, 6, 8, 2, 'call', 'Ch?m s?c ??nh k?', 'Ki?m tra ?? h?i l?ng c?a ng??i d?ng t?i c?c chi nh?nh. ??nh gi? t?t.', NOW() - INTERVAL '12 days', CURRENT_DATE + INTERVAL '3 days'),
(20, 7, 10, 3, 'meeting', 'K? k?t th?a thu?n h?p t?c', 'K? h?p ??ng d?ch v? gi?m s?t ch?t l??ng d??c ph?m v?i ch? Sen.', NOW() - INTERVAL '42 days', CURRENT_DATE - INTERVAL '30 days'),
(21, 7, 11, 3, 'call', 'H? tr? k? thu?t c?u h?nh', 'H??ng d?n k? s? T?ng k?t n?i c?ng API.', NOW() - INTERVAL '26 days', CURRENT_DATE - INTERVAL '10 days'),
(22, 7, 10, 3, 'email', 'G?i b?o c?o hi?u n?ng th?ng', 'B?o c?o th?i gian ph?n h?i h? th?ng ??t 99.98% uptime.', NOW() - INTERVAL '8 days', CURRENT_DATE + INTERVAL '6 days'),
(23, 8, 12, 2, 'call', 'T? v?n n?ng c?p ph?n m?m CRM', 'Ch? Nguy?t mu?n b? sung t?nh n?ng g?i SMS Brandname ??t l?ch cho kh?ch.', NOW() - INTERVAL '36 days', CURRENT_DATE - INTERVAL '22 days'),
(24, 8, 12, 2, 'meeting', 'Demo module SMS Marketing', 'Kh?ch h?ng r?t h?i l?ng v? ??ng ? chi th?m ng?n s?ch t?ch h?p.', NOW() - INTERVAL '18 days', CURRENT_DATE - INTERVAL '5 days'),
(25, 8, 12, 2, 'note', 'Theo d?i thanh to?n h?a ??n', 'K? to?n b?o ?? nh?n ???c ti?n ??t c?c 50%.', NOW() - INTERVAL '4 days', CURRENT_DATE),
(26, 9, 13, 3, 'call', 'Trao ??i v? gi? c??c v?n t?i bi?n', 'Th?o lu?n v?i anh H?ng v? vi?c t?ch h?p bi?u ph? v?n t?i t? ??ng.', NOW() - INTERVAL '34 days', CURRENT_DATE - INTERVAL '20 days'),
(27, 9, 13, 3, 'email', 'G?i t?i li?u ??c t? k? thu?t', 'Email t?i li?u k?t n?i EDI v?i h? th?ng c?ng bi?n.', NOW() - INTERVAL '19 days', CURRENT_DATE - INTERVAL '7 days'),
(28, 9, 13, 3, 'meeting', 'H?p nghi?m thu h? th?ng giai ?o?n 1', 'Hai b?n ?? k? bi?n b?n nghi?m thu k? thu?t.', NOW() - INTERVAL '6 days', CURRENT_DATE + INTERVAL '8 days'),
(29, 10, 14, 2, 'meeting', '??nh gi? ph?n m?m qu?n l? b?n', 'Kh?o s?t th?c t? t?i nh? h?ng chi nh?nh Qu?n 1.', NOW() - INTERVAL '32 days', CURRENT_DATE - INTERVAL '18 days'),
(30, 10, 15, 2, 'call', 'H? tr? nh?p li?u kho nguy?n li?u', 'Ch? ?nh c?n h? tr? import file Excel t?n kho th?c t?.', NOW() - INTERVAL '16 days', CURRENT_DATE - INTERVAL '2 days'),
(31, 10, 14, 2, 'note', 'Ghi ch? y?u c?u t?y ch?nh', 'Kh?ch y?u c?u b? sung b?o c?o ti?u hao gia v? theo c?ng th?c n?u.', NOW() - INTERVAL '5 days', CURRENT_DATE + INTERVAL '2 days'),
(32, 11, 16, 3, 'meeting', 'K? h?p ??ng b?o tr? n?m', 'H?p ??ng b?o tr? h? th?ng SCADA ?i?n m?t tr?i ?p m?i.', NOW() - INTERVAL '29 days', CURRENT_DATE - INTERVAL '14 days'),
(33, 11, 16, 3, 'call', 'C?nh b?o bi?n t?n qu? nhi?t', 'Th?ng b?o s? c? c?m bi?n t?i d?n m?i nh? x??ng B?nh D??ng.', NOW() - INTERVAL '14 days', CURRENT_DATE - INTERVAL '1 day'),
(34, 11, 16, 3, 'email', 'G?i bi?n b?n x? l? s? c?', '??i k? thu?t ?? thay th? qu?t t?n nhi?t, h? th?ng b?nh th??ng.', NOW() - INTERVAL '3 days', CURRENT_DATE + INTERVAL '10 days'),
(35, 12, 17, 2, 'call', 'T? v?n m? r?ng ?i?m b?n', 'Anh C??ng c? k? ho?ch m? th?m 3 c?a h?ng b?n l? ti?n l?i.', NOW() - INTERVAL '22 days', CURRENT_DATE - INTERVAL '8 days'),
(36, 12, 17, 2, 'email', 'B?o gi? thi?t b? POS thu ng?n', 'G?i b?o gi? tr?n g?i combo m?y in + m?y qu?t m? v?ch.', NOW() - INTERVAL '10 days', CURRENT_DATE),
(37, 13, 18, 3, 'call', 'H?i th?m t?nh h?nh kinh doanh', 'Doanh nghi?p t?m ng?ng nh?p h?ng do th? tr??ng tr?m l?ng.', NOW() - INTERVAL '45 days', NULL),
(38, 14, 19, 2, 'email', 'Th?ng b?o k?t th?c h?p ??ng', 'Kh?ch h?ng chuy?n ??i m? h?nh gia c?ng, kh?ng gia h?n g?i d?ch v?.', NOW() - INTERVAL '50 days', NULL),
(39, 15, 20, 3, 'call', 'Li?n h? ch?m s?c sau thanh l?', 'Kh?ch h?ng chuy?n tr? s? sang ??a ?i?m m?i, l?u th?ng tin ?? ti?p c?n sau.', NOW() - INTERVAL '40 days', NULL),
(40, 6, 8, 1, 'note', '??nh gi? kh?ch h?ng VIP (Qu?n l?)', 'Kh?ch h?ng chi?n l??c c?a c?ng ty n?m 2026. Ch? ??o nh?n vi?n ?u ti?n h? tr? 24/7.', NOW() - INTERVAL '2 days', CURRENT_DATE + INTERVAL '15 days')
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
