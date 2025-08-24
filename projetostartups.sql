-- === Database ===
CREATE DATABASE IF NOT EXISTS plataforma_servicos
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE plataforma_servicos;

-- Para consistência
SET sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- ===================================================================
-- 1) USUÁRIOS (cliente, prestador, admin) – PF (CPF) ou PJ (CNPJ)
-- ===================================================================
DROP TABLE IF EXISTS usuarios;
CREATE TABLE usuarios (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  nome             VARCHAR(100) NOT NULL,
  email            VARCHAR(100) NOT NULL,
  senha_hash       VARCHAR(255) NOT NULL,
  telefone         VARCHAR(20),
  endereco         TEXT,
  tipo_usuario     ENUM('cliente','prestador','admin') NOT NULL,
  cpf              VARCHAR(14) UNIQUE,   -- permite NULL; UNIQUE em MySQL aceita múltiplos NULLs
  cnpj             VARCHAR(18) UNIQUE,   -- permite NULL
  foto_perfil      TEXT,
  criado_em        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  -- Regras leves (validação forte na aplicação):
  CONSTRAINT chk_usuario_doc CHECK (
      (tipo_usuario IN ('cliente','prestador','admin'))
  )
) ENGINE=InnoDB;

CREATE UNIQUE INDEX ux_usuarios_email ON usuarios(email);

-- ===================================================================
-- 2) LOJAS PARCEIRAS (somente PJ)
-- ===================================================================
DROP TABLE IF EXISTS lojas;
CREATE TABLE lojas (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  nome             VARCHAR(120) NOT NULL,
  email            VARCHAR(120) NOT NULL,
  telefone         VARCHAR(20),
  endereco         TEXT,
  cnpj             VARCHAR(18) NOT NULL,
  criado_em        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE UNIQUE INDEX ux_lojas_email ON lojas(email);
CREATE UNIQUE INDEX ux_lojas_cnpj  ON lojas(cnpj);

-- ===================================================================
-- 3) SERVIÇOS (cadastrados por prestadores PF ou PJ)
-- ===================================================================
DROP TABLE IF EXISTS servicos;
CREATE TABLE servicos (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id       INT NOT NULL, -- prestador
  titulo           VARCHAR(100) NOT NULL,
  descricao        TEXT,
  categoria        VARCHAR(50),
  preco            DECIMAL(10,2),
  disponivel       BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_servicos_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX ix_servicos_usuario   ON servicos(usuario_id);
CREATE INDEX ix_servicos_categoria ON servicos(categoria);
CREATE INDEX ix_servicos_disponivel ON servicos(disponivel);

-- ===================================================================
-- 4) FERRAMENTAS (somente LOJAS podem disponibilizar)
-- ===================================================================
DROP TABLE IF EXISTS ferramentas;
CREATE TABLE ferramentas (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  loja_id          INT NOT NULL,
  nome             VARCHAR(100) NOT NULL,
  descricao        TEXT,
  categoria        VARCHAR(50),
  preco_diaria     DECIMAL(10,2),
  disponivel       BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_ferramentas_loja
    FOREIGN KEY (loja_id) REFERENCES lojas(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX ix_ferramentas_loja       ON ferramentas(loja_id);
CREATE INDEX ix_ferramentas_categoria  ON ferramentas(categoria);
CREATE INDEX ix_ferramentas_disponivel ON ferramentas(disponivel);

-- ===================================================================
-- 5) SOLICITAÇÕES (pedido de serviço OU aluguel de ferramenta)
--    - Se tipo = 'servico'    -> cliente_id + prestador_id + servico_id
--    - Se tipo = 'ferramenta' -> cliente_id + loja_id + ferramenta_id
-- ===================================================================
DROP TABLE IF EXISTS solicitacoes;
CREATE TABLE solicitacoes (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id       INT NOT NULL,   -- cliente (PF ou PJ)
  prestador_id     INT,            -- usado quando for serviço
  loja_id          INT,            -- usado quando for ferramenta
  servico_id       INT,            -- quando tipo = 'servico'
  ferramenta_id    INT,            -- quando tipo = 'ferramenta'
  tipo             ENUM('servico','ferramenta') NOT NULL,
  status           ENUM('pendente','aceito','concluido','cancelado') NOT NULL DEFAULT 'pendente',
  data_inicio      DATE,
  data_fim         DATE,
  criado_em        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_solic_cliente
    FOREIGN KEY (cliente_id) REFERENCES usuarios(id),

  CONSTRAINT fk_solic_prestador
    FOREIGN KEY (prestador_id) REFERENCES usuarios(id),

  CONSTRAINT fk_solic_loja
    FOREIGN KEY (loja_id) REFERENCES lojas(id),

  CONSTRAINT fk_solic_servico
    FOREIGN KEY (servico_id) REFERENCES servicos(id),

  CONSTRAINT fk_solic_ferramenta
    FOREIGN KEY (ferramenta_id) REFERENCES ferramentas(id)
) ENGINE=InnoDB;

CREATE INDEX ix_solic_tipo     ON solicitacoes(tipo);
CREATE INDEX ix_solic_status   ON solicitacoes(status);
CREATE INDEX ix_solic_cliente  ON solicitacoes(cliente_id);
CREATE INDEX ix_solic_prestador ON solicitacoes(prestador_id);
CREATE INDEX ix_solic_loja     ON solicitacoes(loja_id);

-- ===================================================================
-- 6) TRANSAÇÕES (pagamentos de solicitações)
-- ===================================================================
DROP TABLE IF EXISTS transacoes;
CREATE TABLE transacoes (
  id                 INT AUTO_INCREMENT PRIMARY KEY,
  solicitacao_id     INT NOT NULL,
  valor              DECIMAL(10,2) NOT NULL,
  metodo_pagamento   ENUM('pix','cartao','boleto') NOT NULL,
  status_pagamento   ENUM('pendente','pago','falhou') NOT NULL DEFAULT 'pendente',
  criado_em          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_transacoes_solic
    FOREIGN KEY (solicitacao_id) REFERENCES solicitacoes(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX ix_transacoes_solic ON transacoes(solicitacao_id);
CREATE INDEX ix_transacoes_status ON transacoes(status_pagamento);

-- ===================================================================
-- 7) AVALIAÇÕES (pós-conclusão)
-- ===================================================================
DROP TABLE IF EXISTS avaliacoes;
CREATE TABLE avaliacoes (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  solicitacao_id   INT NOT NULL,
  avaliador_id     INT NOT NULL,
  avaliado_id      INT NOT NULL,
  nota             INT NOT NULL,
  comentario       TEXT,
  criado_em        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_avaliacoes_solic
    FOREIGN KEY (solicitacao_id) REFERENCES solicitacoes(id)
    ON DELETE CASCADE,

  CONSTRAINT fk_avaliacoes_avaliador
    FOREIGN KEY (avaliador_id) REFERENCES usuarios(id),

  CONSTRAINT fk_avaliacoes_avaliado
    FOREIGN KEY (avaliado_id) REFERENCES usuarios(id),

  CONSTRAINT chk_nota_range CHECK (nota BETWEEN 1 AND 5)
) ENGINE=InnoDB;

CREATE INDEX ix_avaliacoes_solic    ON avaliacoes(solicitacao_id);
CREATE INDEX ix_avaliacoes_avaliado ON avaliacoes(avaliado_id);

-- ===================================================================
-- 8) MENSAGENS (chat entre as partes dentro da solicitação)
-- ===================================================================
DROP TABLE IF EXISTS mensagens;
CREATE TABLE mensagens (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  solicitacao_id   INT NOT NULL,
  remetente_id     INT NOT NULL,
  destinatario_id  INT NOT NULL,
  conteudo         TEXT NOT NULL,
  enviado_em       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_msg_solic
    FOREIGN KEY (solicitacao_id) REFERENCES solicitacoes(id)
    ON DELETE CASCADE,

  CONSTRAINT fk_msg_remetente
    FOREIGN KEY (remetente_id)  REFERENCES usuarios(id),

  CONSTRAINT fk_msg_destinatario
    FOREIGN KEY (destinatario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB;

CREATE INDEX ix_msg_solic       ON mensagens(solicitacao_id);
CREATE INDEX ix_msg_remetente   ON mensagens(remetente_id);
CREATE INDEX ix_msg_destinatario ON mensagens(destinatario_id);

-- ===================================================================
-- SUGESTÕES (opcionais) DE CONSTRAINTS LÓGICAS NA APLICAÇÃO:
-- - Se solicitacoes.tipo='servico':
--     prestador_id NOT NULL, servico_id NOT NULL, loja_id NULL, ferramenta_id NULL
-- - Se solicitacoes.tipo='ferramenta':
--     loja_id NOT NULL, ferramenta_id NOT NULL, prestador_id NULL, servico_id NULL
-- - Validação de CPF/CNPJ, formatação e unicidade adicional devem ser feitas na aplicação.
-- ===================================================================
