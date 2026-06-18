# TrustCorp · SoulUp — Banco de Dados

> Modelagem e implementação do banco de dados relacional da plataforma SoulUp — projeto acadêmico desenvolvido para o Challenge FIAP 2026.

---

## Sobre o Projeto

O SoulUp é uma plataforma de mobilidade sustentável que recompensa usuários por escolherem meios de transporte de baixa emissão de carbono. Este repositório contém toda a modelagem e implementação do banco de dados relacional que sustenta o sistema — desenvolvido integralmente por **[Henrique Soares Serra](https://www.linkedin.com/in/henrique-s-s-47419a3aa/)** como frente de Banco de Dados do grupo TrustCorp.

O modelo foi construído no **Oracle SQL Developer Data Modeler**, seguindo padrões de nomenclatura consistentes: prefixo `TB_` para tabelas, `ID_` para chaves primárias e `FK_` para chaves estrangeiras. A implementação roda sobre **Oracle Database 21c**.

> O repositório principal do projeto (Front-End) está disponível em [github.com/Challenge-Trust/Challenge-FrontEnd](https://github.com/Challenge-Trust/Challenge-FrontEnd).

---

## Modelagem

O banco é composto por 8 tabelas inter-relacionadas que cobrem todo o ciclo da plataforma: cadastro de usuários, registro de viagens, cálculo de CO2 evitado, acumulação de créditos e resgate de recompensas.

| Tabela | Descrição |
|---|---|
| `TB_USUARIO` | Cadastro dos usuários da plataforma |
| `TB_TRANSPORTE` | Catálogo de modais sustentáveis (bike, metrô, ônibus, VLT...) |
| `TB_VIAGEM` | Viagens registradas pelos usuários |
| `TB_EMISSAO_CO2` | CO2 evitado calculado automaticamente por viagem |
| `TB_CREDITO` | Movimentação de créditos gerados pelas viagens |
| `TB_RECOMPENSA` | Catálogo de recompensas dos parceiros |
| `TB_RESGATE` | Resgates de recompensas realizados pelos usuários |
| `TB_HISTORICO_USO` | Log de ações relevantes do usuário |

---

## Regras de Negócio Implementadas

Além das restrições estruturais (PK, FK, UNIQUE e NOT NULL), o modelo aplica constraints e triggers PL/SQL que garantem a integridade do domínio:

| Constraint / Trigger | Regra |
|---|---|
| `CK_USUARIO_SALDO` | Saldo de créditos não pode ser negativo |
| `CK_USUARIO_EMAIL` | E-mail deve seguir o formato `%@%.%` |
| `CK_TRANSP_TIPO` | Tipo de transporte restrito a: BIKE, CARONA, METRO, ONIBUS, PATINETE, TREM, VLT |
| `CK_VIAGEM_STATUS` / `CK_RESGATE_STATUS` | Status controlado por enumeração |
| `TRG_PROTEGE_SALDO` | Trigger BEFORE UPDATE que impede saldo negativo no usuário |
| `TRG_VIAGEM_CREDITOS` | Trigger AFTER INSERT em TB_VIAGEM: calcula CO2 evitado, gera crédito e atualiza saldo automaticamente |

---

## Estrutura do Repositório

```
TrustCorp-Database/
│
├── trustcorp_script.sql        # Script DDL completo (CREATE TABLE, ALTER TABLE, TRIGGERS)
├── modelo_MER.png              # Diagrama Entidade-Relacionamento
└── documentacao.pdf            # Documentação completa da modelagem
```

---

## Como Executar

**Pré-requisito:** Oracle Database 21c ou superior.

1. Clone este repositório
   ```bash
   git clone https://github.com/henriquesoaresserra-h/TrustCorp-Database
   ```

2. Abra o Oracle SQL Developer e conecte-se ao seu banco.

3. Execute o script `trustcorp_script.sql` na sequência — ele cria todas as tabelas, constraints, sequences e triggers automaticamente.

---

## 👥 Equipe TrustCorp

| Integrante | RM | Frente |
|---|---|---|
| **[Henrique Soares Serra](https://www.linkedin.com/in/henrique-s-s-47419a3aa/)** | 573618 | Banco de Dados |
| [Nicolas Martins](https://github.com/NickRM22) | 573178 | Back-End Java |
| [Vinicius Soares](https://github.com/vinisl2510-sudo) | 573351 | Front-End |
| [Nicolas Frazão](https://github.com/Frazaomol) | 568780 | Agente Virtual |
| [Cauã Bertini](https://github.com/cauabertini) | 570451 | Python |

---

*Projeto acadêmico desenvolvido para o Challenge — FIAP, 2026.*
