# 🚀 Guia Rápido: Setup do Banco de Dados

Instruções passo a passo para configurar e testar o banco de dados PostgreSQL.

---

## ✅ Pré-requisitos

- PostgreSQL 12+ instalado
- `psql` (client PostgreSQL) disponível no PATH
- Git e editor de texto

---

## 📦 Passo 1: Instalar PostgreSQL

### Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# Iniciar serviço
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verificar status
sudo systemctl status postgresql
```

### macOS (Homebrew)
```bash
brew install postgresql@15

# Iniciar serviço
brew services start postgresql@15

# Verificar status
brew services list
```

### Windows
1. Download de https://www.postgresql.org/download/windows/
2. Execute o instalador
3. Anote a senha do usuário `postgres`
4. Escolha porta 5432 (padrão)
5. Instale pgAdmin 4 (optional)

---

## 📝 Passo 2: Criar Banco de Dados

```bash
# Conectar como superuser
psql -U postgres

# Dentro do psql, executar:
CREATE DATABASE saas_inscricoes;
CREATE USER saas_app WITH PASSWORD 'senha_segura_aqui';
ALTER ROLE saas_app SET client_encoding TO 'utf8';
ALTER ROLE saas_app SET default_transaction_isolation TO 'read committed';
ALTER ROLE saas_app SET default_transaction_deferrable TO on;
ALTER ROLE saas_app SET default_transaction_readonly TO off;
GRANT ALL PRIVILEGES ON DATABASE saas_inscricoes TO saas_app;

# Sair
\q
```

---

## 🗃️ Passo 3: Executar Script SQL

### Opção A: Via arquivo
```bash
# Salve o arquivo 01_init_database.sql na pasta local

# Execute:
psql -U postgres -d saas_inscricoes -f ./01_init_database.sql

# Se der erro de permissão, use:
sudo -u postgres psql -d saas_inscricoes -f ./01_init_database.sql
```

### Opção B: Via cópia/cola
```bash
# Conectar
psql -U postgres -d saas_inscricoes

# Colar o conteúdo do arquivo 01_init_database.sql
# (Dentro do psql, use \i se o arquivo estiver no disco)
\i /caminho/completo/para/01_init_database.sql

# Sair
\q
```

---

## ✔️ Passo 4: Verificar Criação

```bash
# Conectar ao banco
psql -U saas_app -d saas_inscricoes -h localhost

# Listar tabelas
\dt

# Saída esperada:
#                    List of relations
#  Schema |            Name            | Type  | Owner
# --------+----------------------------+-------+---------
#  public | organizations              | table | postgres
#  public | events                     | table | postgres
#  public | ticket_batches             | table | postgres
#  public | custom_fields              | table | postgres
#  public | registrations              | table | postgres
#  public | registration_answers       | table | postgres
#  public | coupons                    | table | postgres
#  public | audit_logs                 | table | postgres

# Verificar índices
\di

# Verificar views
\dv

# Sair
\q
```

---

## 🧪 Passo 5: Teste de Dados (Opcional)

```bash
psql -U saas_app -d saas_inscricoes -h localhost

-- Inserir organização de teste
INSERT INTO organizations (name, slug, email)
VALUES ('Meu Evento 2025', 'meu-evento-2025', 'admin@meuevento.com')
RETURNING id;

-- Copiar o ID retornado (ex: a1b2c3d4...)

-- Inserir evento
INSERT INTO events (organization_id, title, start_date, status, max_registrations)
VALUES ('a1b2c3d4-...', 'Conferência 2025', '2025-06-15 09:00:00', 'published', 500)
RETURNING id;

-- Copiar o ID do evento

-- Inserir lote de ingressos
INSERT INTO ticket_batches (event_id, name, price, service_fee, total_tickets, available_tickets, sale_start_date, sale_end_date)
VALUES ('evento-id-aqui', 'Ingresso Normal', 79.90, 5.00, 100, 100, '2025-05-01', '2025-06-15')
RETURNING id;

-- Verificar dados
SELECT * FROM organizations;
SELECT * FROM events;
SELECT * FROM ticket_batches;

-- Sair
\q
```

---

## 📊 Passo 6: Configurar Backup

```bash
# Fazer backup do banco
pg_dump -U saas_app -d saas_inscricoes -h localhost > backup_saas_inscricoes.sql

# Comprimir
gzip backup_saas_inscricoes.sql

# Restaurar de um backup
gunzip backup_saas_inscricoes.sql.gz
psql -U saas_app -d saas_inscricoes -h localhost < backup_saas_inscricoes.sql
```

---

## 🔒 Passo 7: Configurar .env (Para Backend)

Crie arquivo `.env` na raiz do projeto:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=saas_app
DB_PASSWORD=senha_segura_aqui
DB_NAME=saas_inscricoes

# Aplicação
NODE_ENV=development
PORT=3000

# Criptografia (gerar com: openssl rand -hex 32)
ENCRYPTION_KEY=cole_aqui_a_chave_de_32_bytes_em_hex

# Payment Gateway
STRIPE_SECRET_KEY=sk_test_xxxxx
MERCADO_PAGO_ACCESS_TOKEN=xxxxx

# JWT
JWT_SECRET=seu_jwt_secret_super_secreto

# Redis (opcional)
REDIS_URL=redis://localhost:6379
```

---

## 🧬 Passo 8: TypeORM (Se usar Node.js)

```bash
# Instalar dependências
npm install typeorm pg --save

# Copiar arquivo typeorm.config.ts para src/

# Executar migrations (se usar TypeORM)
npx typeorm migration:run -d src/database/data-source.ts

# Reverter migration se necessário
npx typeorm migration:revert -d src/database/data-source.ts
```

---

## 🐍 Passo 9: SQLAlchemy (Se usar Python)

```bash
# Instalar dependências
pip install SQLAlchemy psycopg2 python-dotenv

# Exemplo de conexão em Python
from sqlalchemy import create_engine

engine = create_engine(
    'postgresql://saas_app:senha_aqui@localhost:5432/saas_inscricoes'
)

# Testar conexão
with engine.connect() as connection:
    result = connection.execute("SELECT 1")
    print(result.fetchone())
```

---

## 📈 Monitoramento Básico

```bash
# Ver tamanho do banco
psql -U saas_app -d saas_inscricoes -h localhost -c \
  "SELECT pg_size_pretty(pg_database_size('saas_inscricoes'));"

# Ver número de registros por tabela
psql -U saas_app -d saas_inscricoes -h localhost -c \
  "SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"

# Ver conexões ativas
psql -U saas_app -d saas_inscricoes -h localhost -c \
  "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"
```

---

## 🚨 Troubleshooting

### Erro: "psql: command not found"
```bash
# macOS
brew install postgresql

# Linux
sudo apt-get install postgresql-client

# Windows: Adicione ao PATH:
# C:\Program Files\PostgreSQL\15\bin
```

### Erro: "FATAL: Peer authentication failed"
```bash
# No Linux, use sudo:
sudo -u postgres psql -d saas_inscricoes

# Ou configure /etc/postgresql/*/main/pg_hba.conf
# Mude 'peer' para 'md5' na linha local
```

### Erro: "database saas_inscricoes does not exist"
```bash
# Criar banco antes
psql -U postgres
CREATE DATABASE saas_inscricoes;
\q

# Depois executar o script
psql -U postgres -d saas_inscricoes -f 01_init_database.sql
```

### Erro: "role saas_app does not exist"
```bash
# Criar role
psql -U postgres
CREATE ROLE saas_app WITH LOGIN PASSWORD 'senha';
\q
```

### Conexão recusada em localhost:5432
```bash
# Verificar se PostgreSQL está rodando
psql -U postgres  # Sem -h localhost

# Se conexão TCP não funcionar, use socket Unix:
psql -U postgres -h /var/run/postgresql  # Linux
```

---

## ✨ Próximos Passos

1. ✅ **Banco criado**? Vá para **Fase 2: Backend API**
2. Tenha os dados de conexão em mãos
3. Copie o arquivo `.env.example` para `.env`
4. Preencha com as credenciais do BD
5. Comece a implementar os serviços

---

## 📖 Referências

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [psql Cheat Sheet](https://www.postgresql.org/docs/current/app-psql.html)
- [TypeORM Migrations](https://typeorm.io/migrations)
- [SQLAlchemy Docs](https://docs.sqlalchemy.org/)

---

## 💡 Dica de Desenvolvimento

Para facilitar o desenvolvimento local, use **Docker Compose**:

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: saas_inscricoes
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./01_init_database.sql:/docker-entrypoint-initdb.d/init.sql

  adminer:
    image: adminer
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  postgres_data:
```

Depois:
```bash
docker-compose up -d
# PostgreSQL rodando em localhost:5432
# Adminer (GUI) em http://localhost:8080
```

---

**Pronto para a Fase 2? 🚀**
