# 📊 Fase 1: Arquitetura de Banco de Dados PostgreSQL
## SaaS de Gestão de Eventos e Inscrições

---

## 1️⃣ Visão Geral da Arquitetura

Este banco de dados foi projetado para:
- **Multi-tenancy seguro**: Isolamento completo entre organizadores
- **Flexibilidade de campos**: Cada evento pode solicitar dados diferentes
- **Performance em alta concorrência**: Ingressos que esgotam em segundos
- **Conformidade com LGPD**: Criptografia de dados sensíveis
- **Auditoria**: Rastreamento de todas as transações

---

## 2️⃣ Estrutura de Tabelas

### **2.1 Tabela: `organizations` (Organizadores/Tenants)**

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,  -- ex: "meu-evento-2025"
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20),
  
  -- Branding
  logo_url TEXT,
  primary_color VARCHAR(7) DEFAULT '#8000FF',  -- roxo vibrante
  secondary_color VARCHAR(7) DEFAULT '#00C9A7', -- verde água
  
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
```

---

### **2.2 Tabela: `events` (Eventos)**

```sql
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Informações básicas
  title VARCHAR(255) NOT NULL,
  description TEXT,
  image_url TEXT,
  location VARCHAR(500),
  
  -- Data e hora
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP,
  registration_deadline TIMESTAMP,
  
  -- Status do evento
  status VARCHAR(50) DEFAULT 'draft', -- 'draft' | 'published' | 'closed' | 'completed'
  
  -- Configurações de inscrição
  max_registrations INT,
  current_registrations INT DEFAULT 0,
  require_approval BOOLEAN DEFAULT FALSE,
  allow_duplicate_email BOOLEAN DEFAULT FALSE,
  
  -- Auditoria
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_dates CHECK (start_date < COALESCE(end_date, start_date + INTERVAL '1 day')),
  CONSTRAINT valid_status CHECK (status IN ('draft', 'published', 'closed', 'completed'))
);

CREATE INDEX idx_events_organization ON events(organization_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_date ON events(start_date);
```

---

### **2.3 Tabela: `ticket_batches` (Lotes de Ingressos)**

```sql
CREATE TABLE ticket_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  -- Identificação
  name VARCHAR(255) NOT NULL, -- ex: "Ingresso Gratuito", "Normal com taxa"
  description TEXT,
  
  -- Preço e taxas
  price DECIMAL(10, 2) NOT NULL DEFAULT 0, -- Preço do ingresso
  service_fee DECIMAL(10, 2) DEFAULT 0,    -- Taxa de serviço
  currency VARCHAR(3) DEFAULT 'BRL',
  
  -- Controle de estoque
  total_tickets INT NOT NULL,
  available_tickets INT NOT NULL, -- total_tickets - sold_tickets
  sold_tickets INT DEFAULT 0,
  
  -- Datas
  sale_start_date TIMESTAMP NOT NULL,
  sale_end_date TIMESTAMP NOT NULL,
  
  -- Configurações
  is_active BOOLEAN DEFAULT TRUE,
  is_early_bird BOOLEAN DEFAULT FALSE,
  
  -- Ordenação
  display_order INT DEFAULT 0,
  
  -- Auditoria
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
```

---

### **2.4 Tabela: `custom_fields` (Campos Personalizados)**

```sql
CREATE TABLE custom_fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  -- Definição do campo
  field_name VARCHAR(255) NOT NULL, -- ex: "CPF", "Tamanho de Camiseta"
  field_type VARCHAR(50) NOT NULL,  -- 'text' | 'email' | 'phone' | 'select' | 'checkbox' | 'date'
  placeholder VARCHAR(255),
  help_text TEXT,
  
  -- Validação
  is_required BOOLEAN DEFAULT FALSE,
  validation_pattern VARCHAR(500), -- regex para validações customizadas
  
  -- Opções (para select/radio)
  options JSONB, -- ex: ["P", "M", "G", "GG"]
  
  -- Formato
  input_mask VARCHAR(50), -- ex: "(00) 00000-0000" para telefone
  
  -- Ordenação
  display_order INT DEFAULT 0,
  
  -- Metadados
  is_pii BOOLEAN DEFAULT FALSE, -- "Personally Identifiable Information" - dados sensíveis
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_field_type CHECK (field_type IN ('text', 'email', 'phone', 'select', 'checkbox', 'date', 'number', 'textarea'))
);

CREATE INDEX idx_custom_fields_event ON custom_fields(event_id);
```

---

### **2.5 Tabela: `registrations` (Inscrições)**

Esta é a **tabela mais crítica**. Cada registro aqui é uma inscrição de um participante.

```sql
CREATE TABLE registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Referências
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  ticket_batch_id UUID NOT NULL REFERENCES ticket_batches(id) ON DELETE RESTRICT,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Dados do participante (alguns criptografados no servidor)
  email VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  full_name VARCHAR(255),
  
  -- CPF criptografado (AES-256 no servidor)
  cpf_encrypted VARCHAR(255),
  cpf_hash VARCHAR(255) UNIQUE, -- hash SHA256 para buscas sem descriptografar
  
  -- Dados dinâmicos (fields personalizados)
  custom_fields_data JSONB, -- ex: { "tamanho_camiseta": "M", "alergias": "Lactose" }
  
  -- Status de pagamento
  status VARCHAR(50) DEFAULT 'pending', -- 'pending' | 'confirmed' | 'cancelled' | 'refunded'
  payment_status VARCHAR(50) DEFAULT 'unpaid', -- 'unpaid' | 'paid' | 'failed'
  
  -- Informações de pagamento
  payment_method VARCHAR(50), -- 'pix' | 'credit_card' | 'debit_card' | 'free'
  payment_id VARCHAR(255), -- ID da transação no gateway (Stripe, Mercado Pago, etc.)
  amount_paid DECIMAL(10, 2),
  
  -- Controle
  ticket_quantity INT DEFAULT 1,
  confirmation_token VARCHAR(255) UNIQUE,
  confirmed_at TIMESTAMP,
  
  -- Auditoria
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'confirmed', 'cancelled', 'refunded')),
  CONSTRAINT valid_payment_status CHECK (payment_status IN ('unpaid', 'paid', 'failed')),
  CONSTRAINT valid_quantity CHECK (ticket_quantity > 0)
);

-- ÍNDICES CRÍTICOS PARA PERFORMANCE
CREATE INDEX idx_registrations_event ON registrations(event_id);
CREATE INDEX idx_registrations_organization ON registrations(organization_id);
CREATE INDEX idx_registrations_ticket_batch ON registrations(ticket_batch_id);
CREATE INDEX idx_registrations_email ON registrations(email);
CREATE INDEX idx_registrations_cpf_hash ON registrations(cpf_hash);
CREATE INDEX idx_registrations_payment_id ON registrations(payment_id);
CREATE INDEX idx_registrations_status ON registrations(event_id, status);
CREATE INDEX idx_registrations_payment_status ON registrations(event_id, payment_status);
CREATE INDEX idx_registrations_created ON registrations(created_at DESC);

-- Índice para isolamento de tenant (segurança)
CREATE INDEX idx_registrations_org_event ON registrations(organization_id, event_id);
```

---

### **2.6 Tabela: `registration_answers` (Respostas de Campos Personalizados)**

Alternativa mais normalizada ao JSONB (escolha arquitetural):

```sql
CREATE TABLE registration_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id UUID NOT NULL REFERENCES registrations(id) ON DELETE CASCADE,
  custom_field_id UUID NOT NULL REFERENCES custom_fields(id) ON DELETE CASCADE,
  
  -- Resposta (flexível para qualquer tipo de dado)
  answer_value TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(registration_id, custom_field_id)
);

CREATE INDEX idx_registration_answers_registration ON registration_answers(registration_id);
CREATE INDEX idx_registration_answers_field ON registration_answers(custom_field_id);
```

---

### **2.7 Tabela: `coupons` (Cupons de Desconto)**

```sql
CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  
  code VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  
  -- Tipo de desconto
  discount_type VARCHAR(20), -- 'fixed' | 'percentage'
  discount_value DECIMAL(10, 2) NOT NULL,
  max_uses INT,
  current_uses INT DEFAULT 0,
  
  -- Datas de validade
  valid_from TIMESTAMP,
  valid_until TIMESTAMP,
  
  -- Aplicável a quais lotes
  applicable_batches JSONB, -- UUIDs dos ticket_batches, ou null para todos
  
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_discount_type CHECK (discount_type IN ('fixed', 'percentage')),
  CONSTRAINT valid_discount CHECK (discount_value > 0),
  CONSTRAINT valid_uses CHECK (max_uses IS NULL OR max_uses > 0)
);

CREATE INDEX idx_coupons_event ON coupons(event_id);
CREATE INDEX idx_coupons_code ON coupons(code);
```

---

### **2.8 Tabela: `audit_logs` (Auditoria de Segurança)**

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  
  action VARCHAR(100) NOT NULL, -- 'registration_created', 'payment_confirmed', 'data_exported', etc.
  resource_type VARCHAR(50), -- 'event', 'registration', 'custom_field'
  resource_id UUID,
  
  -- Quem fez
  user_id UUID, -- se houver autenticação de admin
  ip_address INET,
  user_agent TEXT,
  
  -- O quê foi alterado
  old_values JSONB,
  new_values JSONB,
  
  -- Contexto
  status VARCHAR(50), -- 'success' | 'failure'
  error_message TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT valid_action CHECK (action ~ '^[a-z_]+$')
);

CREATE INDEX idx_audit_logs_organization ON audit_logs(organization_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
```

---

## 3️⃣ Fluxo de Inscrição (Visão do Banco)

### Etapa 1: Usuário seleciona ingressos
- **Leitura**: `SELECT * FROM ticket_batches WHERE event_id = ? AND is_active = TRUE`
- **Validação**: Verifica se `available_tickets > 0` e se está dentro de `sale_start_date` e `sale_end_date`

### Etapa 2: Usuário preenche dados pessoais
- **Insira em `registrations`** com status = `pending`, payment_status = `unpaid`
- **Criptografe o CPF** na aplicação (nunca envie em texto puro para o BD)

### Etapa 3: Pagamento
- **Webhook do Stripe/Mercado Pago** atualiza `registrations.payment_status = 'paid'`
- **Trigger automático**: Quando pagamento confirmado, `status = 'confirmed'` e decrementa `available_tickets`

---

## 4️⃣ Constraints e Regras de Integridade

### ✅ **Evitar Overselling (Venda de ingressos que não existem)**

```sql
-- CONSTRAINT que valida sempre que ticket_quantity é alterado
CREATE TRIGGER check_ticket_availability
BEFORE INSERT ON registrations
FOR EACH ROW
EXECUTE FUNCTION check_ticket_availability_fn();

CREATE FUNCTION check_ticket_availability_fn()
RETURNS TRIGGER AS $$
DECLARE
  available_count INT;
BEGIN
  SELECT available_tickets INTO available_count
  FROM ticket_batches
  WHERE id = NEW.ticket_batch_id
  FOR UPDATE; -- Row-level lock

  IF available_count < NEW.ticket_quantity THEN
    RAISE EXCEPTION 'Insufficient tickets available';
  END IF;

  -- Decrementa o estoque
  UPDATE ticket_batches
  SET available_tickets = available_tickets - NEW.ticket_quantity,
      sold_tickets = sold_tickets + NEW.ticket_quantity
  WHERE id = NEW.ticket_batch_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### ✅ **Isolamento de Tenant**

Qualquer query que leia registrations de um organizador **OBRIGATORIAMENTE** inclui:

```sql
-- ❌ NÃO FAÇA (vulnerável a ID enumeration)
SELECT * FROM registrations WHERE id = '123e4567...'

-- ✅ FAÇA (seguro)
SELECT * FROM registrations 
WHERE id = '123e4567...' 
  AND organization_id = current_org_id
```

---

## 5️⃣ Criptografia de Dados Sensíveis

### **No Backend (Node.js/Python)**

```typescript
// TypeScript example
import crypto from 'crypto';

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY; // 32 bytes para AES-256

function encryptCPF(cpf: string): string {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(
    'aes-256-gcm',
    Buffer.from(ENCRYPTION_KEY, 'hex'),
    iv
  );
  
  let encrypted = cipher.update(cpf, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  return iv.toString('hex') + ':' + encrypted + ':' + cipher.getAuthTag().toString('hex');
}

function decryptCPF(encrypted: string): string {
  const [iv, data, authTag] = encrypted.split(':');
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    Buffer.from(ENCRYPTION_KEY, 'hex'),
    Buffer.from(iv, 'hex')
  );
  
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));
  
  let decrypted = decipher.update(data, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

function hashCPF(cpf: string): string {
  return crypto.createHash('sha256').update(cpf).digest('hex');
}
```

### **Armazenamento no BD**
- `cpf_encrypted`: valor criptografado (AES-256)
- `cpf_hash`: hash SHA-256 do CPF (para buscas sem descriptografar)

---

## 6️⃣ Views Úteis para Relatórios

### **View: Dashboard do Organizador**

```sql
CREATE VIEW event_summary AS
SELECT
  e.id,
  e.title,
  e.start_date,
  COUNT(DISTINCT r.id) as total_registrations,
  SUM(CASE WHEN r.payment_status = 'paid' THEN r.amount_paid ELSE 0 END) as total_revenue,
  COUNT(DISTINCT CASE WHEN r.status = 'confirmed' THEN r.id END) as confirmed_registrations,
  SUM(tb.total_tickets) as total_available_tickets,
  SUM(tb.sold_tickets) as tickets_sold
FROM events e
LEFT JOIN registrations r ON e.id = r.event_id
LEFT JOIN ticket_batches tb ON e.id = tb.event_id
GROUP BY e.id, e.title, e.start_date;
```

---

## 7️⃣ Checklist de Implementação

- [ ] **Criar tabelas** em ordem: `organizations` → `events` → `custom_fields` → `ticket_batches` → `registrations` → `registration_answers`
- [ ] **Adicionar triggers** para validar estoque
- [ ] **Configurar backups** diários (PostgreSQL WAL)
- [ ] **Implementar criptografia** de CPF e dados sensíveis na aplicação
- [ ] **Criar índices** para performance
- [ ] **Testes de carga**: Simular múltiplas inscrições simultâneas
- [ ] **Audit logging**: Registrar todas as alterações sensíveis
- [ ] **Conformidade LGPD**: Direito ao esquecimento, portabilidade

---

## 8️⃣ Scripts SQL para Testes

### Criar uma organização de teste:
```sql
INSERT INTO organizations (name, slug, email)
VALUES ('TechConf 2025', 'techconf-2025', 'admin@techconf.com');
```

### Criar um evento:
```sql
INSERT INTO events (organization_id, title, start_date, status)
SELECT id, 'TechConf 2025 - Conferência de Tecnologia', 
       '2025-06-15 09:00:00', 'published'
FROM organizations WHERE slug = 'techconf-2025';
```

### Criar lotes de ingressos:
```sql
INSERT INTO ticket_batches 
(event_id, name, price, service_fee, total_tickets, available_tickets, sale_start_date, sale_end_date)
SELECT id, 'Ingresso Gratuito', 0, 0, 100, 100, '2025-05-01', '2025-06-15'
FROM events WHERE title = 'TechConf 2025 - Conferência de Tecnologia';

INSERT INTO ticket_batches 
(event_id, name, price, service_fee, total_tickets, available_tickets, sale_start_date, sale_end_date)
SELECT id, 'Ingresso Normal', 79.90, 5.00, 50, 50, '2025-05-01', '2025-06-15'
FROM events WHERE title = 'TechConf 2025 - Conferência de Tecnologia';
```

---

## 9️⃣ Considerações de Scaling

### **Problema: Tabela `registrations` cresce muito rápido**

Para um evento grande (10 mil inscrições por dia), em 1 ano teremos **3.65 milhões de registros**.

**Solução: Particionamento por Data**

```sql
-- Particionar registrations por mês
CREATE TABLE registrations_2025_01 PARTITION OF registrations
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE registrations_2025_02 PARTITION OF registrations
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
-- ... e assim por diante
```

### **Problema: Campos customizados com muitos dados**

Se o `custom_fields_data` JSONB ficar muito grande, considere:
1. **Normalizar**: Mover para tabela separada (`registration_answers`)
2. **Arquivar**: Mover inscrições antigas para tabela de histórico

---

## 🔟 Próximos Passos

✅ **Fase 1 (Banco)**: Esquema PostgreSQL completo  
⏭️ **Fase 2**: Scripts de inicialização e migrations (Alembic/TypeORM)  
⏭️ **Fase 3**: API Backend (Node.js/Python)  
⏭️ **Fase 4**: Frontend React/Next.js  
⏭️ **Fase 5**: Integração de Pagamentos  

---

**Autor**: Arquitetura SaaS de Eventos  
**Data**: 2025  
**Versão**: 1.0
