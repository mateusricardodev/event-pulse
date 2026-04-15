// ============================================================================
// typeorm.config.ts - Configuração do TypeORM
// ============================================================================

import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';

dotenv.config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'saas_inscricoes',
  
  // Entities (seão criadas na Fase 2)
  entities: [
    'src/entities/*.entity.ts',
  ],
  
  // Migrations
  migrations: [
    'src/database/migrations/*.ts',
  ],
  
  // Configurações
  synchronize: false, // NUNCA use synchronize em produção
  logging: process.env.NODE_ENV === 'development',
  logNotifications: true,
});

// ============================================================================
// .env.example - Variáveis de Ambiente
// ============================================================================

/*
# Database
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=seu_password_super_secreto
DB_NAME=saas_inscricoes

# Aplicação
NODE_ENV=development
PORT=3000

# Criptografia
ENCRYPTION_KEY=sua_chave_aes_256_aqui_em_hex

# Payment Gateway
STRIPE_SECRET_KEY=sk_test_xxx
MERCADO_PAGO_ACCESS_TOKEN=xxx

# JWT (para autenticação de admin)
JWT_SECRET=sua_jwt_secret_aqui

# Redis (opcional, para cache/filas)
REDIS_URL=redis://localhost:6379
*/

// ============================================================================
// src/database/migrations/001_initial_schema.ts
// ============================================================================

import { MigrationInterface, QueryRunner, Table, Index, TableForeignKey } from 'typeorm';

export class InitialSchema1001000000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Habilitar extensões
    await queryRunner.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
    await queryRunner.query('CREATE EXTENSION IF NOT EXISTS "pgcrypto"');

    // ===== ORGANIZATIONS =====
    await queryRunner.createTable(
      new Table({
        name: 'organizations',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'name',
            type: 'varchar',
            length: '255',
            isNullable: false,
          },
          {
            name: 'slug',
            type: 'varchar',
            length: '100',
            isNullable: false,
            isUnique: true,
          },
          {
            name: 'email',
            type: 'varchar',
            length: '255',
            isNullable: false,
            isUnique: true,
          },
          {
            name: 'phone',
            type: 'varchar',
            length: '20',
            isNullable: true,
          },
          {
            name: 'logo_url',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'primary_color',
            type: 'varchar',
            length: '7',
            default: "'#8000FF'",
          },
          {
            name: 'secondary_color',
            type: 'varchar',
            length: '7',
            default: "'#00C9A7'",
          },
          {
            name: 'country_code',
            type: 'varchar',
            length: '2',
            default: "'BR'",
          },
          {
            name: 'timezone',
            type: 'varchar',
            length: '50',
            default: "'America/Sao_Paulo'",
          },
          {
            name: 'payment_gateway',
            type: 'varchar',
            length: '50',
            isNullable: true,
          },
          {
            name: 'is_active',
            type: 'boolean',
            default: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
      }),
      true
    );

    await queryRunner.createIndex(
      'organizations',
      new Index({
        name: 'idx_organizations_slug',
        columnNames: ['slug'],
      })
    );

    await queryRunner.createIndex(
      'organizations',
      new Index({
        name: 'idx_organizations_email',
        columnNames: ['email'],
      })
    );

    // ===== EVENTS =====
    await queryRunner.createTable(
      new Table({
        name: 'events',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'organization_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'title',
            type: 'varchar',
            length: '255',
            isNullable: false,
          },
          {
            name: 'description',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'image_url',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'location',
            type: 'varchar',
            length: '500',
            isNullable: true,
          },
          {
            name: 'start_date',
            type: 'timestamp',
            isNullable: false,
          },
          {
            name: 'end_date',
            type: 'timestamp',
            isNullable: true,
          },
          {
            name: 'registration_deadline',
            type: 'timestamp',
            isNullable: true,
          },
          {
            name: 'status',
            type: 'varchar',
            length: '50',
            default: "'draft'",
          },
          {
            name: 'max_registrations',
            type: 'int',
            isNullable: true,
          },
          {
            name: 'current_registrations',
            type: 'int',
            default: 0,
          },
          {
            name: 'require_approval',
            type: 'boolean',
            default: false,
          },
          {
            name: 'allow_duplicate_email',
            type: 'boolean',
            default: false,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['organization_id'],
            referencedTableName: 'organizations',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
        ],
      }),
      true
    );

    await queryRunner.createIndex(
      'events',
      new Index({
        name: 'idx_events_organization',
        columnNames: ['organization_id'],
      })
    );

    // ===== TICKET_BATCHES =====
    await queryRunner.createTable(
      new Table({
        name: 'ticket_batches',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'event_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'name',
            type: 'varchar',
            length: '255',
            isNullable: false,
          },
          {
            name: 'description',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'price',
            type: 'decimal',
            precision: 10,
            scale: 2,
            default: 0,
          },
          {
            name: 'service_fee',
            type: 'decimal',
            precision: 10,
            scale: 2,
            default: 0,
          },
          {
            name: 'currency',
            type: 'varchar',
            length: '3',
            default: "'BRL'",
          },
          {
            name: 'total_tickets',
            type: 'int',
            isNullable: false,
          },
          {
            name: 'available_tickets',
            type: 'int',
            isNullable: false,
          },
          {
            name: 'sold_tickets',
            type: 'int',
            default: 0,
          },
          {
            name: 'sale_start_date',
            type: 'timestamp',
            isNullable: false,
          },
          {
            name: 'sale_end_date',
            type: 'timestamp',
            isNullable: false,
          },
          {
            name: 'is_active',
            type: 'boolean',
            default: true,
          },
          {
            name: 'is_early_bird',
            type: 'boolean',
            default: false,
          },
          {
            name: 'display_order',
            type: 'int',
            default: 0,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['event_id'],
            referencedTableName: 'events',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
        ],
      }),
      true
    );

    // ===== CUSTOM_FIELDS =====
    await queryRunner.createTable(
      new Table({
        name: 'custom_fields',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'event_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'field_name',
            type: 'varchar',
            length: '255',
            isNullable: false,
          },
          {
            name: 'field_type',
            type: 'varchar',
            length: '50',
            isNullable: false,
          },
          {
            name: 'placeholder',
            type: 'varchar',
            length: '255',
            isNullable: true,
          },
          {
            name: 'help_text',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'is_required',
            type: 'boolean',
            default: false,
          },
          {
            name: 'validation_pattern',
            type: 'varchar',
            length: '500',
            isNullable: true,
          },
          {
            name: 'options',
            type: 'jsonb',
            isNullable: true,
          },
          {
            name: 'input_mask',
            type: 'varchar',
            length: '50',
            isNullable: true,
          },
          {
            name: 'display_order',
            type: 'int',
            default: 0,
          },
          {
            name: 'is_pii',
            type: 'boolean',
            default: false,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['event_id'],
            referencedTableName: 'events',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
        ],
      }),
      true
    );

    // ===== REGISTRATIONS =====
    await queryRunner.createTable(
      new Table({
        name: 'registrations',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'event_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'ticket_batch_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'organization_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'email',
            type: 'varchar',
            length: '255',
            isNullable: false,
          },
          {
            name: 'phone',
            type: 'varchar',
            length: '20',
            isNullable: true,
          },
          {
            name: 'full_name',
            type: 'varchar',
            length: '255',
            isNullable: true,
          },
          {
            name: 'cpf_encrypted',
            type: 'varchar',
            length: '255',
            isNullable: true,
          },
          {
            name: 'cpf_hash',
            type: 'varchar',
            length: '255',
            isNullable: true,
            isUnique: true,
          },
          {
            name: 'custom_fields_data',
            type: 'jsonb',
            isNullable: true,
          },
          {
            name: 'status',
            type: 'varchar',
            length: '50',
            default: "'pending'",
          },
          {
            name: 'payment_status',
            type: 'varchar',
            length: '50',
            default: "'unpaid'",
          },
          {
            name: 'payment_method',
            type: 'varchar',
            length: '50',
            isNullable: true,
          },
          {
            name: 'payment_id',
            type: 'varchar',
            length: '255',
            isNullable: true,
          },
          {
            name: 'amount_paid',
            type: 'decimal',
            precision: 10,
            scale: 2,
            isNullable: true,
          },
          {
            name: 'ticket_quantity',
            type: 'int',
            default: 1,
          },
          {
            name: 'confirmation_token',
            type: 'varchar',
            length: '255',
            isNullable: true,
            isUnique: true,
          },
          {
            name: 'confirmed_at',
            type: 'timestamp',
            isNullable: true,
          },
          {
            name: 'ip_address',
            type: 'inet',
            isNullable: true,
          },
          {
            name: 'user_agent',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['event_id'],
            referencedTableName: 'events',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
          new TableForeignKey({
            columnNames: ['ticket_batch_id'],
            referencedTableName: 'ticket_batches',
            referencedColumnNames: ['id'],
            onDelete: 'RESTRICT',
          }),
          new TableForeignKey({
            columnNames: ['organization_id'],
            referencedTableName: 'organizations',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
        ],
      }),
      true
    );

    // Criar índices para registrations
    const indices = [
      { name: 'idx_registrations_event', columns: ['event_id'] },
      { name: 'idx_registrations_organization', columns: ['organization_id'] },
      { name: 'idx_registrations_ticket_batch', columns: ['ticket_batch_id'] },
      { name: 'idx_registrations_email', columns: ['email'] },
      { name: 'idx_registrations_cpf_hash', columns: ['cpf_hash'] },
      { name: 'idx_registrations_payment_id', columns: ['payment_id'] },
      { name: 'idx_registrations_status', columns: ['event_id', 'status'] },
      { name: 'idx_registrations_payment_status', columns: ['event_id', 'payment_status'] },
      { name: 'idx_registrations_created', columns: ['created_at'] },
      { name: 'idx_registrations_org_event', columns: ['organization_id', 'event_id'] },
    ];

    for (const index of indices) {
      await queryRunner.createIndex(
        'registrations',
        new Index({
          name: index.name,
          columnNames: index.columns,
        })
      );
    }

    // ===== REGISTRATION_ANSWERS =====
    await queryRunner.createTable(
      new Table({
        name: 'registration_answers',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'registration_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'custom_field_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'answer_value',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['registration_id'],
            referencedTableName: 'registrations',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
          new TableForeignKey({
            columnNames: ['custom_field_id'],
            referencedTableName: 'custom_fields',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
        ],
      }),
      true
    );

    // ===== COUPONS =====
    await queryRunner.createTable(
      new Table({
        name: 'coupons',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'event_id',
            type: 'uuid',
            isNullable: false,
          },
          {
            name: 'code',
            type: 'varchar',
            length: '50',
            isNullable: false,
            isUnique: true,
          },
          {
            name: 'description',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'discount_type',
            type: 'varchar',
            length: '20',
            isNullable: false,
          },
          {
            name: 'discount_value',
            type: 'decimal',
            precision: 10,
            scale: 2,
            isNullable: false,
          },
          {
            name: 'max_uses',
            type: 'int',
            isNullable: true,
          },
          {
            name: 'current_uses',
            type: 'int',
            default: 0,
          },
          {
            name: 'valid_from',
            type: 'timestamp',
            isNullable: true,
          },
          {
            name: 'valid_until',
            type: 'timestamp',
            isNullable: true,
          },
          {
            name: 'applicable_batches',
            type: 'jsonb',
            isNullable: true,
          },
          {
            name: 'is_active',
            type: 'boolean',
            default: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['event_id'],
            referencedTableName: 'events',
            referencedColumnNames: ['id'],
            onDelete: 'CASCADE',
          }),
        ],
      }),
      true
    );

    // ===== AUDIT_LOGS =====
    await queryRunner.createTable(
      new Table({
        name: 'audit_logs',
        columns: [
          {
            name: 'id',
            type: 'uuid',
            isPrimary: true,
            generationStrategy: 'uuid',
            default: 'gen_random_uuid()',
          },
          {
            name: 'organization_id',
            type: 'uuid',
            isNullable: true,
          },
          {
            name: 'action',
            type: 'varchar',
            length: '100',
            isNullable: false,
          },
          {
            name: 'resource_type',
            type: 'varchar',
            length: '50',
            isNullable: true,
          },
          {
            name: 'resource_id',
            type: 'uuid',
            isNullable: true,
          },
          {
            name: 'user_id',
            type: 'uuid',
            isNullable: true,
          },
          {
            name: 'ip_address',
            type: 'inet',
            isNullable: true,
          },
          {
            name: 'user_agent',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'old_values',
            type: 'jsonb',
            isNullable: true,
          },
          {
            name: 'new_values',
            type: 'jsonb',
            isNullable: true,
          },
          {
            name: 'status',
            type: 'varchar',
            length: '50',
            isNullable: true,
          },
          {
            name: 'error_message',
            type: 'text',
            isNullable: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
        ],
        foreignKeys: [
          new TableForeignKey({
            columnNames: ['organization_id'],
            referencedTableName: 'organizations',
            referencedColumnNames: ['id'],
            onDelete: 'SET NULL',
          }),
        ],
      }),
      true
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Dropar todas as tabelas em ordem reversa
    const tables = [
      'audit_logs',
      'coupons',
      'registration_answers',
      'registrations',
      'custom_fields',
      'ticket_batches',
      'events',
      'organizations',
    ];

    for (const table of tables) {
      await queryRunner.dropTable(table, true);
    }
  }
}
