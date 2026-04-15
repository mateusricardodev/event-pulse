-- ============================================================================
-- SAAS DE INSCRIÇÕES - SCRIPT INICIAL DE BANCO DE DADOS
-- PostgreSQL 12+
-- ============================================================================
-- Executar como superuser ou com privilégios adequados
-- ============================================================================

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. TABELA: ORGANIZATIONS (Organizadores/Tenants)
-- ============================================================================

DROP TABLE IF EXISTS organizations CASCADE;

CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20),
  
  -- Branding
  logo_url TEXT,
  primary_color VARCHAR(7) DEFAULT '#8000FF',
  secondary_color VARCHAR(7) DEFAULT '#00C9A7',
  
  -- Configurações
  country_code VARCHAR(2) DEFAULT 'BR',
  timezone VARCHAR(50) DEFAULT 'America/Sao_Paulo',
  payment_gateway VARCHAR(50), -- 'stripe' | 'mercado_pago' | 'pagar_me'
  
  -- Segurança
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_email ON organizations(email);
CREATE INDEX idx_organizations_active ON organizations(is_active);

-- ============================================================================
-- 2. TABELA: EVENTS (Eventos)
-- ============================================================================

DROP TABLE IF EXISTS events CASCADE;

CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  title VARCHAR(255) NOT NULL,
  description TEXT,
  image_url TEXT,
  location VARCHAR(500),
  
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP,
  registration_deadline TIMESTAMP,
  
  status VARCHAR(50) DEFAULT 'draft',
  
  max_registrations INT,
  current_registrations INT DEFAULT 0,
  require_approval BOOLEAN DEFAULT FALSE,
  allow_duplicate_email BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_dates CHECK (start_date < COALESCE(end_date, start_date + INTERVAL '1 day')),
  CONSTRAINT valid_status CHECK (status IN ('draft', 'published', 'closed', 'completed'))
);

CREATE INDEX idx_events_organization ON events(organization_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_date ON events(start_date);

-- ============================================================================
-- 3. TABELA: CUSTOM_FIELDS (Campos Personalizados)
-- ============================================================================

DROP TABLE IF EXISTS custom_fields CASCADE;

CREATE TABLE custom_fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  field_name VARCHAR(255) NOT NULL,
  field_type VARCHAR(50) NOT NULL,
  placeholder VARCHAR(255),
  help_text TEXT,
  
  is_required BOOLEAN DEFAULT FALSE,
  validation_pattern VARCHAR(500),
  
  options JSONB,
  input_mask VARCHAR(50),
  
  display_order INT DEFAULT 0,
  is_pii BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_field_type CHECK (field_type IN ('text', 'email', 'phone', 'select', 'checkbox', 'date', 'number', 'textarea'))
);

CREATE INDEX idx_custom_fields_event ON custom_fields(event_id);

-- ============================================================================
-- 4. TABELA: TICKET_BATCHES (Lotes de Ingressos)
-- ============================================================================

DROP TABLE IF EXISTS ticket_batches CASCADE;

CREATE TABLE ticket_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  name VARCHAR(255) NOT NULL,
  description TEXT,
  
  price DECIMAL(10, 2) NOT NULL DEFAULT 0,
  service_fee DECIMAL(10, 2) DEFAULT 0,
  currency VARCHAR(3) DEFAULT 'BRL',
  
  total_tickets INT NOT NULL,
  available_tickets INT NOT NULL,
  sold_tickets INT DEFAULT 0,
  
  sale_start_date TIMESTAMP NOT NULL,
  sale_end_date TIMESTAMP NOT NULL,
  
  is_active BOOLEAN DEFAULT TRUE,
  is_early_bird BOOLEAN DEFAULT FALSE,
  
  display_order INT DEFAULT 0,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_tickets CHECK (total_tickets > 0),
  CONSTRAINT valid_available CHECK (available_tickets >= 0 AND available_tickets <= total_tickets),
  CONSTRAINT valid_sold CHECK (sold_tickets >= 0 AND sold_tickets <= total_tickets),
  CONSTRAINT valid_inventory CHECK (available_tickets + sold_tickets = total_tickets),
  CONSTRAINT valid_dates CHECK (sale_start_date <= sale_end_date),
  CONSTRAINT valid_price CHECK (price >= 0 AND service_fee >= 0)
);

CREATE INDEX idx_ticket_batches_event ON ticket_batches(event_id);
CREATE INDEX idx_ticket_batches_active ON ticket_batches(event_id, is_active);
CREATE INDEX idx_ticket_batches_sale_dates ON ticket_batches(sale_start_date, sale_end_date);

-- ============================================================================
-- 5. TABELA: REGISTRATIONS (Inscrições) - CORE DO SISTEMA
-- ============================================================================

DROP TABLE IF EXISTS registrations CASCADE;

CREATE TABLE registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  ticket_batch_id UUID NOT NULL REFERENCES ticket_batches(id) ON DELETE RESTRICT,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  email VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  full_name VARCHAR(255),
  
  cpf_encrypted VARCHAR(255),
  cpf_hash VARCHAR(255) UNIQUE,
  
  custom_fields_data JSONB,
  
  status VARCHAR(50) DEFAULT 'pending',
  payment_status VARCHAR(50) DEFAULT 'unpaid',
  
  payment_method VARCHAR(50),
  payment_id VARCHAR(255),
  amount_paid DECIMAL(10, 2),
  
  ticket_quantity INT DEFAULT 1,
  confirmation_token VARCHAR(255) UNIQUE,
  confirmed_at TIMESTAMP,
  
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'confirmed', 'cancelled', 'refunded')),
  CONSTRAINT valid_payment_status CHECK (payment_status IN ('unpaid', 'paid', 'failed')),
  CONSTRAINT valid_quantity CHECK (ticket_quantity > 0)
);

-- ÍNDICES CRÍTICOS
CREATE INDEX idx_registrations_event ON registrations(event_id);
CREATE INDEX idx_registrations_organization ON registrations(organization_id);
CREATE INDEX idx_registrations_ticket_batch ON registrations(ticket_batch_id);
CREATE INDEX idx_registrations_email ON registrations(email);
CREATE INDEX idx_registrations_cpf_hash ON registrations(cpf_hash);
CREATE INDEX idx_registrations_payment_id ON registrations(payment_id);
CREATE INDEX idx_registrations_status ON registrations(event_id, status);
CREATE INDEX idx_registrations_payment_status ON registrations(event_id, payment_status);
CREATE INDEX idx_registrations_created ON registrations(created_at DESC);
CREATE INDEX idx_registrations_org_event ON registrations(organization_id, event_id);

-- ============================================================================
-- 6. TABELA: REGISTRATION_ANSWERS (Respostas de Campos Personalizados)
-- ============================================================================

DROP TABLE IF EXISTS registration_answers CASCADE;

CREATE TABLE registration_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  custom_field_id UUID NOT NULL REFERENCES custom_fields(id) ON DELETE CASCADE,
  
  answer_value TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(registration_id, custom_field_id)
);

CREATE INDEX idx_registration_answers_registration ON registration_answers(registration_id);
CREATE INDEX idx_registration_answers_field ON registration_answers(custom_field_id);

-- ============================================================================
-- 7. TABELA: COUPONS (Cupons de Desconto)
-- ============================================================================

DROP TABLE IF EXISTS coupons CASCADE;

CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  code VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  
  discount_type VARCHAR(20),
  discount_value DECIMAL(10, 2) NOT NULL,
  max_uses INT,
  current_uses INT DEFAULT 0,
  
  valid_from TIMESTAMP,
  valid_until TIMESTAMP,
  
  applicable_batches JSONB,
  
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_discount_type CHECK (discount_type IN ('fixed', 'percentage')),
  CONSTRAINT valid_discount CHECK (discount_value > 0),
  CONSTRAINT valid_uses CHECK (max_uses IS NULL OR max_uses > 0)
);

CREATE INDEX idx_coupons_event ON coupons(event_id);
CREATE INDEX idx_coupons_code ON coupons(code);

-- ============================================================================
-- 8. TABELA: AUDIT_LOGS (Auditoria de Segurança)
-- ============================================================================

DROP TABLE IF EXISTS audit_logs CASCADE;

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id UUID,
  
  user_id UUID,
  ip_address INET,
  user_agent TEXT,
  
  old_values JSONB,
  new_values JSONB,
  
  status VARCHAR(50),
  error_message TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_action CHECK (action ~ '^[a-z_]+$')
);

CREATE INDEX idx_audit_logs_organization ON audit_logs(organization_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- ============================================================================
-- TRIGGERS E FUNÇÕES
-- ============================================================================

-- Atualizar campo updated_at automaticamente
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a todas as tabelas que têm updated_at
CREATE TRIGGER update_organizations_timestamp
BEFORE UPDATE ON organizations
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_events_timestamp
BEFORE UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_ticket_batches_timestamp
BEFORE UPDATE ON ticket_batches
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_registrations_timestamp
BEFORE UPDATE ON registrations
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_registration_answers_timestamp
BEFORE UPDATE ON registration_answers
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- FUNÇÃO: VALIDAR DISPONIBILIDADE DE TICKETS
-- ============================================================================

CREATE OR REPLACE FUNCTION check_ticket_availability()
RETURNS TRIGGER AS $$
DECLARE
  available_count INT;
BEGIN
  -- Buscar quantidade disponível com lock para evitar race conditions
  SELECT available_tickets INTO available_count
  FROM ticket_batches
  WHERE id = NEW.ticket_batch_id
  FOR UPDATE;

  -- Verificar se há tickets suficientes
  IF available_count < NEW.ticket_quantity THEN
    RAISE EXCEPTION 'Insufficient tickets available. Available: %, Requested: %', available_count, NEW.ticket_quantity;
  END IF;

  -- Decrementar estoque apenas se for inscrição confirmada
  IF NEW.status = 'confirmed' THEN
    UPDATE ticket_batches
    SET available_tickets = available_tickets - NEW.ticket_quantity,
        sold_tickets = sold_tickets + NEW.ticket_quantity,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.ticket_batch_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_ticket_availability
BEFORE INSERT ON registrations
FOR EACH ROW
EXECUTE FUNCTION check_ticket_availability();

-- ============================================================================
-- FUNÇÃO: INCREMENTAR CURRENT_REGISTRATIONS NO EVENT
-- ============================================================================

CREATE OR REPLACE FUNCTION increment_event_registrations()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
    UPDATE events
    SET current_registrations = current_registrations + 1
    WHERE id = NEW.event_id;
  ELSIF NEW.status != 'confirmed' AND OLD.status = 'confirmed' THEN
    UPDATE events
    SET current_registrations = GREATEST(current_registrations - 1, 0)
    WHERE id = NEW.event_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_increment_event_registrations
AFTER INSERT OR UPDATE ON registrations
FOR EACH ROW
EXECUTE FUNCTION increment_event_registrations();

-- ============================================================================
-- VIEWS ÚTEIS
-- ============================================================================

-- View: Resumo de Eventos (para dashboard)
CREATE OR REPLACE VIEW event_summary AS
SELECT
  e.id,
  e.organization_id,
  e.title,
  e.start_date,
  e.status,
  COUNT(DISTINCT r.id) as total_registrations,
  SUM(CASE WHEN r.payment_status = 'paid' THEN r.amount_paid ELSE 0 END) as total_revenue,
  COUNT(DISTINCT CASE WHEN r.status = 'confirmed' THEN r.id END) as confirmed_registrations,
  SUM(tb.total_tickets) as total_available_tickets,
  SUM(tb.sold_tickets) as tickets_sold
FROM events e
LEFT JOIN ticket_batches tb ON e.id = tb.event_id
LEFT JOIN registrations r ON e.id = r.event_id
GROUP BY e.id, e.organization_id, e.title, e.start_date, e.status;

-- View: Status de Vendas por Lote
CREATE OR REPLACE VIEW ticket_batch_sales AS
SELECT
  tb.id,
  tb.event_id,
  tb.name,
  tb.total_tickets,
  tb.available_tickets,
  tb.sold_tickets,
  (tb.sold_tickets::FLOAT / tb.total_tickets * 100)::DECIMAL(5, 2) as sold_percentage,
  tb.price,
  tb.service_fee,
  SUM(r.amount_paid) as total_revenue,
  COUNT(DISTINCT r.id) as total_orders
FROM ticket_batches tb
LEFT JOIN registrations r ON tb.id = r.ticket_batch_id AND r.payment_status = 'paid'
GROUP BY tb.id, tb.event_id, tb.name, tb.total_tickets, tb.available_tickets, tb.sold_tickets, tb.price, tb.service_fee;

-- View: Registrations com informações do evento e lote
CREATE OR REPLACE VIEW registration_details AS
SELECT
  r.id as registration_id,
  r.organization_id,
  r.event_id,
  e.title as event_title,
  r.full_name,
  r.email,
  r.phone,
  tb.name as ticket_batch_name,
  tb.price,
  tb.service_fee,
  r.amount_paid,
  r.status,
  r.payment_status,
  r.confirmed_at,
  r.created_at,
  r.custom_fields_data
FROM registrations r
JOIN events e ON r.event_id = e.id
JOIN ticket_batches tb ON r.ticket_batch_id = tb.id;

-- ============================================================================
-- GRANTS (Configurar permissões de usuários - OPCIONAL)
-- ============================================================================

-- Criar role para aplicação (substitua 'saas_app' por seu usuário)
-- DO NOT EXECUTE EM PRODUÇÃO SEM AJUSTAR:
-- CREATE ROLE saas_app WITH LOGIN PASSWORD 'secure_password_here';
-- GRANT CONNECT ON DATABASE saas_db TO saas_app;
-- GRANT USAGE ON SCHEMA public TO saas_app;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO saas_app;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO saas_app;

-- ============================================================================
-- DADOS INICIAIS (PARA TESTES)
-- ============================================================================

-- Descomente para adicionar organização de teste
/*
INSERT INTO organizations (name, slug, email, primary_color, secondary_color, country_code, timezone, payment_gateway)
VALUES (
  'TechConf Brasil 2025',
  'techconf-brasil-2025',
  'admin@techconf.com.br',
  '#8000FF',
  '#00C9A7',
  'BR',
  'America/Sao_Paulo',
  'mercado_pago'
);

INSERT INTO events (
  organization_id,
  title,
  description,
  location,
  start_date,
  end_date,
  registration_deadline,
  status,
  max_registrations
)
SELECT
  id,
  'TechConf Brasil 2025',
  'A maior conferência de tecnologia do Brasil',
  'São Paulo - SP',
  '2025-06-15 09:00:00',
  '2025-06-17 18:00:00',
  '2025-06-14 23:59:59',
  'published',
  500
FROM organizations
WHERE slug = 'techconf-brasil-2025';

INSERT INTO ticket_batches (
  event_id,
  name,
  description,
  price,
  service_fee,
  total_tickets,
  available_tickets,
  sale_start_date,
  sale_end_date,
  is_active,
  is_early_bird,
  display_order
)
SELECT
  id,
  'Ingresso Gratuito',
  'Acesso básico ao evento',
  0,
  0,
  50,
  50,
  '2025-05-01 00:00:00',
  '2025-06-15 23:59:59',
  TRUE,
  FALSE,
  1
FROM events
WHERE title = 'TechConf Brasil 2025';

INSERT INTO ticket_batches (
  event_id,
  name,
  description,
  price,
  service_fee,
  total_tickets,
  available_tickets,
  sale_start_date,
  sale_end_date,
  is_active,
  is_early_bird,
  display_order
)
SELECT
  id,
  'Ingresso Normal',
  'Acesso completo ao evento',
  79.90,
  5.00,
  200,
  200,
  '2025-05-01 00:00:00',
  '2025-06-15 23:59:59',
  TRUE,
  FALSE,
  2
FROM events
WHERE title = 'TechConf Brasil 2025';

INSERT INTO custom_fields (
  event_id,
  field_name,
  field_type,
  placeholder,
  is_required,
  display_order,
  is_pii
)
SELECT
  id,
  'CPF',
  'text',
  '000.000.000-00',
  TRUE,
  1,
  TRUE
FROM events
WHERE title = 'TechConf Brasil 2025';

INSERT INTO custom_fields (
  event_id,
  field_name,
  field_type,
  placeholder,
  help_text,
  is_required,
  display_order,
  is_pii
)
SELECT
  id,
  'Tamanho de Camiseta',
  'select',
  'Selecione seu tamanho',
  'Enviaremos uma camiseta do evento',
  TRUE,
  2,
  FALSE
FROM events
WHERE title = 'TechConf Brasil 2025';

UPDATE custom_fields
SET options = '["P", "M", "G", "GG"]'::jsonb
WHERE field_name = 'Tamanho de Camiseta';
*/

-- ============================================================================
-- FIM DO SCRIPT
-- ============================================================================

COMMIT;

-- Verificação: Listar todas as tabelas criadas
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
