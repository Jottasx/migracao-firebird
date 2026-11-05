<#
.SYNOPSIS
    Migrador Firebird 2.5 para 5.0 (Fortes Tecnologia) - Porta Unificada 53052
    Sistemas suportados: AC, Ponto, AG, Patrio, Cargas e Frota.
    Fluxo:
      1. Deploy e registro do servico do FB 5.0 (configurado para a porta 53052 no firebird.conf).
      2. Loop de selecao de bases e geracao de backups via FB 2.5 (porta 53052).
      3. Parada definitiva do FB 2.5 para liberar a porta 53052.
      4. Subida do servico do FB 5.0 na porta 53052.
      5. Restauracao dos bancos via FB 5.0 diretamente na porta 53052.
      6. Arquivos .ini permanecem intactos, mantendo comunicacao ativa com os terminais.
#>

# Forca o console a utilizar UTF-8
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

$CaminhoFB50_Gbak     = Join-Path $PastaDestinoFB50 "gbak.exe"
$CaminhoFB50_InstSvc  = Join-Path $PastaDestinoFB50 "instsvc.exe"
$CaminhoFB50_InstReg  = Join-Path $PastaDestinoFB50 "instreg.exe"

# Porta unificada para manter compatibilidade com os terminais
$PortaPadrao = "53052"

$UsuarioFB = "SYSDBA"
$SenhaFB   = "masterkey"

$ServicoFB25_Server   = "FirebirdServerFortes_FB2_5"
$ServicoFB25_Guardian = "FirebirdGuardianFortes_FB2_5"

$NomeInstanciaFB50    = "Fortes_FB5_0"
$ServicoFB50_Server   = "FirebirdServer$NomeInstanciaFB50"

# Estrutura para armazenar a fila de migracao
$FilaDeBancos = [System.Collections.Generic.List[PSCustomObject]]::new()

# ==========================================
# 2. ETAPA 1: VERIFICACAO / PREPARACAO DO FB 5.0
# ==========================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 1: Preparacao do Firebird 5.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

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

# Garante a chave de registro do FB 5.0
if (Test-Path $CaminhoFB50_InstReg) {
    & $CaminhoFB50_InstReg install "$PastaDestinoFB50" 2>$null | Out-Null
}

# Registra o servico do FB 5.0 (sem iniciar ainda para nao colidir na porta 53052)
$ServicoFB50 = Get-Service -Name $ServicoFB50_Server -ErrorAction SilentlyContinue

if (-not $ServicoFB50) {
    Write-Host "Registrando servico do Firebird 5.0 ($ServicoFB50_Server)..." -ForegroundColor Yellow
    if (Test-Path $CaminhoFB50_InstSvc) {
        & $CaminhoFB50_InstSvc install -auto -name $NomeInstanciaFB50
        Start-Sleep -Seconds 2
    } else {
        Write-Error "instsvc.exe nao encontrado para registrar o servico."
        exit 1
    }
}

# Liberacao da porta no Firewall
Write-Host "Verificando regra de Firewall para a porta $PortaPadrao..." -ForegroundColor Yellow
$NomeRegra = "Firebird Fortes (Porta $PortaPadrao)"
netsh advfirewall firewall delete rule name="$NomeRegra" >$null 2>&1
netsh advfirewall firewall add rule name="$NomeRegra" dir=in action=allow protocol=TCP localport=$PortaPadrao profile=any >$null

Write-Host "[OK] Firewall validado para a porta $PortaPadrao." -ForegroundColor Green

# ==========================================
# 3. ETAPA 2: FILA DE BASES PARA MIGRAR
# ==========================================
Add-Type -AssemblyName System.Windows.Forms

$ColetandoBancos = $true
$Contador = 0

while ($ColetandoBancos) {
    $Contador++

    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "SELECAO DO SISTEMA / BANCO (BASE #$Contador)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Selecione o arquivo .FDB do sistema para migrar"
    $OpenFileDialog.InitialDirectory = "C:\Fortes"
    $OpenFileDialog.Filter = "Banco Firebird (*.fdb)|*.fdb|Todos os Arquivos (*.*)|*.*"

    if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Selecao finalizada/cancelada pelo operador." -ForegroundColor Yellow
        break
    }

    $BancoOrigem = $OpenFileDialog.FileName
    $DiretorioDados = [System.IO.Path]::GetDirectoryName($BancoOrigem)
    $NomeArquivoOrigem = [System.IO.Path]::GetFileNameWithoutExtension($BancoOrigem)
    $CaminhoMinusculo = $BancoOrigem.ToLower()

    # Deteccao de modulo
    if ($NomeArquivoOrigem -like "*Ponto*" -or $CaminhoMinusculo -match "\\ponto\\") {
        $Sistema = "Ponto"
    } elseif ($NomeArquivoOrigem -like "*Patrio*" -or $CaminhoMinusculo -match "\\patrio\\") {
        $Sistema = "Patrio"
    } elseif ($NomeArquivoOrigem -like "*Cargas*" -or $CaminhoMinusculo -match "\\cargas\\") {
        $Sistema = "Cargas"
    } elseif ($NomeArquivoOrigem -like "*Frota*" -or $CaminhoMinusculo -match "\\frota\\") {
        $Sistema = "Frota"
    } elseif ($NomeArquivoOrigem -match "(^|_)AG($|_)" -or $CaminhoMinusculo -match "\\ag\\") {
        $Sistema = "AG"
    } else {
        $Sistema = "AC"
    }

    $NomeFinalBanco    = "$Sistema.fdb"
    $ArquivoBackupTemp = Join-Path $DiretorioDados "temp_migracao_$Sistema.fbk"
    $ArquivoBancoNovo  = Join-Path $DiretorioDados "temp_fb50_$Sistema.fdb"
    $ArquivoBancoFinal = Join-Path $DiretorioDados $NomeFinalBanco

    Write-Host "Sistema Detectado: $Sistema" -ForegroundColor Green
    Write-Host "Caminho da Base:   $BancoOrigem"

    # Verificacao ODS
    try {
        $Stream = [System.IO.File]::OpenRead($BancoOrigem)
        $Buffer = New-Object byte[] 32
        $Stream.Read($Buffer, 0, 32) | Out-Null
        $Stream.Close()

        $ODS_Major = [int]$Buffer[18]
        $ODS_Minor = [int]$Buffer[20]

        if ($ODS_Major -ge 13) {
            Write-Host "`n[AVISO] Base ja migrada para o FB 5.0 (ODS $ODS_Major.$ODS_Minor)!" -ForegroundColor Green
            $Forcar = Read-Host "Deseja incluir essa base mesmo assim (S/N)?"
            if ($Forcar -notmatch "^[sS]") {
                $PerguntaOutro = Read-Host "`nDeseja selecionar OUTRO sistema (S/N)?"
                $ColetandoBancos = ($PerguntaOutro -match "^[sS]")
                continue
            }
        }
    } catch {
        Write-Host "Nao foi possivel inspecionar os bytes do cabecalho, prosseguindo..." -ForegroundColor DarkGray
    }

    # Validacao de espaco em disco (2.1x)
    $TamanhoBytes = (Get-Item $BancoOrigem).Length
    $EspacoNecessarioBytes = [math]::Round($TamanhoBytes * 2.1)
    $LetraUnidade = [System.IO.Path]::GetPathRoot($BancoOrigem).Replace("\", "")
    $UnidadeDisco = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $LetraUnidade }

    if ($UnidadeDisco -and ($UnidadeDisco.FreeSpace -lt $EspacoNecessarioBytes)) {
        Write-Host "[ERRO CRITICO] Espaco insuficiente no disco $LetraUnidade!" -ForegroundColor Red
        Write-Host "Necessarios: $([math]::Round($EspacoNecessarioBytes / 1GB, 2)) GB | Livres: $([math]::Round($UnidadeDisco.FreeSpace / 1GB, 2)) GB" -ForegroundColor Red
        $PerguntaOutro = Read-Host "`nDeseja tentar outro sistema (S/N)?"
        $ColetandoBancos = ($PerguntaOutro -match "^[sS]")
        continue
    }

    # Adiciona a fila de trabalho
    $FilaDeBancos.Add([PSCustomObject]@{
        Sistema           = $Sistema
        BancoOrigem       = $BancoOrigem
        ArquivoBackupTemp = $ArquivoBackupTemp
        ArquivoBancoNovo  = $ArquivoBancoNovo
        ArquivoBancoFinal = $ArquivoBancoFinal
    })

    Write-Host "[OK] Base adicionada a fila de migracao." -ForegroundColor Green

    $PerguntaOutro = Read-Host "`nDeseja adicionar MAIS UM sistema a fila (ex: Ponto, Patrio, AG, Frota) (S/N)?"
    $ColetandoBancos = ($PerguntaOutro -match "^[sS]")
}

if ($FilaDeBancos.Count -eq 0) {
    Write-Host "`nNenhuma base foi selecionada para migracao. Finalizando operacao..." -ForegroundColor Yellow
    exit 0
}

# ==========================================
# 4. ETAPA 3: GERAR BACKUPS (FB 2.5 - PORTA 53052)
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 3: Extraindo Backups via Firebird 2.5" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Garante que o servico 2.5 esta ativo para fazer a extracao
Write-Host "Reiniciando Firebird 2.5 para liberar conexoes presas..." -ForegroundColor Yellow
if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) {
    Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
}
if (Get-Service -Name $ServicoFB25_Server -ErrorAction SilentlyContinue) {
    Restart-Service -Name $ServicoFB25_Server -Force
}
if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) {
    Start-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue
}

foreach ($item in $FilaDeBancos) {
    Write-Host "`nExtraindo backup do sistema: $($item.Sistema)..." -ForegroundColor Yellow
    
    $PularBackup = $false
    if (Test-Path $item.ArquivoBackupTemp) {
        $TamanhoMB = [math]::Round(((Get-Item $item.ArquivoBackupTemp).Length / 1MB), 2)
        Write-Host "[CHECKPOINT] Backup encontrado: $($item.ArquivoBackupTemp) ($TamanhoMB MB)" -ForegroundColor Yellow
        $Escolha = Read-Host "Deseja APROVEITAR esse backup ja existente (S/N)?"
        if ($Escolha -match "^[sS]") {
            $PularBackup = $true
        } else {
            Remove-Item $item.ArquivoBackupTemp -Force
        }
    }

    if (-not $PularBackup) {
        $ConexaoFB25 = "localhost/${PortaPadrao}:$($item.BancoOrigem)"
        & $CaminhoFB25_Gbak -b -v -g "$ConexaoFB25" "$($item.ArquivoBackupTemp)" -user $UsuarioFB -password $SenhaFB

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $item.ArquivoBackupTemp)) {
            Write-Error "Falha ao extrair backup do sistema $($item.Sistema)."
            exit 1
        }
        Write-Host "[OK] Backup do $($item.Sistema) finalizado com sucesso." -ForegroundColor Green
    }
}

# ==========================================
# 5. ETAPA 4: VIRADA DE CHAVE DOS SERVICOS
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 4: Transicao de Motores na Porta $PortaPadrao" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "Parando e desinstalando servicos do Firebird 2.5..." -ForegroundColor Yellow
Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
Stop-Service -Name $ServicoFB25_Server -Force -ErrorAction SilentlyContinue

sc.exe delete $ServicoFB25_Guardian | Out-Null
sc.exe delete $ServicoFB25_Server | Out-Null
Start-Sleep -Seconds 2

Write-Host "Iniciando o Firebird 5.0 na porta unificada $PortaPadrao..." -ForegroundColor Yellow
Start-Service -Name $ServicoFB50_Server
Start-Sleep -Seconds 3

# Valida se subiu
$StatusFB50 = (Get-Service -Name $ServicoFB50_Server).Status
if ($StatusFB50 -ne "Running") {
    Write-Error "O Firebird 5.0 nao conseguiu iniciar. Verifique se o firebird.conf esta configurado com a porta $PortaPadrao."
    exit 1
}
Write-Host "[OK] Firebird 5.0 ativo e escutando na porta $PortaPadrao!" -ForegroundColor Green

# ==========================================
# 6. ETAPA 5: RESTAURAR BASES NO FB 5.0
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 5: Restaurando Bases no Firebird 5.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

foreach ($item in $FilaDeBancos) {
    Write-Host "`nRestaurando sistema: $($item.Sistema)..." -ForegroundColor Yellow

    if (Test-Path $item.ArquivoBancoNovo) {
        Remove-Item $item.ArquivoBancoNovo -Force
    }

    $ConexaoFB50 = "localhost/${PortaPadrao}:$($item.ArquivoBancoNovo)"
    & $CaminhoFB50_Gbak -c -v -p 8192 "$($item.ArquivoBackupTemp)" "$ConexaoFB50" -user $UsuarioFB -password $SenhaFB

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $item.ArquivoBancoNovo)) {
        Write-Error "Falha ao restaurar banco $($item.Sistema) no Firebird 5.0."
        exit 1
    }

    # Limpa arquivo temporario de backup
    if (Test-Path $item.ArquivoBackupTemp) {
        Remove-Item $item.ArquivoBackupTemp -Force
    }

    # Preserva o arquivo antigo caso exista
    if (Test-Path $item.ArquivoBancoFinal) {
        $DataHora = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupAntigo = "$($item.ArquivoBancoFinal)_OLD_${DataHora}"
        Write-Host "Guardando copia de seguranca em: $BackupAntigo" -ForegroundColor Yellow
        Rename-Item -Path $item.ArquivoBancoFinal -NewName (Split-Path $BackupAntigo -Leaf) -Force
    }

    Move-Item -Path $item.ArquivoBancoNovo -Destination $item.ArquivoBancoFinal -Force
    Write-Host "[OK] Base do $($item.Sistema) migrada com sucesso em: $($item.ArquivoBancoFinal)" -ForegroundColor Green
}

# ==========================================
# 7. RESUMO FINAL
# ==========================================
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "           MIGRACAO CONCLUIDA COM SUCESSO!              " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Porta unificada mantida: $PortaPadrao (Terminais nao necessitam alteracao)" -ForegroundColor Cyan
Write-Host "Arquivos de configuracao (.INI): Mantidos intactos sem necessidade de alteracao.`n" -ForegroundColor Cyan
Write-Host "Bancos migrados:" -ForegroundColor Yellow
foreach ($item in $FilaDeBancos) {
    Write-Host " - $($item.Sistema): $($item.ArquivoBancoFinal)" -ForegroundColor Green
}
Write-Host "========================================================" -ForegroundColor Green