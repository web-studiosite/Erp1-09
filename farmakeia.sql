-- ============================================
-- FARMAKEIA - PHARMACY MANAGEMENT SYSTEM
-- SQL COMPLETO E DEFINITIVO
-- Moeda: MZN (Metical Moçambicano)
-- ============================================

-- EXTENSÕES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- TABELAS PRINCIPAIS
-- ============================================

-- 1. LOJAS/FARMÁCIAS
CREATE TABLE IF NOT EXISTS stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    logo_url TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    currency TEXT DEFAULT 'MZN',
    tax_number TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- 2. PERFIS DE USUÁRIO
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    store_id UUID REFERENCES stores(id) ON DELETE SET NULL,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    role TEXT NOT NULL CHECK (role IN ('admin', 'cashier')),
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. USUÁRIOS DAS LOJAS
CREATE TABLE IF NOT EXISTS store_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'cashier')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, user_id)
);

-- 4. FORNECEDORES
CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    tax_number TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. PRODUTOS
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    code TEXT,
    barcode TEXT,
    active_ingredient TEXT,
    dosage TEXT,
    manufacturer TEXT,
    base_unit TEXT NOT NULL DEFAULT 'unidade',
    is_fractionable BOOLEAN DEFAULT FALSE,
    min_stock NUMERIC(12,2) DEFAULT 0,
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, code),
    UNIQUE(store_id, barcode)
);

-- 6. UNIDADES DO PRODUTO
CREATE TABLE IF NOT EXISTS product_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_name TEXT NOT NULL,
    conversion_to_base NUMERIC(12,4) NOT NULL DEFAULT 1,
    is_base BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. EMBALAGENS
CREATE TABLE IF NOT EXISTS product_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    package_name TEXT NOT NULL,
    quantity NUMERIC(12,2) NOT NULL,
    unit_id UUID REFERENCES product_units(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. LOTES
CREATE TABLE IF NOT EXISTS batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    batch_number TEXT NOT NULL,
    expiry_date DATE NOT NULL,
    quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(12,2) NOT NULL,
    supplier_id UUID REFERENCES suppliers(id),
    purchase_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, batch_number)
);

-- 9. ESTOQUE DO ARMAZÉM
CREATE TABLE IF NOT EXISTS warehouse_stock (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES batches(id),
    quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
    unit_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(product_id, batch_id)
);

-- 10. MOVIMENTAÇÕES DE ESTOQUE
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES batches(id),
    movement_type TEXT NOT NULL CHECK (movement_type IN ('entry', 'sale', 'transfer_out', 'transfer_in', 'adjustment', 'loss', 'expiry', 'return', 'reversal')),
    quantity NUMERIC(12,2) NOT NULL,
    unit_cost NUMERIC(12,2),
    reference_id UUID,
    reference_type TEXT,
    notes TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. COMPRAS/ENTRADAS
CREATE TABLE IF NOT EXISTS purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES suppliers(id),
    invoice_number TEXT,
    total_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. ITENS DA COMPRA
CREATE TABLE IF NOT EXISTS purchase_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    batch_id UUID REFERENCES batches(id),
    quantity NUMERIC(12,2) NOT NULL,
    unit_cost NUMERIC(12,2) NOT NULL,
    total_cost NUMERIC(12,2) NOT NULL,
    expiry_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. TRANSFERÊNCIAS
CREATE TABLE IF NOT EXISTS transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    from_location TEXT DEFAULT 'warehouse',
    to_location TEXT DEFAULT 'shelf',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    notes TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 14. ITENS DA TRANSFERÊNCIA
CREATE TABLE IF NOT EXISTS transfer_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    batch_id UUID REFERENCES batches(id),
    quantity NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. VENDAS
CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    receipt_number TEXT NOT NULL UNIQUE,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'mpesa', 'card', 'transfer', 'other')),
    amount_received NUMERIC(12,2) NOT NULL DEFAULT 0,
    change_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT DEFAULT 'completed' CHECK (status IN ('completed', 'cancelled', 'refunded')),
    cashier_id UUID NOT NULL REFERENCES profiles(id),
    is_refunded BOOLEAN DEFAULT FALSE,
    refunded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 16. ITENS DA VENDA
CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    batch_id UUID REFERENCES batches(id),
    unit_name TEXT NOT NULL,
    quantity NUMERIC(12,2) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    total_price NUMERIC(12,2) NOT NULL,
    unit_cost NUMERIC(12,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 17. CAIXAS/REGISTRADORAS
CREATE TABLE IF NOT EXISTS cash_registers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    cashier_id UUID NOT NULL REFERENCES profiles(id),
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    opening_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    expected_amount NUMERIC(12,2) DEFAULT 0,
    actual_amount NUMERIC(12,2),
    difference_amount NUMERIC(12,2) DEFAULT 0,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 18. MOVIMENTAÇÕES DO CAIXA
CREATE TABLE IF NOT EXISTS cash_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    register_id UUID NOT NULL REFERENCES cash_registers(id),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('sale', 'refund', 'withdrawal', 'deposit', 'expense', 'opening', 'closing', 'adjustment')),
    amount NUMERIC(12,2) NOT NULL,
    description TEXT,
    payment_method TEXT,
    reference_id UUID,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 19. RECIBOS
CREATE TABLE IF NOT EXISTS receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    reference_id UUID NOT NULL,
    reference_type TEXT NOT NULL,
    receipt_number TEXT NOT NULL,
    receipt_data JSONB NOT NULL,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 20. PERDAS
CREATE TABLE IF NOT EXISTS losses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    batch_id UUID REFERENCES batches(id),
    quantity NUMERIC(12,2) NOT NULL,
    reason TEXT NOT NULL,
    notes TEXT,
    unit_cost NUMERIC(12,2),
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 21. TRANSAÇÕES DE CAPITAL
CREATE TABLE IF NOT EXISTS capital_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('initial', 'investment', 'withdrawal')),
    amount NUMERIC(12,2) NOT NULL,
    description TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 22. TRANSAÇÕES FINANCEIRAS
CREATE TABLE IF NOT EXISTS financial_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('revenue', 'cost', 'expense', 'profit', 'loss', 'adjustment')),
    amount NUMERIC(12,2) NOT NULL,
    description TEXT,
    reference_id UUID,
    reference_type TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 23. FECHAMENTOS DIÁRIOS
CREATE TABLE IF NOT EXISTS daily_closings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    register_id UUID REFERENCES cash_registers(id),
    closing_date DATE NOT NULL,
    total_sales NUMERIC(12,2) DEFAULT 0,
    total_refunds NUMERIC(12,2) DEFAULT 0,
    total_withdrawals NUMERIC(12,2) DEFAULT 0,
    total_expenses NUMERIC(12,2) DEFAULT 0,
    expected_amount NUMERIC(12,2) DEFAULT 0,
    actual_amount NUMERIC(12,2) DEFAULT 0,
    difference_amount NUMERIC(12,2) DEFAULT 0,
    status TEXT DEFAULT 'closed',
    notes TEXT,
    closed_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 24. LOGS DE AUDITORIA
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id),
    user_id UUID REFERENCES profiles(id),
    user_role TEXT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 25. CONFIGURAÇÕES
CREATE TABLE IF NOT EXISTS settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, setting_key)
);

-- ============================================
-- ÍNDICES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_products_store ON products(store_id);
CREATE INDEX IF NOT EXISTS idx_products_code ON products(code);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_batches_product ON batches(product_id);
CREATE INDEX IF NOT EXISTS idx_batches_expiry ON batches(expiry_date);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON warehouse_stock(product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_stock_batch ON warehouse_stock(batch_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_store ON stock_movements(store_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_sales_store ON sales(store_id);
CREATE INDEX IF NOT EXISTS idx_sales_cashier ON sales(cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(created_at);
CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_cash_registers_store ON cash_registers(store_id);
CREATE INDEX IF NOT EXISTS idx_cash_registers_status ON cash_registers(status);
CREATE INDEX IF NOT EXISTS idx_cash_movements_register ON cash_movements(register_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_store ON audit_logs(store_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_receipts_reference ON receipts(reference_id, reference_type);
CREATE INDEX IF NOT EXISTS idx_capital_store ON capital_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_financial_store ON financial_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_financial_type ON financial_transactions(transaction_type);

-- ============================================
-- FUNÇÕES AUXILIARES
-- ============================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para updated_at
CREATE TRIGGER update_stores_updated_at BEFORE UPDATE ON stores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_batches_updated_at BEFORE UPDATE ON batches FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_warehouse_stock_updated_at BEFORE UPDATE ON warehouse_stock FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para gerar número de recibo
CREATE OR REPLACE FUNCTION generate_receipt_number(p_store_id UUID, p_prefix TEXT)
RETURNS TEXT AS $$
DECLARE
    v_count INTEGER;
    v_number TEXT;
BEGIN
    SELECT COUNT(*) + 1 INTO v_count FROM sales WHERE store_id = p_store_id AND DATE(created_at) = CURRENT_DATE;
    v_number := p_prefix || '-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(v_count::TEXT, 4, '0');
    RETURN v_number;
END;
$$ LANGUAGE plpgsql;

-- Função para registrar auditoria
CREATE OR REPLACE FUNCTION log_audit(
    p_store_id UUID,
    p_user_id UUID,
    p_user_role TEXT,
    p_action TEXT,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_old_data JSONB,
    p_new_data JSONB
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_logs (store_id, user_id, user_role, action, entity_type, entity_id, old_data, new_data)
    VALUES (p_store_id, p_user_id, p_user_role, p_action, p_entity_type, p_entity_id, p_old_data, p_new_data);
END;
$$ LANGUAGE plpgsql;

-- Função RPC para processar venda completa
CREATE OR REPLACE FUNCTION process_sale(
    p_store_id UUID,
    p_cashier_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_sale_id UUID;
    v_receipt_number TEXT;
    v_total NUMERIC := 0;
    v_item JSONB;
    v_product_id UUID;
    v_batch_id UUID;
    v_unit_name TEXT;
    v_quantity NUMERIC;
    v_unit_price NUMERIC;
    v_unit_cost NUMERIC;
    v_item_total NUMERIC;
    v_stock_quantity NUMERIC;
    v_change NUMERIC;
    v_cashier_role TEXT;
BEGIN
    SELECT role INTO v_cashier_role FROM profiles WHERE id = p_cashier_id;
    IF v_cashier_role IS NULL THEN
        RAISE EXCEPTION 'Caixa não encontrado';
    END IF;

    v_receipt_number := generate_receipt_number(p_store_id, 'VND');

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_quantity := (v_item->>'quantity')::NUMERIC;
        v_unit_price := (v_item->>'unit_price')::NUMERIC;
        v_item_total := v_quantity * v_unit_price;
        v_total := v_total + v_item_total;
    END LOOP;

    IF p_amount_received < v_total THEN
        RAISE EXCEPTION 'Valor recebido insuficiente';
    END IF;
    v_change := p_amount_received - v_total;

    INSERT INTO sales (store_id, receipt_number, total_amount, payment_method, amount_received, change_amount, cashier_id)
    VALUES (p_store_id, v_receipt_number, v_total, p_payment_method, p_amount_received, v_change, p_cashier_id)
    RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_batch_id := NULLIF((v_item->>'batch_id')::TEXT, '')::UUID;
        v_unit_name := v_item->>'unit_name';
        v_quantity := (v_item->>'quantity')::NUMERIC;
        v_unit_price := (v_item->>'unit_price')::NUMERIC;
        v_unit_cost := (v_item->>'unit_cost')::NUMERIC;
        v_item_total := v_quantity * v_unit_price;

        SELECT COALESCE(SUM(quantity), 0) INTO v_stock_quantity FROM warehouse_stock WHERE product_id = v_product_id AND store_id = p_store_id;
        IF v_stock_quantity < v_quantity THEN
            RAISE EXCEPTION 'Estoque insuficiente para o produto %', v_product_id;
        END IF;

        INSERT INTO sale_items (sale_id, product_id, batch_id, unit_name, quantity, unit_price, total_price, unit_cost)
        VALUES (v_sale_id, v_product_id, v_batch_id, v_unit_name, v_quantity, v_unit_price, v_item_total, v_unit_cost);

        UPDATE warehouse_stock SET quantity = quantity - v_quantity, updated_at = NOW()
        WHERE product_id = v_product_id AND store_id = p_store_id;

        INSERT INTO stock_movements (store_id, product_id, batch_id, movement_type, quantity, unit_cost, reference_id, reference_type, created_by)
        VALUES (p_store_id, v_product_id, v_batch_id, 'sale', -v_quantity, v_unit_cost, v_sale_id, 'sale', p_cashier_id);
    END LOOP;

    INSERT INTO cash_movements (register_id, store_id, movement_type, amount, description, payment_method, reference_id, created_by)
    SELECT id, p_store_id, 'sale', v_total, 'Venda ' || v_receipt_number, p_payment_method, v_sale_id, p_cashier_id
    FROM cash_registers WHERE store_id = p_store_id AND cashier_id = p_cashier_id AND status = 'open' LIMIT 1;

    INSERT INTO financial_transactions (store_id, transaction_type, amount, description, reference_id, reference_type, created_by)
    VALUES (p_store_id, 'revenue', v_total, 'Venda ' || v_receipt_number, v_sale_id, 'sale', p_cashier_id);

    PERFORM log_audit(p_store_id, p_cashier_id, v_cashier_role, 'sale', 'sales', v_sale_id, NULL, jsonb_build_object('receipt_number', v_receipt_number, 'total', v_total, 'payment_method', p_payment_method));

    RETURN jsonb_build_object('sale_id', v_sale_id, 'receipt_number', v_receipt_number, 'total', v_total, 'change', v_change);
END;
$$ LANGUAGE plpgsql;

-- Função RPC para estornar venda
CREATE OR REPLACE FUNCTION refund_sale(
    p_sale_id UUID,
    p_user_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_sale RECORD;
    v_item RECORD;
    v_user_role TEXT;
    v_refund_id UUID;
    v_receipt_number TEXT;
BEGIN
    SELECT role INTO v_user_role FROM profiles WHERE id = p_user_id;
    IF v_user_role IS NULL THEN
        RAISE EXCEPTION 'Usuário não encontrado';
    END IF;

    SELECT * INTO v_sale FROM sales WHERE id = p_sale_id;
    IF v_sale IS NULL THEN
        RAISE EXCEPTION 'Venda não encontrada';
    END IF;
    IF v_sale.is_refunded THEN
        RAISE EXCEPTION 'Venda já estornada';
    END IF;

    v_receipt_number := generate_receipt_number(v_sale.store_id, 'EST');

    INSERT INTO sales (store_id, receipt_number, total_amount, payment_method, amount_received, change_amount, cashier_id, status, is_refunded)
    VALUES (v_sale.store_id, v_receipt_number, -v_sale.total_amount, v_sale.payment_method, 0, 0, p_user_id, 'refunded', FALSE)
    RETURNING id INTO v_refund_id;

    FOR v_item IN SELECT * FROM sale_items WHERE sale_id = p_sale_id LOOP
        UPDATE warehouse_stock SET quantity = quantity + v_item.quantity, updated_at = NOW()
        WHERE product_id = v_item.product_id AND store_id = v_sale.store_id;

        INSERT INTO stock_movements (store_id, product_id, batch_id, movement_type, quantity, unit_cost, reference_id, reference_type, created_by)
        VALUES (v_sale.store_id, v_item.product_id, v_item.batch_id, 'reversal', v_item.quantity, v_item.unit_cost, p_sale_id, 'refund', p_user_id);

        INSERT INTO sale_items (sale_id, product_id, batch_id, unit_name, quantity, unit_price, total_price, unit_cost)
        VALUES (v_refund_id, v_item.product_id, v_item.batch_id, v_item.unit_name, -v_item.quantity, v_item.unit_price, -v_item.total_price, v_item.unit_cost);
    END LOOP;

    UPDATE sales SET is_refunded = TRUE, refunded_at = NOW(), status = 'refunded' WHERE id = p_sale_id;

    INSERT INTO cash_movements (register_id, store_id, movement_type, amount, description, payment_method, reference_id, created_by)
    SELECT id, v_sale.store_id, 'refund', -v_sale.total_amount, 'Estorno ' || v_sale.receipt_number || ': ' || p_reason, v_sale.payment_method, p_sale_id, p_user_id
    FROM cash_registers WHERE store_id = v_sale.store_id AND status = 'open' LIMIT 1;

    INSERT INTO financial_transactions (store_id, transaction_type, amount, description, reference_id, reference_type, created_by)
    VALUES (v_sale.store_id, 'adjustment', -v_sale.total_amount, 'Estorno: ' || p_reason, p_sale_id, 'refund', p_user_id);

    PERFORM log_audit(v_sale.store_id, p_user_id, v_user_role, 'refund', 'sales', p_sale_id, jsonb_build_object('sale_id', p_sale_id, 'reason', p_reason), jsonb_build_object('refund_id', v_refund_id));

    RETURN jsonb_build_object('refund_id', v_refund_id, 'receipt_number', v_receipt_number, 'amount', v_sale.total_amount);
END;
$$ LANGUAGE plpgsql;

-- Função RPC para sangria
CREATE OR REPLACE FUNCTION process_withdrawal(
    p_store_id UUID,
    p_cashier_id UUID,
    p_amount NUMERIC,
    p_reason TEXT,
    p_description TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_register_id UUID;
    v_user_role TEXT;
BEGIN
    SELECT role INTO v_user_role FROM profiles WHERE id = p_cashier_id;

    SELECT id INTO v_register_id FROM cash_registers WHERE store_id = p_store_id AND cashier_id = p_cashier_id AND status = 'open' LIMIT 1;
    IF v_register_id IS NULL THEN
        RAISE EXCEPTION 'Nenhum caixa aberto encontrado';
    END IF;

    IF (SELECT COALESCE(SUM(CASE WHEN movement_type IN ('sale', 'opening', 'deposit') THEN amount ELSE -amount END), 0) FROM cash_movements WHERE register_id = v_register_id) < p_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente no caixa';
    END IF;

    INSERT INTO cash_movements (register_id, store_id, movement_type, amount, description, reference_id, created_by)
    VALUES (v_register_id, p_store_id, 'withdrawal', p_amount, p_reason || ': ' || p_description, gen_random_uuid(), p_cashier_id);

    INSERT INTO financial_transactions (store_id, transaction_type, amount, description, reference_id, reference_type, created_by)
    VALUES (p_store_id, 'expense', p_amount, 'Sangria: ' || p_reason, v_register_id, 'withdrawal', p_cashier_id);

    PERFORM log_audit(p_store_id, p_cashier_id, v_user_role, 'withdrawal', 'cash_registers', v_register_id, NULL, jsonb_build_object('amount', p_amount, 'reason', p_reason));

    RETURN jsonb_build_object('success', TRUE, 'register_id', v_register_id, 'amount', p_amount);
END;
$$ LANGUAGE plpgsql;

-- Função RPC para fechamento de caixa
CREATE OR REPLACE FUNCTION close_cash_register(
    p_register_id UUID,
    p_user_id UUID,
    p_actual_amount NUMERIC,
    p_notes TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_register RECORD;
    v_expected NUMERIC;
    v_difference NUMERIC;
    v_user_role TEXT;
BEGIN
    SELECT role INTO v_user_role FROM profiles WHERE id = p_user_id;

    SELECT * INTO v_register FROM cash_registers WHERE id = p_register_id;
    IF v_register IS NULL THEN
        RAISE EXCEPTION 'Caixa não encontrado';
    END IF;
    IF v_register.status = 'closed' THEN
        RAISE EXCEPTION 'Caixa já fechado';
    END IF;

    SELECT COALESCE(SUM(CASE WHEN movement_type IN ('sale', 'opening', 'deposit') THEN amount WHEN movement_type IN ('refund', 'withdrawal', 'expense') THEN -amount ELSE 0 END), 0) INTO v_expected FROM cash_movements WHERE register_id = p_register_id;
    v_difference := p_actual_amount - v_expected;

    UPDATE cash_registers SET closed_at = NOW(), expected_amount = v_expected, actual_amount = p_actual_amount, difference_amount = v_difference, status = 'closed', notes = p_notes WHERE id = p_register_id;

    INSERT INTO cash_movements (register_id, store_id, movement_type, amount, description, created_by)
    VALUES (p_register_id, v_register.store_id, 'closing', 0, 'Fechamento de caixa. Diferença: ' || v_difference || ' MT', p_user_id);

    INSERT INTO daily_closings (store_id, register_id, closing_date, total_sales, total_refunds, total_withdrawals, expected_amount, actual_amount, difference_amount, closed_by)
    SELECT v_register.store_id, p_register_id, CURRENT_DATE, COALESCE(SUM(CASE WHEN movement_type = 'sale' THEN amount ELSE 0 END), 0), COALESCE(SUM(CASE WHEN movement_type = 'refund' THEN amount ELSE 0 END), 0), COALESCE(SUM(CASE WHEN movement_type = 'withdrawal' THEN amount ELSE 0 END), 0), v_expected, p_actual_amount, v_difference, p_user_id FROM cash_movements WHERE register_id = p_register_id;

    PERFORM log_audit(v_register.store_id, p_user_id, v_user_role, 'close_register', 'cash_registers', p_register_id, jsonb_build_object('expected', v_expected, 'actual', p_actual_amount), jsonb_build_object('difference', v_difference));

    RETURN jsonb_build_object('register_id', p_register_id, 'expected', v_expected, 'actual', p_actual_amount, 'difference', v_difference);
END;
$$ LANGUAGE plpgsql;

-- Função RPC para entrada de produto
CREATE OR REPLACE FUNCTION process_warehouse_entry(
    p_store_id UUID,
    p_user_id UUID,
    p_supplier_id UUID,
    p_invoice_number TEXT,
    p_items JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_purchase_id UUID;
    v_item JSONB;
    v_product_id UUID;
    v_batch_id UUID;
    v_quantity NUMERIC;
    v_unit_cost NUMERIC;
    v_unit_price NUMERIC;
    v_batch_number TEXT;
    v_expiry_date DATE;
    v_product_name TEXT;
    v_user_role TEXT;
BEGIN
    SELECT role INTO v_user_role FROM profiles WHERE id = p_user_id;

    INSERT INTO purchases (store_id, supplier_id, invoice_number, total_cost, created_by)
    VALUES (p_store_id, p_supplier_id, p_invoice_number, 0, p_user_id)
    RETURNING id INTO v_purchase_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_batch_number := v_item->>'batch_number';
        v_expiry_date := (v_item->>'expiry_date')::DATE;
        v_quantity := (v_item->>'quantity')::NUMERIC;
        v_unit_cost := (v_item->>'unit_cost')::NUMERIC;
        v_unit_price := (v_item->>'unit_price')::NUMERIC;
        v_product_name := v_item->>'product_name';

        SELECT id INTO v_batch_id FROM batches WHERE product_id = v_product_id AND batch_number = v_batch_number;
        IF v_batch_id IS NULL THEN
            INSERT INTO batches (product_id, store_id, batch_number, expiry_date, quantity, unit_cost, supplier_id, purchase_date)
            VALUES (v_product_id, p_store_id, v_batch_number, v_expiry_date, v_quantity, v_unit_cost, p_supplier_id, CURRENT_DATE)
            RETURNING id INTO v_batch_id;
        ELSE
            UPDATE batches SET quantity = quantity + v_quantity, expiry_date = v_expiry_date WHERE id = v_batch_id;
        END IF;

        INSERT INTO purchase_items (purchase_id, product_id, batch_id, quantity, unit_cost, total_cost, expiry_date)
        VALUES (v_purchase_id, v_product_id, v_batch_id, v_quantity, v_unit_cost, v_quantity * v_unit_cost, v_expiry_date);

        INSERT INTO warehouse_stock (product_id, store_id, batch_id, quantity, unit_cost)
        VALUES (v_product_id, p_store_id, v_batch_id, v_quantity, v_unit_cost)
        ON CONFLICT (product_id, batch_id) DO UPDATE SET quantity = warehouse_stock.quantity + v_quantity, unit_cost = v_unit_cost, updated_at = NOW();

        INSERT INTO stock_movements (store_id, product_id, batch_id, movement_type, quantity, unit_cost, reference_id, reference_type, created_by)
        VALUES (p_store_id, v_product_id, v_batch_id, 'entry', v_quantity, v_unit_cost, v_purchase_id, 'purchase', p_user_id);
    END LOOP;

    UPDATE purchases SET total_cost = (SELECT COALESCE(SUM(total_cost), 0) FROM purchase_items WHERE purchase_id = v_purchase_id) WHERE id = v_purchase_id;

    INSERT INTO financial_transactions (store_id, transaction_type, amount, description, reference_id, reference_type, created_by)
    SELECT p_store_id, 'cost', total_cost, 'Compra ' || invoice_number, v_purchase_id, 'purchase', p_user_id FROM purchases WHERE id = v_purchase_id;

    PERFORM log_audit(p_store_id, p_user_id, v_user_role, 'purchase', 'purchases', v_purchase_id, NULL, jsonb_build_object('supplier_id', p_supplier_id, 'items_count', jsonb_array_length(p_items)));

    RETURN jsonb_build_object('purchase_id', v_purchase_id, 'total_cost', (SELECT total_cost FROM purchases WHERE id = v_purchase_id));
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_registers ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE losses ENABLE ROW LEVEL SECURITY;
ALTER TABLE capital_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_closings ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Políticas para stores
CREATE POLICY stores_admin_all ON stores FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY stores_member_select ON stores FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM store_users WHERE store_id = stores.id AND user_id = auth.uid()));

-- Políticas para profiles
CREATE POLICY profiles_self ON profiles FOR ALL TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY profiles_admin_all ON profiles FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Políticas para store_users
CREATE POLICY store_users_admin ON store_users FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Políticas para suppliers
CREATE POLICY suppliers_admin ON suppliers FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = suppliers.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = suppliers.store_id));

-- Políticas para products
CREATE POLICY products_admin ON products FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = products.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = products.store_id));
CREATE POLICY products_cashier_select ON products FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'cashier' AND su.store_id = products.store_id));

-- Políticas para product_units
CREATE POLICY product_units_admin ON product_units FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN products pr ON pr.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND pr.id = product_units.product_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN products pr ON pr.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND pr.id = product_units.product_id));
CREATE POLICY product_units_cashier_select ON product_units FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN products pr ON pr.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'cashier' AND pr.id = product_units.product_id));

-- Políticas para product_packages
CREATE POLICY product_packages_admin ON product_packages FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN products pr ON pr.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND pr.id = product_packages.product_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN products pr ON pr.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND pr.id = product_packages.product_id));

-- Políticas para batches
CREATE POLICY batches_admin ON batches FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = batches.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = batches.store_id));
CREATE POLICY batches_cashier_select ON batches FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'cashier' AND su.store_id = batches.store_id));

-- Políticas para warehouse_stock
CREATE POLICY warehouse_stock_admin ON warehouse_stock FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = warehouse_stock.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = warehouse_stock.store_id));
CREATE POLICY warehouse_stock_cashier_select ON warehouse_stock FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'cashier' AND su.store_id = warehouse_stock.store_id));

-- Políticas para stock_movements
CREATE POLICY stock_movements_admin ON stock_movements FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = stock_movements.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = stock_movements.store_id));
CREATE POLICY stock_movements_cashier ON stock_movements FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND su.store_id = stock_movements.store_id));

-- Políticas para purchases
CREATE POLICY purchases_admin ON purchases FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = purchases.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = purchases.store_id));

-- Políticas para purchase_items
CREATE POLICY purchase_items_admin ON purchase_items FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN purchases pu ON pu.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND pu.id = purchase_items.purchase_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN purchases pu ON pu.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND pu.id = purchase_items.purchase_id));

-- Políticas para transfers
CREATE POLICY transfers_admin ON transfers FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = transfers.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = transfers.store_id));

-- Políticas para transfer_items
CREATE POLICY transfer_items_admin ON transfer_items FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN transfers t ON t.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND t.id = transfer_items.transfer_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN transfers t ON t.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND t.id = transfer_items.transfer_id));

-- Políticas para sales
CREATE POLICY sales_admin ON sales FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = sales.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = sales.store_id));
CREATE POLICY sales_cashier ON sales FOR ALL TO authenticated USING (cashier_id = auth.uid() OR EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = sales.store_id)) WITH CHECK (cashier_id = auth.uid() OR EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = sales.store_id));

-- Políticas para sale_items
CREATE POLICY sale_items_admin ON sale_items FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN sales s ON s.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND s.id = sale_items.sale_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN sales s ON s.store_id = su.store_id WHERE p.id = auth.uid() AND p.role = 'admin' AND s.id = sale_items.sale_id));
CREATE POLICY sale_items_cashier ON sale_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id JOIN sales s ON s.store_id = su.store_id WHERE p.id = auth.uid() AND su.store_id = s.store_id AND s.id = sale_items.sale_id));

-- Políticas para cash_registers
CREATE POLICY cash_registers_admin ON cash_registers FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = cash_registers.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = cash_registers.store_id));
CREATE POLICY cash_registers_cashier ON cash_registers FOR ALL TO authenticated USING (cashier_id = auth.uid()) WITH CHECK (cashier_id = auth.uid());

-- Políticas para cash_movements
CREATE POLICY cash_movements_admin ON cash_movements FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = cash_movements.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = cash_movements.store_id));
CREATE POLICY cash_movements_cashier ON cash_movements FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM cash_registers cr WHERE cr.id = cash_movements.register_id AND cr.cashier_id = auth.uid()));

-- Políticas para receipts
CREATE POLICY receipts_admin ON receipts FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = receipts.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = receipts.store_id));
CREATE POLICY receipts_cashier ON receipts FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND su.store_id = receipts.store_id));

-- Políticas para losses
CREATE POLICY losses_admin ON losses FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = losses.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = losses.store_id));

-- Políticas para capital_transactions
CREATE POLICY capital_admin ON capital_transactions FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = capital_transactions.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = capital_transactions.store_id));

-- Políticas para financial_transactions
CREATE POLICY financial_admin ON financial_transactions FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = financial_transactions.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = financial_transactions.store_id));

-- Políticas para daily_closings
CREATE POLICY daily_closings_admin ON daily_closings FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = daily_closings.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = daily_closings.store_id));

-- Políticas para audit_logs
CREATE POLICY audit_admin ON audit_logs FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = audit_logs.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = audit_logs.store_id));
CREATE POLICY audit_cashier ON audit_logs FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Políticas para settings
CREATE POLICY settings_admin ON settings FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = settings.store_id)) WITH CHECK (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND p.role = 'admin' AND su.store_id = settings.store_id));
CREATE POLICY settings_cashier ON settings FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM profiles p JOIN store_users su ON p.id = su.user_id WHERE p.id = auth.uid() AND su.store_id = settings.store_id));

-- ============================================
-- VIEWS
-- ============================================

CREATE OR REPLACE VIEW stock_summary AS
SELECT
    p.id AS product_id,
    p.store_id,
    p.name AS product_name,
    p.code,
    p.barcode,
    p.base_unit,
    COALESCE(SUM(ws.quantity), 0) AS total_quantity,
    COALESCE(SUM(ws.quantity * ws.unit_cost), 0) AS total_cost,
    COALESCE((SELECT pu.conversion_to_base FROM product_units pu WHERE pu.product_id = p.id AND pu.is_base = TRUE LIMIT 1), 1) AS base_conversion
FROM products p
LEFT JOIN warehouse_stock ws ON ws.product_id = p.id
GROUP BY p.id, p.store_id, p.name, p.code, p.barcode, p.base_unit;

CREATE OR REPLACE VIEW expiring_products AS
SELECT
    b.id AS batch_id,
    b.product_id,
    b.store_id,
    b.batch_number,
    b.expiry_date,
    b.quantity,
    p.name AS product_name,
    (b.expiry_date - CURRENT_DATE) AS days_until_expiry,
    CASE
        WHEN b.expiry_date < CURRENT_DATE THEN 'expired'
        WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring_30'
        WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '60 days' THEN 'expiring_60'
        WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '90 days' THEN 'expiring_90'
        ELSE 'ok'
    END AS expiry_status
FROM batches b
JOIN products p ON p.id = b.product_id
WHERE b.expiry_date <= CURRENT_DATE + INTERVAL '90 days' AND b.quantity > 0;

CREATE OR REPLACE VIEW financial_summary AS
SELECT
    store_id,
    COALESCE(SUM(CASE WHEN transaction_type = 'revenue' THEN amount ELSE 0 END), 0) AS total_revenue,
    COALESCE(SUM(CASE WHEN transaction_type = 'cost' THEN amount ELSE 0 END), 0) AS total_cost,
    COALESCE(SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END), 0) AS total_expenses,
    COALESCE(SUM(CASE WHEN transaction_type = 'revenue' THEN amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN transaction_type = 'cost' THEN amount ELSE 0 END), 0) AS gross_profit
FROM financial_transactions
GROUP BY store_id;

CREATE OR REPLACE VIEW patrimony_view AS
SELECT
    s.id AS store_id,
    s.name AS store_name,
    COALESCE((SELECT SUM(amount) FROM capital_transactions WHERE store_id = s.id), 0) AS total_capital,
    COALESCE((SELECT SUM(amount) FROM financial_transactions WHERE store_id = s.id AND transaction_type = 'revenue'), 0) AS total_revenue,
    COALESCE((SELECT SUM(amount) FROM financial_transactions WHERE store_id = s.id AND transaction_type = 'cost'), 0) AS total_cost,
    COALESCE((SELECT SUM(amount) FROM financial_transactions WHERE store_id = s.id AND transaction_type = 'expense'), 0) AS total_expenses,
    COALESCE((SELECT SUM(quantity * unit_cost) FROM warehouse_stock WHERE store_id = s.id), 0) AS stock_value_cost
FROM stores s;

-- ============================================
-- DADOS INICIAIS
-- ============================================

INSERT INTO stores (name, address, phone, currency)
VALUES ('Farmakeia - Farmácia Principal', 'Maputo, Moçambique', '+258 84 000 0000', 'MZN')
ON CONFLICT DO NOTHING;

INSERT INTO settings (store_id, setting_key, setting_value)
SELECT id, 'payment_methods', '{"cash":"Dinheiro","mpesa":"M-Pesa","card":"Cartão/POS","transfer":"Transferência","other":"Outro"}'::jsonb
FROM stores WHERE name = 'Farmakeia - Farmácia Principal'
ON CONFLICT DO NOTHING;

INSERT INTO settings (store_id, setting_key, setting_value)
SELECT id, 'units', '["comprimido","cápsula","carteira","blister","caixa","frasco","ampola","tubo","sachê","pacote","unidade"]'::jsonb
FROM stores WHERE name = 'Farmakeia - Farmácia Principal'
ON CONFLICT DO NOTHING;

INSERT INTO settings (store_id, setting_key, setting_value)
SELECT id, 'receipt_footer', '"Obrigado pela preferência! Farmakeia - Sua saúde em primeiro lugar."'::jsonb
FROM stores WHERE name = 'Farmakeia - Farmácia Principal'
ON CONFLICT DO NOTHING;
