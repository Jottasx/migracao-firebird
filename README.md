# Utilitário de Migração Firebird 2.5 para 5.0 (Fortes Tecnologia) - Edição GUI

Solução automatizada desenvolvida em PowerShell com interface gráfica nativa em **Windows Forms** para a migração assistida e segura de bases de dados dos sistemas Fortes (**AC, Ponto, AG, Patrio, Cargas e Frota**) do Firebird 2.5 para o Firebird 5.0.

---

## 🚀 Principais Funcionalidades

* **Interface Gráfica Intuitiva:** Painel completo em Windows Forms para gestão da fila de migração, dispensando comandos manuais na consola.
* **Fila Dinâmica com Indicadores Visuais:** Adição e remoção de múltiplas bases na mesma sessão, com mudança de cor e estado por linha em tempo real:
  * ⚪ **Branco:** Na Fila / Aguardando;
  * 🟡 **Amarelo:** Em processamento (Extração de Backup / Restauro);
  * 🟢 **Verde / Negrito:** Concluído com sucesso;
  * 🔴 **Vermelho:** Erro na operação.
* **Monitor GBAK em Tempo Real:** Terminal dedicado que exibe o fluxo linha a linha do `gbak -v` (tabelas lidas, índices recriados e metadados) sem congelar a janela principal.
* **Manutenção da Porta Unificada (53052):** 
  * Os backups são extraídos via motor do FB 2.5 escutando na porta `53052`.
  * Os serviços do FB 2.5 são terminados e o FB 5.0 assume a porta `53052` (`firebird.conf`).
  * As bases são restauradas com tamanho de página otimizado (`-p 8192`) e ODS atualizada (ODS 13.x).
  * **Zero reconfiguração em terminais:** Os ficheiros de configuração (`.INI`) permanecem intactos.
* **Validação Prévia de ODS:** Inspeciona o cabeçalho físico da base `.fdb` (offset `0x12`) ao adicionar à lista, alertando o operador se a base já tiver sido migrada anteriormente para FB 5.0.
* **Regra de Firewall Automatizada:** Garante a abertura de tráfego de entrada para a porta TCP `53052` no Firewall do Windows (`netsh advfirewall`).
* **Proteção e Preservação de Dados:** Cada base original é preservada no mesmo diretório com sufixo carimbado (`<Sistema>.fdb_OLD_yyyyMMdd_HHmmss`).

---

## 📁 Estrutura de Pastas e Ficheiros

```text
Pasta_Migracao/
│
├── ExecutarMigracao.bat        # Iniciador com elevação UAC automática
├── Migrar-Firebird-GUI.ps1     # Aplicação principal (PowerShell + WinForms)
├── README.md                   # Documentação da ferramenta
└── Binarios/
    └── Firebird_5_0.zip        # Pacote com os binários do Firebird 5.0.3
```

> **Atenção:** Certifique-se de que o ficheiro `firebird.conf` dentro do pacote `Firebird_5_0.zip` está predefinido para escutar na porta `53052` (`RemoteServicePort = 53052`).

---

## ⚙️ Mapeamento de Ambientes e Serviços

| Parâmetro | Firebird 2.5 (Origem) | Firebird 5.0 (Destino) |
| :--- | :--- | :--- |
| **Porta de Rede TCP** | `53052` | `53052` *(Porta mantida)* |
| **Diretório no Servidor** | `C:\Fortes\Firebird\Firebird_2_5` | `C:\Fortes\Firebird\Firebird_5_0` |
| **Nome do Serviço** | `FirebirdServerFortes_FB2_5` | `FirebirdServerFortes_FB5_0` |
| **Page Size Padrão** | Original (ex.: 4096) | **8192 bytes** (`-p 8192`) |
| **Versão da ODS** | ODS 11.2 | ODS 13.1 |

---

## 🖥️ Mapeamento dos Sistemas Suportados

A aplicação identifica o módulo automaticamente pelo nome do ficheiro ou pela pasta de origem:

| Sistema | Ficheiro de Dados | Ficheiro .INI | Pasta Padrão Fortes |
| :--- | :--- | :--- | :--- |
| **AC** | `AC.fdb` | `AC.ini` *(inalterado)* | `C:\Fortes\AC` |
| **Ponto** | `Ponto.fdb` | `Ponto.ini` *(inalterado)* | `C:\Fortes\Ponto` |
| **AG** | `AG.fdb` | `AG.ini` *(inalterado)* | `C:\Fortes\AG` |
| **Patrio** | `Patrio.fdb` | `Patrio.ini` *(inalterado)* | `C:\Fortes\Patrio` |
| **Cargas** | `Cargas.fdb` | `Cargas.ini` *(inalterado)* | `C:\Fortes\Cargas` |
| **Frota** | `Frota.fdb` | `Frota.ini` *(inalterado)* | `C:\Fortes\Frota` |

---

## 📋 Pré-requisitos do Servidor

1. **Sistema Operativo:** Windows Server 2012 R2 ou superior / Windows 10 ou 11 (64-bit).
2. **Ambiente de Execução:** Pacote `Visual C++ 2015-2022 Redistributable (x64)` instalado.
3. **Privilégios:** Acesso de Administrador local da máquina.
4. **Espaço em Disco:** Mínimo de 2,1x o tamanho da base de dados na partição em que os ficheiros estão localizados.

---

## 🛠️ Passo a Passo Operacional

1. Certifique-se de que todos os colaboradores fecharam os sistemas Fortes nas estações e no servidor.
2. Extraia o pacote de migração numa diretoria local do servidor (ex.: `C:\MigradorFortes`).
3. Execute o ficheiro **`ExecutarMigracao.bat`** (aceite o aviso de privilégios de Administrador).
4. Na interface gráfica:
   * Clique em **`Adicionar...`** e selecione o ficheiro `.fdb` do primeiro sistema.
   * Repita a seleção para os restantes sistemas que residem no servidor (ex.: AC, Ponto, Frota).
   * Caso adicione alguma base por engano, selecione a linha e clique em **`Remover`**.
5. Clique no botão verde **`INICIAR`** e confirme a mensagem de arranque.
6. Acompanhe a execução:
   * A coluna **Status** indicará o progresso de cada banco individualmente.
   * O painel **Acompanhamento do GBAK** apresentará o fluxo contínuo das tabelas e índices processados.
   * O painel **Log Geral** indicará o registo do serviço, regras de firewall e transições de pastas.
7. Quando surgir a mensagem de confirmação de conclusão com sucesso, as bases estarão prontas a ser utilizadas diretamente pelos terminais.

---

## 🔄 Procedimento de Contingência (Rollback)

Se for necessário desfazer a operação por qualquer anomalia antes da validação final:

1. **Restaurar as Bases de Dados Originais:**
   Aceda à pasta onde reside a base e elimine a base migrada recente. Localize o ficheiro de salvaguarda `<Sistema>.fdb_OLD_yyyyMMdd_HHmmss` e retire o sufixo, restabelecendo o nome original (ex.: `AC.fdb`).
2. **Reativar o Serviço do Firebird 2.5 na Porta 53052:**
   Abra uma Linha de Comandos (como Administrador) e execute:
   ```cmd
   net stop FirebirdServerFortes_FB5_0
   sc config FirebirdServerFortes_FB5_0 start= demand
   "C:\Fortes\Firebird\Firebird_2_5\bin\instreg.exe" install "C:\Fortes\Firebird\Firebird_2_5"
   "C:\Fortes\Firebird\Firebird_2_5\bin\instsvc.exe" install -auto -name Fortes_FB2_5
   "C:\Fortes\Firebird\Firebird_2_5\bin\instsvc.exe" start -name Fortes_FB2_5
   ```