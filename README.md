# Migrador Automatizado Firebird 2.5 para 5.0 - Sistemas Fortes

Script nativo em PowerShell/Batch desenvolvido para automatizar a migração das bases de dados dos sistemas Fortes Tecnologia (AC, Ponto, AG, Patrio, Cargas e Frota) do Firebird 2.5.5 (legado) para o Firebird 5.0.3, garantindo integridade de dados, conversão de ODS (11.x -> 13.x), segurança de backup e ajuste automático de strings de conexão.

---

## 📋 Características e Funcionalidades

- **Identificação Automática do Sistema:** Reconhece automaticamente os bancos e diretórios dos módulos **AC**, **Ponto**, **AG**, **Patrio**, **Cargas** e **Frota**.
- **Inspeção de Cabeçalho (ODS):** Lê os bytes do cabeçalho físico da base selecionada para validar se ela já está migrada em ODS 13.x (Firebird 5.0) ou se ainda está em ODS 11.x (Firebird 2.5), prevenindo execuções redundantes.
- **Validação Preditiva de Disco (2.1x):** Verifica se a partição do banco possui espaço livre equivalente a pelo menos o dobro mais 10% ($2{,}1 \times \text{tamanho}$) do arquivo `.fdb` original antes de iniciar qualquer operação.
- **Deploy Automático do Firebird 5.0:** Extrai os binários compactados, grava as chaves de registro no Windows (`instreg.exe`) e cria/inicia o serviço do Firebird 5.0 na porta configurada.
- **Checkpoint / Recuperação de Falhas:** Caso o processo seja interrompido após o backup, o script detecta o `.fbk` temporário e pergunta ao operador se deseja reutilizá-lo, economizando tempo em bases pesadas.
- **Transição Segura de Serviços:** Remove os serviços antigos do FB 2.5 apenas após a validação do restore no FB 5.0.
- **Ajuste Automatizado de Conexão (`.ini`):** Atualiza de forma direta as referências de porta (`53052` -> `53055`) em parâmetros como `DatabaseFile`, `DatabaseURL` e `SERVER NAME` nos arquivos de configuração do sistema (`AC.ini`, `Ponto.ini`, etc.), criando backup `.ini_BKP_timestamp` prévio.

---

## 🗂 Estrutura de Arquivos

O pacote de migração deve ser distribuído com a seguinte organização de pastas:

```text
MigradorFortes/
│
├── ExecutarMigracao.bat         # Wrapper com auto-elevação para Administrador
├── Migrar-Firebird.ps1          # Script principal com todas as rotinas de migração
├── README.md                    # Documentação do procedimento
│
└── Binarios/
    └── Firebird_5_0.zip         # Pacote zipado com os binários do Firebird 5.0 (x64)
```

---

## ⚙️ Parâmetros Técnicos de Execução

| Parâmetro | Firebird 2.5 (Origem) | Firebird 5.0 (Destino) |
| :--- | :--- | :--- |
| **Diretório Padrão** | `C:\Fortes\Firebird\Firebird_2_5` | `C:\Fortes\Firebird\Firebird_5_0` |
| **Porta TCP** | `53052` | `53055` |
| **ODS Suportada** | 11.2 | 13.1 |
| **Nome do Serviço Server** | `FirebirdServerFortes_FB2_5` | `FirebirdServerFortes_FB5_0` |
| **Nome do Serviço Guardian** | `FirebirdGuardianFortes_FB2_5` | *(Descontinuado no FB 5.0)* |

---

## 🚀 Como Executar

1. **Feche os Sistemas:** Certifique-se de que nenhum usuário esteja operando os sistemas Fortes na rede ou localmente no servidor.
2. **Execute o Inicializador:**
   - Clique com o botão direito em `ExecutarMigracao.bat` e selecione **Executar como Administrador** (o script também possui elevação automática caso seja aberto por clique duplo).
3. **Selecione a Base:**
   - Uma caixa de diálogo do Windows será aberta. Navegue até a pasta do sistema (ex: `C:\Fortes\AC` ou `C:\Fortes\Ponto`) e selecione o banco `.fdb` a ser migrado.
4. **Acompanhe as Etapas:**
   - **Etapa 1:** Instalação e inicialização do serviço Firebird 5.0 (Porta 53055).
   - **Etapa 2:** Validação da ODS, detecção do módulo do sistema e checagem de espaço em disco.
   - **Etapa 3:** Parada/rearranque de segurança do FB 2.5 e extração do backup via `gbak.exe`.
   - **Etapa 4:** Restauração do backup na nova arquitetura do FB 5.0.
   - **Etapa 5:** Desativação e exclusão dos serviços obsoletos do FB 2.5.
   - **Etapa 6:** Renomeação do banco antigo para `NOME_OLD_DATAHORA` e posicionamento da base final migrada.
   - **Etapa 7:** Backup e atualização das portas nos arquivos `.ini`.

---

## 🛡️ Medidas de Segurança e Rollback

### O que o script preserva:
- **Base antiga intacta:** O banco original nunca é sobrescrito diretamente; ele é renomeado para `<NomeDoBanco>.fdb_OLD_yyyyMMdd_HHmmss`.
- **Arquivos binários do FB 2.5:** A pasta física `C:\Fortes\Firebird\Firebird_2_5` é mantida em disco (apenas o serviço do Windows é removido).
- **Configuração de conexão:** O arquivo `.ini` recebe um backup com sufixo `_BKP_yyyyMMdd_HHmmss` antes de qualquer alteração de linha.

### Como desfazer (Rollback de emergência):
Caso precise reverter para o Firebird 2.5 imediatamente:
1. Reinstale os serviços do FB 2.5 executando em um prompt de Administrador:
   ```cmd
   C:\Fortes\Firebird\Firebird_2_5\bin\instreg.exe install "C:\Fortes\Firebird\Firebird_2_5"
   C:\Fortes\Firebird\Firebird_2_5\bin\instsvc.exe install -auto -name Fortes_FB2_5
   C:\Fortes\Firebird\Firebird_2_5\bin\instsvc.exe start -name Fortes_FB2_5
   ```
2. Renomeie o arquivo `.fdb` migrado para outro nome e retorne o arquivo `_OLD_...` para o nome original (`AC.fdb`, etc.).
3. Restaure o arquivo `.ini` a partir do backup `_BKP_...`.

---

## 📌 Requisitos Mínimos do Sistema

- **Sistemas Operacionais Homologados:** Windows Server 2012 / 2012 R2 / 2016 / 2019 / 2022, Windows 10 e Windows 11 (64-bit).
- **Permissões:** Privilégios de Administrador local.
- **Dependências de Runtime:** Pacote `Microsoft Visual C++ 2015-2022 Redistributable (x64)` instalado na máquina host.