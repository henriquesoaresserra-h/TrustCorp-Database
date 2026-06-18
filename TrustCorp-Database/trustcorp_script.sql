-- PROJETO: TrustCorp · SoulUp
-- Banco de Dados Oracle - Script completo
-- Autor: Henrique Soares Serra (RM 573618) — FIAP 1TDSPI
-- Descrição: Sistema de mobilidade sustentável que recompensa usuários
--            por escolherem transportes de baixa emissão de carbono.
--            Inclui acúmulo de créditos, resgate de recompensas e
--            medição automática de CO2 evitado por viagem.
-- Disciplina: Challenge — FIAP 2026
--
-- ORDEM DE EXECUÇÃO RECOMENDADA (no Oracle SQL Developer):
--   1) DROP de objetos (opcional, somente em re-execução)
--   2) CREATE SEQUENCES
--   3) CREATE TABLES (com PK, FK, CHECK, UNIQUE, DEFAULT)
--   4) INSERTS de dados de exemplo
--   5) CREATE VIEWS
--   6) CREATE FUNCTIONS / PROCEDURES / TRIGGERS
--   7) Consultas (SELECT, JOIN, GROUP BY, HAVING, ORDER BY, SUBQUERIES)
--------------------------------------------------------------------------------

--==============================================================================
-- 1) LIMPEZA (executar apenas em re-criação do schema)
--==============================================================================
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN (
              'TB_RESGATE','TB_HISTORICO_USO','TB_EMISSAO_CO2',
              'TB_CREDITO','TB_VIAGEM','TB_RECOMPENSA',
              'TB_TRANSPORTE','TB_USUARIO')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE '||t.table_name||' CASCADE CONSTRAINTS';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name LIKE 'SEQ\_%' ESCAPE '\') LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE '||s.sequence_name;
  END LOOP;
END;
/

--==============================================================================
-- 2) SEQUENCES (geração de IDs)
--==============================================================================
CREATE SEQUENCE seq_usuario       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_transporte    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_viagem        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_credito       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_recompensa    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_resgate       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_emissao       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_historico     START WITH 1 INCREMENT BY 1 NOCACHE;

--==============================================================================
-- 3) TABELAS
--==============================================================================

-- Usuários do aplicativo
CREATE TABLE tb_usuario (
  id_usuario     NUMBER(10)        PRIMARY KEY,
  nome           VARCHAR2(120)     NOT NULL,
  email          VARCHAR2(150)     NOT NULL UNIQUE,
  cpf            CHAR(11)          NOT NULL UNIQUE,
  senha_hash     VARCHAR2(255)     NOT NULL,
  data_nascimento DATE             NOT NULL,
  saldo_creditos NUMBER(10,2)      DEFAULT 0 NOT NULL,
  data_cadastro  DATE              DEFAULT SYSDATE NOT NULL,
  ativo          CHAR(1)           DEFAULT 'S' NOT NULL,
  CONSTRAINT ck_usuario_ativo  CHECK (ativo IN ('S','N')),
  CONSTRAINT ck_usuario_saldo  CHECK (saldo_creditos >= 0),
  CONSTRAINT ck_usuario_email  CHECK (email LIKE '%@%.%')
);

-- Meios de transporte sustentáveis cadastrados
CREATE TABLE tb_transporte (
  id_transporte    NUMBER(10)     PRIMARY KEY,
  nome             VARCHAR2(60)   NOT NULL UNIQUE,
  tipo             VARCHAR2(30)   NOT NULL, -- ONIBUS, METRO, TREM, BIKE, PATINETE, VLT, CARONA
  fator_co2_kg_km  NUMBER(8,4)    NOT NULL, -- emissão evitada por km vs carro
  creditos_por_km  NUMBER(6,2)    DEFAULT 1 NOT NULL,
  ativo            CHAR(1)        DEFAULT 'S' NOT NULL,
  CONSTRAINT ck_transp_tipo  CHECK (tipo IN ('ONIBUS','METRO','TREM','BIKE','PATINETE','VLT','CARONA')),
  CONSTRAINT ck_transp_fator CHECK (fator_co2_kg_km >= 0),
  CONSTRAINT ck_transp_cred  CHECK (creditos_por_km >= 0),
  CONSTRAINT ck_transp_ativo CHECK (ativo IN ('S','N'))
);

-- Viagens registradas
CREATE TABLE tb_viagem (
  id_viagem       NUMBER(10)     PRIMARY KEY,
  id_usuario      NUMBER(10)     NOT NULL,
  id_transporte   NUMBER(10)     NOT NULL,
  origem          VARCHAR2(120)  NOT NULL,
  destino         VARCHAR2(120)  NOT NULL,
  distancia_km    NUMBER(8,2)    NOT NULL,
  data_viagem     DATE           DEFAULT SYSDATE NOT NULL,
  status          VARCHAR2(15)   DEFAULT 'CONFIRMADA' NOT NULL,
  CONSTRAINT fk_viagem_usuario     FOREIGN KEY (id_usuario)
      REFERENCES tb_usuario(id_usuario),
  CONSTRAINT fk_viagem_transporte  FOREIGN KEY (id_transporte)
      REFERENCES tb_transporte(id_transporte),
  CONSTRAINT ck_viagem_dist        CHECK (distancia_km > 0),
  CONSTRAINT ck_viagem_status      CHECK (status IN ('CONFIRMADA','PENDENTE','CANCELADA'))
);

-- Créditos ganhos por viagem (extrato de entradas)
CREATE TABLE tb_credito (
  id_credito    NUMBER(10)    PRIMARY KEY,
  id_usuario    NUMBER(10)    NOT NULL,
  id_viagem     NUMBER(10),
  quantidade    NUMBER(10,2)  NOT NULL,
  origem        VARCHAR2(30)  DEFAULT 'VIAGEM' NOT NULL, -- VIAGEM, BONUS, AJUSTE
  data_credito  DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT fk_credito_usuario FOREIGN KEY (id_usuario)
      REFERENCES tb_usuario(id_usuario),
  CONSTRAINT fk_credito_viagem  FOREIGN KEY (id_viagem)
      REFERENCES tb_viagem(id_viagem),
  CONSTRAINT ck_credito_qtd CHECK (quantidade > 0),
  CONSTRAINT ck_credito_origem CHECK (origem IN ('VIAGEM','BONUS','AJUSTE'))
);

-- Catálogo de recompensas disponíveis
CREATE TABLE tb_recompensa (
  id_recompensa     NUMBER(10)    PRIMARY KEY,
  nome              VARCHAR2(120) NOT NULL UNIQUE,
  descricao         VARCHAR2(400),
  custo_creditos    NUMBER(10,2)  NOT NULL,
  estoque           NUMBER(6)     DEFAULT 0 NOT NULL,
  parceiro          VARCHAR2(120),
  ativo             CHAR(1)       DEFAULT 'S' NOT NULL,
  CONSTRAINT ck_recomp_custo   CHECK (custo_creditos > 0),
  CONSTRAINT ck_recomp_estoque CHECK (estoque >= 0),
  CONSTRAINT ck_recomp_ativo   CHECK (ativo IN ('S','N'))
);

-- Resgates de recompensas pelos usuários
CREATE TABLE tb_resgate (
  id_resgate       NUMBER(10)   PRIMARY KEY,
  id_usuario       NUMBER(10)   NOT NULL,
  id_recompensa    NUMBER(10)   NOT NULL,
  data_resgate     DATE         DEFAULT SYSDATE NOT NULL,
  creditos_gastos  NUMBER(10,2) NOT NULL,
  status           VARCHAR2(15) DEFAULT 'CONCLUIDO' NOT NULL,
  CONSTRAINT fk_resgate_usuario   FOREIGN KEY (id_usuario)
      REFERENCES tb_usuario(id_usuario),
  CONSTRAINT fk_resgate_recomp    FOREIGN KEY (id_recompensa)
      REFERENCES tb_recompensa(id_recompensa),
  CONSTRAINT ck_resgate_status    CHECK (status IN ('CONCLUIDO','PENDENTE','CANCELADO')),
  CONSTRAINT ck_resgate_gastos    CHECK (creditos_gastos > 0)
);

-- Registro de CO2 evitado por viagem
CREATE TABLE tb_emissao_co2 (
  id_emissao   NUMBER(10)   PRIMARY KEY,
  id_viagem    NUMBER(10)   NOT NULL UNIQUE,
  co2_evitado_kg NUMBER(10,4) NOT NULL,
  data_calculo DATE         DEFAULT SYSDATE NOT NULL,
  CONSTRAINT fk_emissao_viagem FOREIGN KEY (id_viagem)
      REFERENCES tb_viagem(id_viagem),
  CONSTRAINT ck_emissao_valor CHECK (co2_evitado_kg >= 0)
);

-- Histórico geral de uso do aplicativo (auditoria)
CREATE TABLE tb_historico_uso (
  id_historico NUMBER(10)   PRIMARY KEY,
  id_usuario   NUMBER(10)   NOT NULL,
  acao         VARCHAR2(60) NOT NULL,
  descricao    VARCHAR2(400),
  data_acao    DATE         DEFAULT SYSDATE NOT NULL,
  CONSTRAINT fk_hist_usuario FOREIGN KEY (id_usuario)
      REFERENCES tb_usuario(id_usuario)
);

--==============================================================================
-- 4) INSERTS DE DADOS DE EXEMPLO
--==============================================================================

-- Usuários
INSERT INTO tb_usuario (id_usuario,nome,email,cpf,senha_hash,data_nascimento)
  VALUES (seq_usuario.NEXTVAL,'Ana Carolina Silva','ana.silva@email.com','12345678901','hash_ana',DATE '1998-05-12');
INSERT INTO tb_usuario (id_usuario,nome,email,cpf,senha_hash,data_nascimento)
  VALUES (seq_usuario.NEXTVAL,'Bruno Henrique Costa','bruno.costa@email.com','22345678902','hash_bruno',DATE '1995-03-22');
INSERT INTO tb_usuario (id_usuario,nome,email,cpf,senha_hash,data_nascimento)
  VALUES (seq_usuario.NEXTVAL,'Carla Mendes Oliveira','carla.mendes@email.com','32345678903','hash_carla',DATE '2000-11-30');
INSERT INTO tb_usuario (id_usuario,nome,email,cpf,senha_hash,data_nascimento)
  VALUES (seq_usuario.NEXTVAL,'Diego Almeida','diego.almeida@email.com','42345678904','hash_diego',DATE '1992-07-09');
INSERT INTO tb_usuario (id_usuario,nome,email,cpf,senha_hash,data_nascimento)
  VALUES (seq_usuario.NEXTVAL,'Eduarda Lopes','eduarda.lopes@email.com','52345678905','hash_edu',DATE '1999-01-18');

-- Meios de transporte (fator CO2 evitado vs carro padrão ~0.192 kg/km)
INSERT INTO tb_transporte (id_transporte,nome,tipo,fator_co2_kg_km,creditos_por_km)
  VALUES (seq_transporte.NEXTVAL,'Ônibus Municipal','ONIBUS',0.0890,2);
INSERT INTO tb_transporte (id_transporte,nome,tipo,fator_co2_kg_km,creditos_por_km)
  VALUES (seq_transporte.NEXTVAL,'Metrô SP','METRO',0.1700,3);
INSERT INTO tb_transporte (id_transporte,nome,tipo,fator_co2_kg_km,creditos_por_km)
  VALUES (seq_transporte.NEXTVAL,'Trem CPTM','TREM',0.1500,3);
INSERT INTO tb_transporte (id_transporte,nome,tipo,fator_co2_kg_km,creditos_por_km)
  VALUES (seq_transporte.NEXTVAL,'Bicicleta Compartilhada','BIKE',0.1920,5);
INSERT INTO tb_transporte (id_transporte,nome,tipo,fator_co2_kg_km,creditos_por_km)
  VALUES (seq_transporte.NEXTVAL,'Patinete Elétrico','PATINETE',0.1500,4);
INSERT INTO tb_transporte (id_transporte,nome,tipo,fator_co2_kg_km,creditos_por_km)
  VALUES (seq_transporte.NEXTVAL,'VLT Centro','VLT',0.1600,3);

-- Recompensas
INSERT INTO tb_recompensa (id_recompensa,nome,descricao,custo_creditos,estoque,parceiro)
  VALUES (seq_recompensa.NEXTVAL,'Vale Café 10 reais','Voucher para café em rede parceira',50,100,'Cafeteria Verde');
INSERT INTO tb_recompensa (id_recompensa,nome,descricao,custo_creditos,estoque,parceiro)
  VALUES (seq_recompensa.NEXTVAL,'Desconto Bilhete Único','15% off na recarga do bilhete único',80,200,'SPTrans');
INSERT INTO tb_recompensa (id_recompensa,nome,descricao,custo_creditos,estoque,parceiro)
  VALUES (seq_recompensa.NEXTVAL,'Ingresso Cinema','Ingresso meia-entrada em sala parceira',150,50,'CineEco');
INSERT INTO tb_recompensa (id_recompensa,nome,descricao,custo_creditos,estoque,parceiro)
  VALUES (seq_recompensa.NEXTVAL,'Camiseta Trade Value','Camiseta oficial em algodão orgânico',300,30,'Trade Value');
INSERT INTO tb_recompensa (id_recompensa,nome,descricao,custo_creditos,estoque,parceiro)
  VALUES (seq_recompensa.NEXTVAL,'Plante uma Árvore','Plantio de muda em sua homenagem',200,500,'SOS Mata Atlântica');

-- Viagens (a TRIGGER fará: créditos + saldo + CO2 + histórico)
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,1,1,'Vila Mariana','Paulista',6.5);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,1,2,'Sé','Santana',9.0);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,2,4,'Pinheiros','Faria Lima',3.2);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,2,3,'Luz','Osasco',14.5);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,3,5,'Berrini','Vila Olímpia',2.0);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,3,2,'República','Tatuapé',11.0);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,4,6,'Barra Funda','Lapa',4.4);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,4,1,'Mooca','Brás',3.6);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,5,4,'Itaim','Vila Nova',5.5);
INSERT INTO tb_viagem (id_viagem,id_usuario,id_transporte,origem,destino,distancia_km)
  VALUES (seq_viagem.NEXTVAL,5,2,'Brás','Liberdade',7.8);

COMMIT;

--==============================================================================
-- 5) VIEWS
--==============================================================================

-- Saldo atual e total de créditos ganhos por usuário
CREATE OR REPLACE VIEW vw_saldo_usuario AS
SELECT u.id_usuario,
       u.nome,
       u.email,
       u.saldo_creditos,
       NVL(SUM(c.quantidade),0)  AS total_creditos_ganhos
FROM tb_usuario u
LEFT JOIN tb_credito c ON c.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.nome, u.email, u.saldo_creditos;

-- Ranking ambiental: CO2 evitado por usuário
CREATE OR REPLACE VIEW vw_ranking_co2 AS
SELECT u.id_usuario,
       u.nome,
       ROUND(NVL(SUM(e.co2_evitado_kg),0),3) AS co2_total_kg,
       COUNT(v.id_viagem) AS total_viagens
FROM tb_usuario u
LEFT JOIN tb_viagem v       ON v.id_usuario = u.id_usuario
LEFT JOIN tb_emissao_co2 e  ON e.id_viagem  = v.id_viagem
GROUP BY u.id_usuario, u.nome
ORDER BY co2_total_kg DESC;

-- Viagens detalhadas
CREATE OR REPLACE VIEW vw_viagens_detalhe AS
SELECT v.id_viagem, u.nome AS usuario, t.nome AS transporte, t.tipo,
       v.origem, v.destino, v.distancia_km, v.data_viagem,
       e.co2_evitado_kg
FROM tb_viagem v
JOIN tb_usuario u     ON u.id_usuario    = v.id_usuario
JOIN tb_transporte t  ON t.id_transporte = v.id_transporte
LEFT JOIN tb_emissao_co2 e ON e.id_viagem = v.id_viagem;

--==============================================================================
-- 6) FUNCTION - calcular CO2 evitado de uma viagem
--==============================================================================
CREATE OR REPLACE FUNCTION fn_calcular_co2 (
  p_distancia_km    IN NUMBER,
  p_fator_co2_kg_km IN NUMBER
) RETURN NUMBER IS
BEGIN
  -- regra: CO2 evitado = distância * fator (kg/km)
  RETURN ROUND(NVL(p_distancia_km,0) * NVL(p_fator_co2_kg_km,0), 4);
END;
/

--==============================================================================
-- 7) PROCEDURE - resgatar recompensa (debita saldo, valida estoque/saldo)
--==============================================================================
CREATE OR REPLACE PROCEDURE sp_resgatar_recompensa (
  p_id_usuario     IN NUMBER,
  p_id_recompensa  IN NUMBER
) IS
  v_custo    tb_recompensa.custo_creditos%TYPE;
  v_estoque  tb_recompensa.estoque%TYPE;
  v_saldo    tb_usuario.saldo_creditos%TYPE;
  v_ativo    tb_recompensa.ativo%TYPE;
BEGIN
  SELECT custo_creditos, estoque, ativo
    INTO v_custo, v_estoque, v_ativo
  FROM tb_recompensa WHERE id_recompensa = p_id_recompensa FOR UPDATE;

  IF v_ativo = 'N' THEN
     RAISE_APPLICATION_ERROR(-20010,'Recompensa inativa.');
  END IF;
  IF v_estoque <= 0 THEN
     RAISE_APPLICATION_ERROR(-20011,'Recompensa sem estoque.');
  END IF;

  SELECT saldo_creditos INTO v_saldo
  FROM tb_usuario WHERE id_usuario = p_id_usuario FOR UPDATE;

  IF v_saldo < v_custo THEN
     RAISE_APPLICATION_ERROR(-20012,'Saldo de créditos insuficiente.');
  END IF;

  UPDATE tb_usuario
     SET saldo_creditos = saldo_creditos - v_custo
   WHERE id_usuario = p_id_usuario;

  UPDATE tb_recompensa
     SET estoque = estoque - 1
   WHERE id_recompensa = p_id_recompensa;

  INSERT INTO tb_resgate (id_resgate,id_usuario,id_recompensa,creditos_gastos)
  VALUES (seq_resgate.NEXTVAL, p_id_usuario, p_id_recompensa, v_custo);

  INSERT INTO tb_historico_uso (id_historico,id_usuario,acao,descricao)
  VALUES (seq_historico.NEXTVAL, p_id_usuario, 'RESGATE',
          'Resgatou recompensa '||p_id_recompensa||' por '||v_custo||' créditos.');

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/

--==============================================================================
-- 8) TRIGGER - ao inserir viagem CONFIRMADA:
--    a) calcular e gravar CO2 evitado
--    b) gerar crédito proporcional
--    c) somar saldo do usuário
--    d) registrar histórico
--==============================================================================
CREATE OR REPLACE TRIGGER trg_viagem_creditos
AFTER INSERT ON tb_viagem
FOR EACH ROW
DECLARE
  v_fator    tb_transporte.fator_co2_kg_km%TYPE;
  v_cred_km  tb_transporte.creditos_por_km%TYPE;
  v_co2      NUMBER;
  v_credito  NUMBER;
BEGIN
  IF :NEW.status <> 'CONFIRMADA' THEN
     RETURN;
  END IF;

  SELECT fator_co2_kg_km, creditos_por_km
    INTO v_fator, v_cred_km
  FROM tb_transporte WHERE id_transporte = :NEW.id_transporte;

  v_co2     := fn_calcular_co2(:NEW.distancia_km, v_fator);
  v_credito := ROUND(:NEW.distancia_km * v_cred_km, 2);

  INSERT INTO tb_emissao_co2 (id_emissao,id_viagem,co2_evitado_kg)
  VALUES (seq_emissao.NEXTVAL, :NEW.id_viagem, v_co2);

  INSERT INTO tb_credito (id_credito,id_usuario,id_viagem,quantidade,origem)
  VALUES (seq_credito.NEXTVAL, :NEW.id_usuario, :NEW.id_viagem, v_credito, 'VIAGEM');

  UPDATE tb_usuario
     SET saldo_creditos = saldo_creditos + v_credito
   WHERE id_usuario = :NEW.id_usuario;

  INSERT INTO tb_historico_uso (id_historico,id_usuario,acao,descricao)
  VALUES (seq_historico.NEXTVAL, :NEW.id_usuario, 'VIAGEM',
          'Viagem '||:NEW.id_viagem||' gerou '||v_credito||
          ' créditos e evitou '||v_co2||' kg de CO2.');
END;
/

--==============================================================================
-- 9) TRIGGER - protege saldo negativo (defesa em profundidade)
--==============================================================================
CREATE OR REPLACE TRIGGER trg_protege_saldo
BEFORE UPDATE OF saldo_creditos ON tb_usuario
FOR EACH ROW
BEGIN
  IF :NEW.saldo_creditos < 0 THEN
    RAISE_APPLICATION_ERROR(-20020,'Saldo de créditos não pode ser negativo.');
  END IF;
END;
/

--==============================================================================
-- 10) TESTES PRÁTICOS
--==============================================================================
-- Resgatar recompensa (exemplo)
BEGIN
  sp_resgatar_recompensa(p_id_usuario => 1, p_id_recompensa => 1);
END;
/

--==============================================================================
-- 11) CONSULTAS DE EXEMPLO
--==============================================================================

-- SELECT simples
SELECT * FROM tb_usuario ORDER BY nome;

-- JOIN: viagens com usuário e transporte
SELECT v.id_viagem, u.nome AS usuario, t.nome AS transporte,
       v.origem, v.destino, v.distancia_km
FROM tb_viagem v
JOIN tb_usuario u    ON u.id_usuario    = v.id_usuario
JOIN tb_transporte t ON t.id_transporte = v.id_transporte
ORDER BY v.data_viagem DESC;

-- GROUP BY + HAVING + ORDER BY: usuários com mais de 1 viagem
SELECT u.nome, COUNT(v.id_viagem) AS qtd_viagens,
       SUM(v.distancia_km)         AS km_total
FROM tb_usuario u
JOIN tb_viagem v ON v.id_usuario = u.id_usuario
GROUP BY u.nome
HAVING COUNT(v.id_viagem) > 1
ORDER BY km_total DESC;

-- Subquery: usuários com saldo acima da média
SELECT nome, saldo_creditos
FROM tb_usuario
WHERE saldo_creditos > (SELECT AVG(saldo_creditos) FROM tb_usuario)
ORDER BY saldo_creditos DESC;

-- Subquery correlacionada: última viagem de cada usuário
SELECT u.nome,
       (SELECT MAX(v.data_viagem)
          FROM tb_viagem v
         WHERE v.id_usuario = u.id_usuario) AS ultima_viagem
FROM tb_usuario u;

-- Ranking CO2
SELECT * FROM vw_ranking_co2;

-- Saldo
SELECT * FROM vw_saldo_usuario ORDER BY saldo_creditos DESC;

-- Total de CO2 evitado pela plataforma
SELECT ROUND(SUM(co2_evitado_kg),3) AS co2_total_kg_plataforma
FROM tb_emissao_co2;
