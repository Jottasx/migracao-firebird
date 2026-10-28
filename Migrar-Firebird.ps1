<#
.SYNOPSIS
    Migrador Firebird 2.5 para 5.0 (Fortes Tecnologia)
    Sistemas suportados: AC, Ponto, AG, Patrio, Cargas e Frota.
    Funcionalidades: Detecao de ODS, Deploy FB 5.0, Validacao de Espaco (2.1x), 
                     Checkpoint e Atualizacao de .INI.
#>

# Forca a consola a utilizar UTF-8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ==========================================
# 1. PARAMETROS E CAMINHOS
# ==========================================
$PastaDestinoFB50     = "C:\Fortes\Firebird\Firebird_5_0"
$ZipOrigemFB50        = Join-Path $ScriptDir "Binarios\Firebird_5_0.zip"

$CaminhoFB25_Gbak     = "C:\Fortes\Firebird\Firebird_2_5\bin\gbak.exe"

# Executaveis localizados na raiz do Firebird 5.0
$CaminhoFB50_Gbak     = Join-Path $PastaDestinoFB50 "gbak.exe"
$CaminhoFB50_InstSvc  = Join-Path $PastaDestinoFB50 "instsvc.exe"
$CaminhoFB50_InstReg  = Join-Path $PastaDestinoFB50 "instreg.exe"

$PortaFB25 = "53052"
$PortaFB50 = "53055"

$UsuarioFB = "SYSDBA"
$SenhaFB   = "masterkey"

$ServicoFB25_Server   = "FirebirdServerFortes_FB2_5"
$ServicoFB25_Guardian = "FirebirdGuardianFortes_FB2_5"

$NomeInstanciaFB50    = "Fortes_FB5_0"
$ServicoFB50_Server   = "FirebirdServer$NomeInstanciaFB50"

# ==========================================
# 2. ETAPA 1: VERIFICACAO / INSTALACAO DO FB 5.0
# ==========================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 1: Verificacao do Firebird 5.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Valida se o Firebird 2.5 original esta na maquina
if (-not (Test-Path $CaminhoFB25_Gbak)) {
    Write-Error "O Firebird 2.5 nao foi encontrado em: $CaminhoFB25_Gbak"
    exit 1
}

# Se o gbak do 5.0 nao existir, extrai o ZIP dos binarios
if (-not (Test-Path $CaminhoFB50_Gbak)) {
    if (-not (Test-Path $ZipOrigemFB50)) {
        Write-Error "Arquivo ZIP de instalacao nao encontrado em: $ZipOrigemFB50"
        exit 1
    }

    Write-Host "Extraindo arquivos do Firebird 5.0 em $PastaDestinoFB50..." -ForegroundColor Yellow
    if (-not (Test-Path $PastaDestinoFB50)) {
        New-Item -ItemType Directory -Path $PastaDestinoFB50 -Force | Out-Null
    }

    Expand-Archive -Path $ZipOrigemFB50 -DestinationPath $PastaDestinoFB50 -Force
    Write-Host "Arquivos descompactados com sucesso!" -ForegroundColor Green
}

# Garante a chave de registo do Firebird no Windows
if (Test-Path $CaminhoFB50_InstReg) {
    & $CaminhoFB50_InstReg install "$PastaDestinoFB50" 2>$null | Out-Null
}

# Garante a criacao e arranque do servico do FB 5.0
$ServicoFB50 = Get-Service -Name $ServicoFB50_Server -ErrorAction SilentlyContinue

if (-not $ServicoFB50) {
    Write-Host "Registrando servico do Firebird 5.0 ($ServicoFB50_Server)..." -ForegroundColor Yellow
    if (Test-Path $CaminhoFB50_InstSvc) {
        & $CaminhoFB50_InstSvc install -auto -name $NomeInstanciaFB50
        Start-Sleep -Seconds 2
        $ServicoFB50 = Get-Service -Name $ServicoFB50_Server -ErrorAction SilentlyContinue
    } else {
        Write-Error "instsvc.exe nao encontrado para registrar o servico."
        exit 1
    }
}

if ($ServicoFB50.Status -ne "Running") {
    Write-Host "Iniciando servico $ServicoFB50_Server..." -ForegroundColor Yellow
    Start-Service -Name $ServicoFB50_Server
    Start-Sleep -Seconds 3
}

Write-Host "[OK] Firebird 5.0 ativo e pronto para receber conexoes." -ForegroundColor Green

# ==========================================
# 3. ETAPA 2: IDENTIFICACAO DO SISTEMA E BANCO
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 2: Selecao da Base de Dados" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Add-Type -AssemblyName System.Windows.Forms
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.Title = "Selecione a base Firebird (.FDB)"
$OpenFileDialog.InitialDirectory = "C:\Fortes"
$OpenFileDialog.Filter = "Banco Firebird (*.fdb)|*.fdb|Todos os Arquivos (*.*)|*.*"

if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operacao cancelada pelo operador." -ForegroundColor Yellow
    exit 0
}

$BancoOrigem = $OpenFileDialog.FileName
$DiretorioDados = [System.IO.Path]::GetDirectoryName($BancoOrigem)
$NomeArquivoOrigem = [System.IO.Path]::GetFileNameWithoutExtension($BancoOrigem)
$CaminhoCompletoMinusculo = $BancoOrigem.ToLower()

# Identificacao do sistema (AC, Ponto, AG, Patrio, Cargas ou Frota)
if ($NomeArquivoOrigem -like "*Ponto*" -or $CaminhoCompletoMinusculo -match "\\ponto\\") {
    $SistemaDetectado = "Ponto"
} elseif ($NomeArquivoOrigem -like "*Patrio*" -or $CaminhoCompletoMinusculo -match "\\patrio\\") {
    $SistemaDetectado = "Patrio"
} elseif ($NomeArquivoOrigem -like "*Cargas*" -or $CaminhoCompletoMinusculo -match "\\cargas\\") {
    $SistemaDetectado = "Cargas"
} elseif ($NomeArquivoOrigem -like "*Frota*" -or $CaminhoCompletoMinusculo -match "\\frota\\") {
    $SistemaDetectado = "Frota"
} elseif ($NomeArquivoOrigem -match "(^|_)AG($|_)" -or $CaminhoCompletoMinusculo -match "\\ag\\") {
    $SistemaDetectado = "AG"
} else {
    $SistemaDetectado = "AC"
}

$NomeFinalBanco    = "$SistemaDetectado.fdb"
$NomeArquivoIni    = "$SistemaDetectado.ini"
$PastaPadraoFortes = "C:\Fortes\$SistemaDetectado"

$ArquivoBackupTemp = Join-Path $DiretorioDados "temp_migracao.fbk"
$ArquivoBancoNovo  = Join-Path $DiretorioDados "temp_fb50.fdb"
$ArquivoBancoFinal = Join-Path $DiretorioDados $NomeFinalBanco

Write-Host "Sistema Detectado: $SistemaDetectado" -ForegroundColor Green
Write-Host "Banco Origem:      $BancoOrigem"
Write-Host "Destino Final:     $ArquivoBancoFinal" -ForegroundColor Yellow

# --- VERIFICACAO DA ODS DO BANCO (CABECALHO) ---
Write-Host "`n--- Verificando versao interna da base (ODS) ---" -ForegroundColor Cyan
try {
    $Stream = [System.IO.File]::OpenRead($BancoOrigem)
    $Buffer = New-Object byte[] 32
    $Stream.Read($Buffer, 0, 32) | Out-Null
    $Stream.Close()

    # No cabecalho do Firebird (header page), o offset 18 guarda a versao major da ODS
    $ODS_Major = [int]$Buffer[18]
    $ODS_Minor = [int]$Buffer[20]

    Write-Host "ODS detectada no cabecalho: $ODS_Major.$ODS_Minor" -ForegroundColor DarkGray

    if ($ODS_Major -ge 13) {
        Write-Host "`n[AVISO] Esta base de dados JA FOI MIGRADA para o Firebird 5.0 (ODS $ODS_Major.$ODS_Minor)!" -ForegroundColor Green
        Write-Host "Nao e necessario executar a conversao novamente." -ForegroundColor Yellow
        
        $ContinuarMesmoAssim = Read-Host "`nDeseja forcar o processo de migracao mesmo assim (S/N)?"
        if ($ContinuarMesmoAssim -notmatch "^[sS]") {
            Write-Host "Operacao cancelada. A base ja esta atualizada." -ForegroundColor Yellow
            exit 0
        }
    } elseif ($ODS_Major -eq 11) {
        Write-Host "[OK] Base identificada no formato Firebird 2.5 (ODS 11.x). Pronta para migracao!" -ForegroundColor Green
    } else {
        Write-Host "Versao de ODS identificada: $ODS_Major.$ODS_Minor. Prosseguindo..." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "Nao foi possivel inspecionar os bytes do cabecalho, prosseguindo com a validacao normal..." -ForegroundColor DarkGray
}

# --- VALIDACAO DE ESPACO EM DISCO (2.1x: DOBRO + 10%) ---
$TamanhoBancoBytes = (Get-Item $BancoOrigem).Length
$EspacoNecessarioBytes = [math]::Round($TamanhoBancoBytes * 2.1)

$TamanhoBancoGB       = [math]::Round($TamanhoBancoBytes / 1GB, 2)
$EspacoNecessarioGB   = [math]::Round($EspacoNecessarioBytes / 1GB, 2)

$LetraUnidade = [System.IO.Path]::GetPathRoot($BancoOrigem).Replace("\", "")
$UnidadeDisco = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $LetraUnidade }

if ($UnidadeDisco) {
    $EspacoLivreBytes = $UnidadeDisco.FreeSpace
    $EspacoLivreGB    = [math]::Round($EspacoLivreBytes / 1GB, 2)

    Write-Host "`n--- Verificacao de Espaco em Disco ($LetraUnidade) ---" -ForegroundColor Cyan
    Write-Host "Tamanho do Banco Atual:   $TamanhoBancoGB GB"
    Write-Host "Espaco Minimo Solicitado: $EspacoNecessarioGB GB (2.1x)"
    Write-Host "Espaco Livre Disponivel:  $EspacoLivreGB GB"

    if ($EspacoLivreBytes -lt $EspacoNecessarioBytes) {
        Write-Host "`n[ERRO CRITICO] Espaco insuficiente no disco $LetraUnidade!" -ForegroundColor Red
        Write-Host "Sao necessarios pelo menos $EspacoNecessarioGB GB livres para prosseguir sem riscos." -ForegroundColor Red
        Write-Host "Processo abortado." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "[OK] Espaco em disco validado com sucesso!" -ForegroundColor Green
    }
}

# ==========================================
# 4. ETAPA 3: BACKUP DOS DADOS (FB 2.5)
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 3: Backup dos Dados (FB 2.5)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$PularBackup = $false

# Checkpoint: reaproveita backup anterior se existir
if (Test-Path $ArquivoBackupTemp) {
    $TamanhoMB = [math]::Round(((Get-Item $ArquivoBackupTemp).Length / 1MB), 2)
    $DataBkp   = (Get-Item $ArquivoBackupTemp).LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
    
    Write-Host "[ATENCAO] Foi detectado um arquivo de backup anterior!" -ForegroundColor Yellow
    Write-Host "Arquivo: $ArquivoBackupTemp"
    Write-Host "Tamanho: $TamanhoMB MB | Gerado em: $DataBkp"
    
    $Escolha = Read-Host "`nDeseja CONTINUAR aproveitando este backup (S/N)?"
    if ($Escolha -match "^[sS]") {
        $PularBackup = $true
        Write-Host "Aproveitando backup existente. Pulando etapa de extracao..." -ForegroundColor Green
    } else {
        Write-Host "Excluindo backup anterior para gerar um novo..." -ForegroundColor Yellow
        Remove-Item $ArquivoBackupTemp -Force
    }
}

if (-not $PularBackup) {
    Write-Host "`nReiniciando Firebird 2.5 para fechar conexoes ativas..." -ForegroundColor Yellow
    if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) {
        Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
    }
    if (Get-Service -Name $ServicoFB25_Server -ErrorAction SilentlyContinue) {
        Restart-Service -Name $ServicoFB25_Server -Force
    }
    if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) {
        Start-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue
    }

    Write-Host "`nIniciando geracao do backup via FB 2.5 (Porta $PortaFB25)..." -ForegroundColor Cyan
    $ConexaoFB25 = "localhost/${PortaFB25}:${BancoOrigem}"
    
    & $CaminhoFB25_Gbak -b -v -g "$ConexaoFB25" "$ArquivoBackupTemp" -user $UsuarioFB -password $SenhaFB

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ArquivoBackupTemp)) {
        Write-Error "Falha ao gerar o backup no Firebird 2.5. Codigo: $LASTEXITCODE"
        exit 1
    }
    Write-Host "Backup concluido com sucesso!" -ForegroundColor Green
}

# ==========================================
# 5. ETAPA 4: RESTAURACAO NO FB 5.0
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 4: Restauracao da Base (FB 5.0)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (Test-Path $ArquivoBancoNovo) {
    Remove-Item $ArquivoBancoNovo -Force
}

$ConexaoFB50 = "localhost/${PortaFB50}:${ArquivoBancoNovo}"
Write-Host "Restaurando via Firebird 5.0 na Porta $PortaFB50..." -ForegroundColor Cyan

& $CaminhoFB50_Gbak -c -v "$ArquivoBackupTemp" "$ConexaoFB50" -user $UsuarioFB -password $SenhaFB

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ArquivoBancoNovo)) {
    Write-Error "Falha ao restaurar no Firebird 5.0. Codigo: $LASTEXITCODE"
    exit 1
}
Write-Host "Restauracao finalizada com exito!" -ForegroundColor Green

# ==========================================
# 6. ETAPA 5: LIMPEZA DOS SERVICOS 2.5
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 5: Desativacao dos Servicos Antigos" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
Stop-Service -Name $ServicoFB25_Server -Force -ErrorAction SilentlyContinue

sc.exe delete $ServicoFB25_Guardian | Out-Null
sc.exe delete $ServicoFB25_Server | Out-Null
Write-Host "Servicos do Firebird 2.5 removidos." -ForegroundColor Green

# ==========================================
# 7. ETAPA 6: RENOMEACAO E ORGANIZACAO FINAL
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 6: Finalizacao dos Arquivos" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Remove o ficheiro temporario de backup
if (Test-Path $ArquivoBackupTemp) {
    Remove-Item $ArquivoBackupTemp -Force
}

# Preserva a base anterior caso ja exista com o nome oficial
if (Test-Path $ArquivoBancoFinal) {
    $DataHora = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupAntigo = "${ArquivoBancoFinal}_OLD_${DataHora}"
    Write-Host "Guardando copia da base anterior em: $BackupAntigo" -ForegroundColor Yellow
    Rename-Item -Path $ArquivoBancoFinal -NewName (Split-Path $BackupAntigo -Leaf) -Force
}

Move-Item -Path $ArquivoBancoNovo -Destination $ArquivoBancoFinal -Force
Write-Host "Banco migrado pronto em: $ArquivoBancoFinal" -ForegroundColor Green

# ==========================================
# 8. ETAPA 7: ATUALIZACAO DO ARQUIVO .INI
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 7: Atualizacao das portas no .INI" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Procura o ficheiro de configuracao (.ini)
$CaminhoIni = Join-Path $DiretorioDados $NomeArquivoIni
if (-not (Test-Path $CaminhoIni)) {
    $CaminhoIni = Join-Path $PastaPadraoFortes $NomeArquivoIni
}

if (Test-Path $CaminhoIni) {
    Write-Host "Arquivo de configuracao localizado: $CaminhoIni" -ForegroundColor Yellow

    # Cria copia de seguranca do .ini
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupIni = "${CaminhoIni}_BKP_${Timestamp}"
    Copy-Item -Path $CaminhoIni -Destination $BackupIni -Force
    Write-Host "Backup do .ini salvo em: $BackupIni"

    # Substituicao direta das portas no ficheiro
    $ConteudoIni = Get-Content -Path $CaminhoIni -Raw -Encoding Default
    $NovoConteudoIni = $ConteudoIni.Replace('/53052:', '/53055:').Replace(':53052:', ':53055:').Replace('$153055:', '/53055:')

    [System.IO.File]::WriteAllText($CaminhoIni, $NovoConteudoIni, [System.Text.Encoding]::Default)
    Write-Host "Portas alteradas para 53055 com sucesso no $NomeArquivoIni!" -ForegroundColor Green
} else {
    Write-Host "[AVISO] Arquivo $NomeArquivoIni nao encontrado em $DiretorioDados nem em $PastaPadraoFortes." -ForegroundColor Yellow
    Write-Host "Caso necessario, atualize as portas manualmente no arquivo de configuracao." -ForegroundColor Yellow
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "MIGRACAO DO SISTEMA $SistemaDetectado CONCLUIDA COM SUCESSO!" -ForegroundColor Green
Write-Host "Base: $ArquivoBancoFinal" -ForegroundColor Green
Write-Host "Porta ativa no FB 5.0: $PortaFB50" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green