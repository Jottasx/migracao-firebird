# Utilitário de Migração Firebird 2.5 para 5.0 (Fortes Tecnologia) - Edição GUI

Solução automatizada desenvolvida em PowerShell com interface gráfica nativa em **Windows Forms** para a migração assistida, performática e segura de bases de dados dos sistemas Fortes (**AC, Ponto, AG, Patrio, Cargas e Frota**) do Firebird 2.5 para o Firebird 5.0.

---

## 🚀 Principais Funcionalidades

* **Interface Gráfica Intuitiva e Desacoplada:** Painel em Windows Forms com execução em background thread (`BeginInvoke`), garantindo responsividade contínua da janela durante toda a operação sem congelamentos (*Não Respondendo*).
* **Fila Dinâmica com Indicadores Visuais:** Gestão de múltiplas bases na mesma sessão com sinalização visual de estado por linha:
  * ⚪ **Branco:** Na Fila / Aguardando;
  * 🟡 **Amarelo:** Em processamento (Extração de Backup / Restauração);
  * 🟢 **Verde / Negrito:** Concluído com sucesso;
  * 🔴 **Vermelho:** Erro na operação.
* **Monitor GBAK em Tempo Real:** Terminal dedicado com buffer circular controlado que exibe o fluxo linha a linha do `gbak -v` (tabelas lidas, contagem de registros, restauração de índices e metadados).
* **Sistema de Auditoria e Log Centralizado (`.txt`):**
  * Geração automática de arquivo único de log com carimbo de execução em `C:\Fortes\Logs\Migracao_FB25_FB50_yyyyMMdd_HHmmss.txt`.
  * **Persistência total do GBAK:** Grava 100% dos metadados e saídas de tabelas no arquivo de texto para resguardo técnico e auditoria contra corrupções pré-existentes na base do cliente.
  * Botão de acesso rápido **`Ver Log (.txt)`** habilitado ao término da rotina para abertura direta no Bloco de Notas.
* **Desinstalação Segura e Resiliente de Serviços Legados:**
  * Remoção primária via utilitário nativo (`instsvc.exe stop/remove -name Fortes_FB2_5`).
  * Tratamento com tolerância a variações de maiúsculas/minúsculas e sufixos nos serviços `FirebirdServer` e `FirebirdGuardian`.
  * Exclusão limpa via API nativa WMI/CIM, evitando chamadas suspeitas a utilitários de terceiros ou falsos positivos em softwares antivírus/EDR.
* **Manutenção da Porta Unificada (53052):**
  * Backups extraídos diretamente pelo motor do FB 2.5 escutando na porta `53052`.
  * Serviços do FB 2.5 são encerrados/desregistrados e o FB 5.0 assume a mesma porta `53052` (`firebird.conf`).
  * Restauração com tamanho de página otimizado para o padrão moderno (`-p 8192`) e ODS atualizada (ODS 13.x).
  * **Zero reconfiguração em terminais:** Arquivos `.INI` e atalhos nas estações permanecem 100% inalterados.
* **Validação Preventiva de ODS:** Inspeciona os bytes de cabeçalho da base `.fdb` (offset `0x12`) ao adicionar o banco à fila, alertando o operador caso a base já tenha sido migrada previamente para Firebird 5.0.
* **Regra de Firewall Automatizada:** Criação/validação automática de regra de entrada para tráfego TCP na porta `53052` no Firewall do Windows (`netsh advfirewall`).
* **Preservação Padronizada da Base Legada:** A base original do FB 2.5 é renomeada e mantida como salvaguarda na própria pasta do sistema seguindo o padrão oficial:
  * Exemplo: `Backup_AC_25_05_2026_FB_2_5.fdb` (com tratamento de sufixo com hora para execuções múltiplas no mesmo dia).

---

## 📁 Estrutura de Pastas e Arquivos

```text
Pasta_Migracao/
│
├── ExecutarMigracao.bat        # Iniciador com elevação UAC automática
├── Migrar-Firebird.ps1         # Script principal (PowerShell + WinForms)
├── README.md                   # Documentação da ferramenta
└── Binarios/
    └── Firebird_5_0.zip        # Pacote com os binários portáteis do Firebird 5.0
```

> **Atenção:** Certifique-se de que o arquivo `firebird.conf` contido dentro do arquivo `Firebird_5_0.zip` está devidamente configurado com `RemoteServicePort = 53052`.

---

## ⚙️ Mapeamento de Ambientes e Serviços

| Parâmetro | Firebird 2.5 (Origem) | Firebird 5.0 (Destino) |
| :--- | :--- | :--- |
| **Porta de Rede TCP** | `53052` | `53052` *(Porta mantida)* |
| **Diretório no Servidor** | `C:\Fortes\Firebird\Firebird_2_5` | `C:\Fortes\Firebird\Firebird_5_0` |
| **Nome do Serviço** | `FirebirdServerFortes_FB2_5` *(e variações)* | `FirebirdServerFortes_FB5_0` |
| **Serviço Guardian** | `FirebirdGuardianFortes_FB2_5` | Descontinuado no FB 5.0 |
| **Page Size Padrão** | Original (ex.: 4096) | **8192 bytes** (`-p 8192`) |
| **Versão da ODS** | ODS 11.2 | ODS 13.x |

---

## 🖥️ Mapeamento dos Sistemas Suportados

A aplicação identifica automaticamente o módulo correspondente analisando a nomenclatura do arquivo ou a pasta onde a base reside:

| Sistema | Arquivo de Dados | Arquivo .INI | Pasta Padrão Fortes |
| :--- | :--- | :--- | :--- |
| **AC** | `AC.fdb` | `AC.ini` *(inalterado)* | `C:\Fortes\AC` |
| **Ponto** | `Ponto.fdb` | `Ponto.ini` *(inalterado)* | `C:\Fortes\Ponto` |
| **AG** | `AG.fdb` | `AG.ini` *(inalterado)* | `C:\Fortes\AG` |
| **Patrio** | `Patrio.fdb` | `Patrio.ini` *(inalterado)* | `C:\Fortes\Patrio` |
| **Cargas** | `Cargas.fdb` | `Cargas.ini` *(inalterado)* | `C:\Fortes\Cargas` |
| **Frota** | `Frota.fdb` | `Frota.ini` *(inalterado)* | `C:\Fortes\Frota` |

---

## 📋 Pré-requisitos do Servidor

1. **Sistema Operacional:** Windows Server 2012 R2 ou superior / Windows 10 ou 11 (64-bit).
2. **Dependência de Execução:** Pacote `Microsoft Visual C++ 2015-2022 Redistributable (x64)` instalado no servidor.
3. **Privilégios Administrativos:** Execução obrigatória com privilégios de Administrador local.
4. **Espaço Livre em Disco:** Pelo menos **2,5x** o tamanho somado das bases de dados selecionadas.

---

## 🛠️ Passo a Passo Operacional

1. Solicite o encerramento das aplicações Fortes em todos os terminais e no próprio servidor.
2. Extraia o conteúdo do utilitário em um diretório local do servidor (ex.: `C:\MigradorFortes`).
3. Execute o inicializador **`ExecutarMigracao.bat`** como Administrador.
4. Na tela inicial:
   * Clique em **`Adicionar...`** e selecione a base `.fdb` do primeiro sistema.
   * Repita a operação para os demais módulos a serem migrados na mesma intervenção (ex.: AC, Ponto, Frota).
   * Para descartar itens incorretos da lista, selecione a linha e clique em **`Remover`**.
5. Clique no botão **`INICIAR`** e confirme o diálogo de início.
6. Acompanhe as etapas pelo painel:
   * **Fila de Bancos:** Indica o status em tempo real por sistema.
   * **Acompanhamento do GBAK:** Exibe o processamento linha a linha das tabelas e índices.
   * **Log Geral de Operações:** Exibe a checagem de binários, paradas de serviço e eventos do sistema.
7. Ao término, a mensagem de sucesso será exibida na tela.
8. Clique no botão **`Ver Log (.txt)`** para revisar o arquivo completo de auditoria gerado em `C:\Fortes\Logs\`.

---

## 🔄 Procedimento de Contingência (Rollback)

Caso ocorra qualquer imprevisto e seja necessário restabelecer o ambiente anterior:

1. **Restaurar a Base Legada:**
   * Acesse o diretório da base (ex.: `C:\Fortes\AC`).
   * Remova ou renomeie a base recém-criada `AC.fdb`.
   * Localize o arquivo de salvaguarda gerado pela ferramenta (`Backup_AC_<Data>_FB_2_5.fdb`) e renomeie-o de volta para `AC.fdb`.

2. **Reativar o Serviço do Firebird 2.5:**
   Abra o Prompt de Comando (CMD) como Administrador e execute:
   ```cmd
   net stop FirebirdServerFortes_FB5_0
   sc config FirebirdServerFortes_FB5_0 start= demand
   "C:\Fortes\Firebird\Firebird_2_5\bin\instreg.exe" install "C:\Fortes\Firebird\Firebird_2_5"
   "C:\Fortes\Firebird\Firebird_2_5\bin\instsvc.exe" install -auto -name Fortes_FB2_5
   "C:\Fortes\Firebird\Firebird_2_5\bin\instsvc.exe" start -name Fortes_FB2_5
   ```