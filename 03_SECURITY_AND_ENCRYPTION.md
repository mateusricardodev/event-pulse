# 🔒 Guia de Segurança e Criptografia
## SaaS de Inscrições - Conformidade LGPD e Boas Práticas

---

## 1️⃣ Estratégia de Criptografia de Dados Sensíveis

### **1.1 Identificando Dados Sensíveis (PII - Personally Identifiable Information)**

No contexto do nosso SaaS de inscrições, dados sensíveis incluem:

| Dado | Sensibilidade | Onde Armazenar | Criptografia |
|------|---------------|-----------------|--------------|
| **CPF** | CRÍTICA | `cpf_encrypted` | AES-256 |
| **Email** | ALTA | `email` (texto) | Não (usado para login) |
| **Telefone** | ALTA | `phone` (texto) | Opcional: AES-256 |
| **Nome Completo** | MÉDIA | `full_name` (texto) | Não |
| **Dados Customizados** | VARIÁVEL | `custom_fields_data` (JSONB) | Depende do campo |

---

### **1.2 Implementação: Criptografia AES-256**

#### **Backend TypeScript (Node.js)**

```typescript
// src/utils/encryption.ts
import crypto from 'crypto';

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || '';
const ENCRYPTION_ALGORITHM = 'aes-256-gcm';

/**
 * Valida se a chave de criptografia está no formato correto
 * Deve ser 32 bytes em hexadecimal (64 caracteres)
 */
function validateEncryptionKey(): void {
  if (!ENCRYPTION_KEY || ENCRYPTION_KEY.length !== 64) {
    throw new Error(
      'ENCRYPTION_KEY deve ter exatamente 64 caracteres (32 bytes em hex)'
    );
  }
}

/**
 * Criptografa um valor usando AES-256-GCM
 * Retorna: iv:encrypted:authTag (separados por dois-pontos)
 */
export function encrypt(plaintext: string): string {
  validateEncryptionKey();

  try {
    // Gerar IV (Initialization Vector) aleatório
    const iv = crypto.randomBytes(16);

    // Criar cipher
    const cipher = crypto.createCipheriv(
      ENCRYPTION_ALGORITHM,
      Buffer.from(ENCRYPTION_KEY, 'hex'),
      iv
    );

    // Criptografar dados
    let encrypted = cipher.update(plaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');

    // Obter authentication tag (garante integridade)
    const authTag = cipher.getAuthTag();

    // Retornar no formato: iv:encrypted:authTag
    return `${iv.toString('hex')}:${encrypted}:${authTag.toString('hex')}`;
  } catch (error) {
    throw new Error(`Encryption failed: ${error.message}`);
  }
}

/**
 * Descriptografa um valor criptografado
 */
export function decrypt(encrypted: string): string {
  validateEncryptionKey();

  try {
    const [ivHex, encryptedHex, authTagHex] = encrypted.split(':');

    if (!ivHex || !encryptedHex || !authTagHex) {
      throw new Error('Invalid encrypted format');
    }

    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');

    // Criar decipher
    const decipher = crypto.createDecipheriv(
      ENCRYPTION_ALGORITHM,
      Buffer.from(ENCRYPTION_KEY, 'hex'),
      iv
    );

    decipher.setAuthTag(authTag);

    // Descriptografar
    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  } catch (error) {
    throw new Error(`Decryption failed: ${error.message}`);
  }
}

/**
 * Gera hash SHA-256 de um valor (para buscas sem descriptografar)
 * Exemplo: buscar inscrição por CPF sem ter que descriptografar tudo
 */
export function hashValue(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}
```

#### **Backend Python (FastAPI)**

```python
# app/utils/encryption.py
import os
import secrets
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives import hashes
import binascii

ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY', '')

def validate_encryption_key() -> None:
    """Valida se a chave está no formato correto"""
    if not ENCRYPTION_KEY or len(ENCRYPTION_KEY) != 64:
        raise ValueError(
            'ENCRYPTION_KEY deve ter exatamente 64 caracteres (32 bytes em hex)'
        )

def encrypt(plaintext: str) -> str:
    """Criptografa usando AES-256-GCM"""
    validate_encryption_key()
    
    try:
        key = binascii.unhexlify(ENCRYPTION_KEY)
        iv = secrets.token_bytes(16)  # IV aleatório
        
        cipher = AESGCM(key)
        ciphertext = cipher.encrypt(iv, plaintext.encode(), None)
        
        # Retornar no formato: iv:encrypted:authTag
        # (AESGCM retorna ciphertext + authTag juntos)
        return f"{binascii.hexlify(iv).decode()}:{binascii.hexlify(ciphertext).decode()}"
    except Exception as e:
        raise ValueError(f'Encryption failed: {str(e)}')

def decrypt(encrypted: str) -> str:
    """Descriptografa valor criptografado"""
    validate_encryption_key()
    
    try:
        parts = encrypted.split(':')
        if len(parts) != 2:
            raise ValueError('Invalid encrypted format')
        
        iv_hex, ciphertext_hex = parts
        key = binascii.unhexlify(ENCRYPTION_KEY)
        iv = binascii.unhexlify(iv_hex)
        ciphertext = binascii.unhexlify(ciphertext_hex)
        
        cipher = AESGCM(key)
        plaintext = cipher.decrypt(iv, ciphertext, None)
        
        return plaintext.decode()
    except Exception as e:
        raise ValueError(f'Decryption failed: {str(e)}')

def hash_value(value: str) -> str:
    """Gera hash SHA-256"""
    return hashlib.sha256(value.encode()).hexdigest()
```

---

### **1.3 Como Gerar a Chave de Criptografia**

```bash
# Gerar uma chave AES-256 aleatória (32 bytes = 64 caracteres em hex)
openssl rand -hex 32

# Saída esperada:
# 7f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f

# Adicionar ao arquivo .env
echo "ENCRYPTION_KEY=7f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f" >> .env
```

---

## 2️⃣ Fluxo Seguro de Inscrição

```
┌─────────────┐
│  Frontend   │
│  (React)    │
└──────┬──────┘
       │ Usuário preenche CPF "123.456.789-00"
       │ (não é criptografado ainda)
       │
       ├─ Valida CPF localmente (máscara/formato)
       └─> Envia para backend:
           {
             email: "user@example.com",
             phone: "(11) 98765-4321",
             cpf: "12345678900" (SEM máscara),
             customFieldsData: {...}
           }

┌──────────────────┐
│   Backend API    │
└────────┬─────────┘
         │
         ├─ Recebe dados
         │
         ├─ Valida email, phone, CPF
         │  - Regex para email
         │  - Máscara para phone
         │  - Validação de CPF (verificar dígitos)
         │
         ├─ Criptografa CPF:
         │  cpf_encrypted = encrypt("12345678900")
         │  cpf_hash = hashValue("12345678900")
         │
         ├─ Persiste no banco:
         │  INSERT INTO registrations (
         │    cpf_encrypted: "abc123def456:xyz789...",
         │    cpf_hash: "sha256hash...",
         │    email: "user@example.com",
         │    ...
         │  )
         │
         └─> Retorna apenas:
             {
               registrationId: "uuid",
               status: "pending",
               confirmationUrl: "/confirm/token123"
             }

┌──────────────────┐
│   PostgreSQL     │
│   (Banco Dados)  │
└──────────────────┘
```

---

## 3️⃣ Uso de Hash vs Criptografia

### **Por que temos duas colunas (`cpf_encrypted` e `cpf_hash`)?**

| Situação | Necessidade | Solução | Coluna |
|----------|-------------|---------|--------|
| Usuário quer recuperar "Qual era meu CPF?" | Descriptografar | Usar `cpf_encrypted` com AES-256 | `cpf_encrypted` |
| Organizar-se quer verificar duplicatas | Comparar sem descriptografar | Hash SHA-256 | `cpf_hash` |
| Auditor quer estar seguro que dados não foram vazados | Verificar integridade | Hash com salt | `cpf_hash` |

### **Exemplo: Prevenir Inscrições Duplicadas**

```typescript
// Service de Registro
async registerParticipant(data: RegisterRequest, organizationId: string) {
  // 1. Hash do CPF (sem descriptografar)
  const cpfHash = hashValue(data.cpf);

  // 2. Verificar se já existe inscrição com esse CPF no evento
  const existingRegistration = await registrationRepository.findOne({
    where: {
      event_id: data.eventId,
      cpf_hash: cpfHash,
    },
  });

  if (existingRegistration) {
    throw new ConflictException('CPF já registrado para este evento');
  }

  // 3. Criptografar CPF para armazenamento
  const cpfEncrypted = encrypt(data.cpf);

  // 4. Salvar registro
  const registration = await registrationRepository.save({
    eventId: data.eventId,
    organizationId,
    email: data.email,
    cpfEncrypted,
    cpfHash,
    status: 'pending',
    // ... outros campos
  });

  return registration;
}
```

---

## 4️⃣ Proteção Contra Vulnerabilidades Comuns

### **4.1 SQL Injection**

❌ **NUNCA FAÇA:**
```typescript
const query = `SELECT * FROM registrations WHERE email = '${email}'`;
// Entrada maliciosa: admin' --
// Query resultante: SELECT * FROM registrations WHERE email = 'admin' --'
```

✅ **FAÇA:**
```typescript
// TypeORM com parâmetros preparados
const registrations = await registrationRepository.find({
  where: { email: email }, // Automaticamente escapado
});

// Ou com Query Builder
const registrations = await registrationRepository
  .createQueryBuilder('r')
  .where('r.email = :email', { email })
  .getMany();
```

---

### **4.2 XSS (Cross-Site Scripting)**

❌ **NUNCA FAÇA:**
```typescript
// Backend retorna dados sem sanitizar
res.json({
  fullName: registration.fullName, // "<script>alert('hack')</script>"
});

// Frontend exibe direto no HTML
<div>{registration.fullName}</div> // Renderiza script!
```

✅ **FAÇA:**

**Backend:**
```typescript
import DOMPurify from 'isomorphic-dompurify';

// Sanitizar entrada
const cleanName = DOMPurify.sanitize(data.fullName);
```

**Frontend (React):**
```typescript
// React já escapa por padrão com {...}
<div>{registration.fullName}</div> // Seguro

// Se precisar renderizar HTML, use DOMPurify
import DOMPurify from 'dompurify';
<div>{DOMPurify.sanitize(htmlContent)}</div>
```

---

### **4.3 CSRF (Cross-Site Request Forgery)**

```typescript
// Middleware Express para CSRF
import csrf from 'csurf';
import cookieParser from 'cookie-parser';

app.use(cookieParser());
app.use(csrf({ cookie: true }));

// Em forms ou requests POST
app.post('/register', csrf(), (req, res) => {
  // Token validado automaticamente
  // Se falhar, retorna 403
});
```

---

### **4.4 Rate Limiting (Prevenir Brute Force)**

```typescript
// src/middleware/rateLimit.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import redis from 'redis';

const redisClient = redis.createClient();

const registerLimiter = rateLimit({
  store: new RedisStore({
    client: redisClient,
    prefix: 'rl:register:', // rate-limit:register
  }),
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 5, // 5 tentativas por IP
  message: 'Muitas inscrições do seu IP. Tente novamente em 15 minutos.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.post('/events/:eventId/register', registerLimiter, registerController);
```

---

## 5️⃣ Isolamento Multi-Tenant

### **O Problema:**

Se o Organizador A conseguir acessar dados do Organizador B, é uma falha crítica.

### **A Solução: Validação em Cada Query**

```typescript
// ❌ INSEGURO
async getRegistrations(eventId: string) {
  return await registrationRepository.find({
    where: { event_id: eventId },
  });
}

// ✅ SEGURO
async getRegistrations(eventId: string, organizationId: string) {
  // Sempre incluir validação de tenant
  return await registrationRepository.find({
    where: {
      event_id: eventId,
      organization_id: organizationId, // Filtro crítico
    },
  });
}

// AINDA MELHOR: Usar middleware automático
@UseGuards(TenantGuard) // Valida que organizationId é do usuário logado
@Get('/events/:eventId/registrations')
async getRegistrations(
  @Param('eventId') eventId: string,
  @CurrentOrganization() organizationId: string, // Injetado pelo middleware
) {
  return await this.registrationService.getRegistrations(eventId, organizationId);
}
```

---

## 6️⃣ Conformidade LGPD (Lei Geral de Proteção de Dados)

### **6.1 Direitos do Titular dos Dados**

#### **1. Direito de Acesso**
```typescript
// GET /api/registrations/:registrationId/my-data
// Usuário consegue baixar seus dados

async getMyData(registrationId: string, email: string) {
  const registration = await registrationRepository.findOne({
    where: { id: registrationId, email },
  });

  if (!registration) {
    throw new NotFoundException('Registro não encontrado');
  }

  return {
    email: registration.email,
    phone: registration.phone,
    name: registration.fullName,
    customFields: registration.customFieldsData,
    createdAt: registration.createdAt,
  };
}
```

#### **2. Direito ao Esquecimento (Exclusão)**
```typescript
// DELETE /api/registrations/:registrationId/delete-me
// Usuário pede para ser deletado

async deleteMyData(registrationId: string, email: string) {
  const registration = await registrationRepository.findOne({
    where: { id: registrationId, email },
  });

  if (!registration) {
    throw new NotFoundException();
  }

  // Não deletar imediatamente - registrar solicitação
  await dataDeleteRequestRepository.save({
    registrationId,
    requestedAt: new Date(),
    status: 'pending',
  });

  // Após 30 dias, deletar efetivamente
  // (Organizar pode contestar em casos de obrigação legal)
  
  return { message: 'Solicitação de exclusão registrada' };
}
```

#### **3. Direito à Portabilidade**
```typescript
// GET /api/registrations/:registrationId/export
// Usuário baixa seus dados em formato aberto (JSON/CSV)

async exportMyData(registrationId: string, email: string) {
  const registration = await registrationRepository.findOne({
    where: { id: registrationId, email },
  });

  const data = {
    registration: registration,
    answers: await registrationAnswerRepository.find({
      where: { registration_id: registrationId },
    }),
  };

  return data; // Cliente faz download em JSON
}
```

---

### **6.2 Política de Retenção de Dados**

```sql
-- Agendar exclusão de dados antigos (exemplo: após 2 anos)
-- Executar com cron job (ex: pg_cron)

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Agendar para rodar todo dia às 3 AM
SELECT cron.schedule('delete_old_registrations', '0 3 * * *', $$
  DELETE FROM registrations
  WHERE created_at < NOW() - INTERVAL '2 years'
  AND status NOT IN ('confirmed')
  AND payment_status = 'unpaid';
$$);
```

---

### **6.3 Consentimento e Termos**

```typescript
// Registrar que o usuário leu e concordou com termos

interface RegisterRequest {
  email: string;
  cpf: string;
  // ... outros campos
  
  // LGPD
  agreedToTerms: boolean; // "Li e concordo com..."
  agreedToPrivacyPolicy: boolean;
  allowedMarketing: boolean; // Pode receber emails?
}

// Salvando junto com registro
await registrationRepository.save({
  ...registration,
  termsAcceptedAt: new Date(),
  privacyAcceptedAt: new Date(),
  marketingAllowed: request.allowedMarketing,
});
```

---

## 7️⃣ Checklist de Implementação Segura

- [ ] **Gerar chave de criptografia AES-256** e adicionar ao `.env`
- [ ] **Implementar encrypt/decrypt** no backend (TypeScript ou Python)
- [ ] **Adicionar hash SHA-256** para buscas de CPF
- [ ] **Aplicar rate limiting** nos endpoints de registro e login
- [ ] **Configurar CORS corretamente**: apenas domínios conhecidos
- [ ] **HTTPS obrigatório** em produção (usar HSTS header)
- [ ] **Validar todas as inputs** (email, phone, CPF) com regexes
- [ ] **Sanitizar dados** com DOMPurify ou similar
- [ ] **Middleware de isolamento tenant** em todos os endpoints
- [ ] **Audit logging** para todas as operações sensíveis
- [ ] **Backups criptografados** do banco de dados
- [ ] **Política de retenção** de dados implementada
- [ ] **Consentimento LGPD** coletado antes de inscrição
- [ ] **Endpoint de export de dados** para usuários
- [ ] **Endpoint de deletion request** (direito ao esquecimento)
- [ ] **Testes de segurança**: OWASP Top 10

---

## 8️⃣ Próximas Fases

✅ **Fase 1**: Banco de Dados (concluído)  
✅ **Fase 1.5**: Segurança e Criptografia (você está aqui)  
⏭️ **Fase 2**: Backend API  
⏭️ **Fase 3**: Frontend React/Next.js  
⏭️ **Fase 4**: Integração de Pagamentos  

---

**Referências Adicionais:**
- [OWASP Top 10 2021](https://owasp.org/www-project-top-ten/)
- [Lei Geral de Proteção de Dados (LGPD)](http://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
- [Node.js Security Checklist](https://blog.risingstack.com/node-js-security-checklist/)
