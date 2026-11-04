<#
.SYNOPSIS
    Migrador Firebird 2.5 para 5.0 (Fortes Tecnologia) - Multi-Sistemas
    Sistemas suportados: AC, Ponto, AG, Patrio, Cargas e Frota.
    Fluxo: Loop de migracao de multiplos bancos com desinstalacao do FB 2.5
           apenas apos confirmacao de que todos os sistemas foram concluidos.
#>

# Forca o console a operar em UTF-8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ==========================================
# 1. PARAMETROS E CAMINHOS GERAIS
# ==========================================
$PastaDestinoFB50     = "C:\Fortes\Firebird\Firebird_5_0"
$ZipOrigemFB50        = Join-Path $ScriptDir "Binarios\Firebird_5_0.zip"

$CaminhoFB25_Gbak     = "C:\Fortes\Firebird\Firebird_2_5\bin\gbak.exe"

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

# Lista para registrar os bancos migrados com sucesso na sessao
$BancosMigradosComSucesso = [System.Collections.Generic.List[string]]::new()

# ==========================================
# 2. ETAPA 1: DEPLOY E SERVICO DO FIREBIRD 5.0
# ==========================================
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ETAPA 1: Verificacao do Firebird 5.0" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $CaminhoFB25_Gbak)) {
    Write-Error "O Firebird 2.5 nao foi encontrado em: $CaminhoFB25_Gbak"
    exit 1
}

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

if (Test-Path $CaminhoFB50_InstReg) {
    & $CaminhoFB50_InstReg install "$PastaDestinoFB50" 2>$null | Out-Null
}

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

Write-Host "[OK] Firebird 5.0 ativo e operacional na porta $PortaFB50." -ForegroundColor Green

# Liberacao da porta no Firewall
Write-Host "Configurando regra de entrada no Firewall do Windows..." -ForegroundColor Yellow
$NomeRegra = "Firebird 5.0 - Fortes (Porta $PortaFB50)"
netsh advfirewall firewall delete rule name="$NomeRegra" >$null 2>&1
netsh advfirewall firewall add rule name="$NomeRegra" dir=in action=allow protocol=TCP localport=$PortaFB50 profile=any >$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Porta $PortaFB50 liberada no Firewall do Windows." -ForegroundColor Green
} else {
    Write-Host "[AVISO] Nao foi possivel configurar o Firewall automaticamente." -ForegroundColor Yellow
}

# ==========================================
# 3. LOOP DE MIGRACAO DE SISTEMAS
# ==========================================
Add-Type -AssemblyName System.Windows.Forms

$ContinuarMigrandoOutro = $true
$ContadorSistemas = 0

while ($ContinuarMigrandoOutro) {
    $ContadorSistemas++

    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "SELECAO DO SISTEMA / BANCO (MIGRACAO #$ContadorSistemas)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Selecione a base Firebird (.FDB) do sistema para migrar"
    $OpenFileDialog.InitialDirectory = "C:\Fortes"
    $OpenFileDialog.Filter = "Banco Firebird (*.fdb)|*.fdb|Todos os Arquivos (*.*)|*.*"

    if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Selecao cancelada pelo operador." -ForegroundColor Yellow
        if ($BancosMigradosComSucesso.Count -gt 0) {
            # Se já migrou pelo menos um banco antes, apenas encerra o loop para seguir para a limpeza
            break
        } else {
            exit 0
        }
    }

    $BancoOrigem = $OpenFileDialog.FileName
    $DiretorioDados = [System.IO.Path]::GetDirectoryName($BancoOrigem)
    $NomeArquivoOrigem = [System.IO.Path]::GetFileNameWithoutExtension($BancoOrigem)
    $CaminhoCompletoMinusculo = $BancoOrigem.ToLower()

    # Identificacao do sistema correspondente
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
    $PularEstaBase = $false

    try {
        $Stream = [System.IO.File]::OpenRead($BancoOrigem)
        $Buffer = New-Object byte[] 32
        $Stream.Read($Buffer, 0, 32) | Out-Null
        $Stream.Close()

        $ODS_Major = [int]$Buffer[18]
        $ODS_Minor = [int]$Buffer[20]

        Write-Host "ODS detectada no cabecalho: $ODS_Major.$ODS_Minor" -ForegroundColor DarkGray

        if ($ODS_Major -ge 13) {
            Write-Host "`n[AVISO] Esta base de dados JA ESTA MIGRADA para o Firebird 5.0 (ODS $ODS_Major.$ODS_Minor)!" -ForegroundColor Green
            $Forcar = Read-Host "Deseja forcar a migracao deste banco novamente (S/N)?"
            if ($Forcar -notmatch "^[sS]") {
                Write-Host "Pulando base $SistemaDetectado..." -ForegroundColor Yellow
                $PularEstaBase = $true
            }
        } elseif ($ODS_Major -eq 11) {
            Write-Host "[OK] Base identificada no formato Firebird 2.5 (ODS 11.x)." -ForegroundColor Green
        }
    } catch {
        Write-Host "Nao foi possivel ler os bytes de cabecalho, prosseguindo com a migracao..." -ForegroundColor DarkGray
    }

    if ($PularEstaBase) {
        $PerguntaContinuar = Read-Host "`nDeseja migrar OUTRO sistema/banco agora (S/N)?"
        $ContinuarMigrandoOutro = ($PerguntaContinuar -match "^[sS]")
        continue
    }

    # --- VALIDACAO DE ESPACO EM DISCO (2.1x) ---
    $TamanhoBancoBytes = (Get-Item $BancoOrigem).Length
    $EspacoNecessarioBytes = [math]::Round($TamanhoBancoBytes * 2.1)

    $TamanhoBancoGB     = [math]::Round($TamanhoBancoBytes / 1GB, 2)
    $EspacoNecessarioGB = [math]::Round($EspacoNecessarioBytes / 1GB, 2)

    $LetraUnidade = [System.IO.Path]::GetPathRoot($BancoOrigem).Replace("\", "")
    $UnidadeDisco = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $LetraUnidade }

    if ($UnidadeDisco) {
        $EspacoLivreBytes = $UnidadeDisco.FreeSpace
        $EspacoLivreGB    = [math]::Round($EspacoLivreBytes / 1GB, 2)

        Write-Host "`n--- Validacao de Disco ($LetraUnidade) ---" -ForegroundColor Cyan
        Write-Host "Tamanho do Banco Atual:   $TamanhoBancoGB GB"
        Write-Host "Espaco Minimo Solicitado: $EspacoNecessarioGB GB (2.1x)"
        Write-Host "Espaco Livre Disponivel:  $EspacoLivreGB GB"

        if ($EspacoLivreBytes -lt $EspacoNecessarioBytes) {
            Write-Host "`n[ERRO CRITICO] Espaco insuficiente no disco $LetraUnidade!" -ForegroundColor Red
            Write-Host "Sao necessarios pelo menos $EspacoNecessarioGB GB livres." -ForegroundColor Red
            
            $PerguntaContinuar = Read-Host "`nDeseja tentar outro sistema em outra unidade (S/N)?"
            $ContinuarMigrandoOutro = ($PerguntaContinuar -match "^[sS]")
            continue
        } else {
            Write-Host "[OK] Espaco em disco suficiente." -ForegroundColor Green
        }
    }

    # --- BACKUP VIA FIREBIRD 2.5 ---
    Write-Host "`n--- Iniciando Backup (FB 2.5) ---" -ForegroundColor Cyan
    $PularBackup = $false

    if (Test-Path $ArquivoBackupTemp) {
        $TamanhoMB = [math]::Round(((Get-Item $ArquivoBackupTemp).Length / 1MB), 2)
        $DataBkp   = (Get-Item $ArquivoBackupTemp).LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
        
        Write-Host "[CHECKPOINT] Arquivo de backup anterior localizado: $ArquivoBackupTemp ($TamanhoMB MB - $DataBkp)" -ForegroundColor Yellow
        $Escolha = Read-Host "Deseja APROVEITAR este backup existente (S/N)?"
        if ($Escolha -match "^[sS]") {
            $PularBackup = $true
        } else {
            Remove-Item $ArquivoBackupTemp -Force
        }
    }

    if (-not $PularBackup) {
        # Reinicia o FB 2.5 para fechar sessoes orfas nesta base
        if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) {
            Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
        }
        if (Get-Service -Name $ServicoFB25_Server -ErrorAction SilentlyContinue) {
            Restart-Service -Name $ServicoFB25_Server -Force
        }
        if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) {
            Start-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue
        }

        $ConexaoFB25 = "localhost/${PortaFB25}:${BancoOrigem}"
        Write-Host "Extraindo base via gbak do Firebird 2.5..." -ForegroundColor Yellow
        & $CaminhoFB25_Gbak -b -v -g "$ConexaoFB25" "$ArquivoBackupTemp" -user $UsuarioFB -password $SenhaFB

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ArquivoBackupTemp)) {
            Write-Error "Falha ao gerar backup no Firebird 2.5 para a base $BancoOrigem."
            continue
        }
        Write-Host "[OK] Backup gerado com sucesso." -ForegroundColor Green
    }

    # --- RESTORE NO FIREBIRD 5.0 ---
    Write-Host "`n--- Restaurando Base no Firebird 5.0 ---" -ForegroundColor Cyan
    if (Test-Path $ArquivoBancoNovo) {
        Remove-Item $ArquivoBancoNovo -Force
    }

    $ConexaoFB50 = "localhost/${PortaFB50}:${ArquivoBancoNovo}"
    Write-Host "Restaurando base no formato FB 5.0 (Porta $PortaFB50)..." -ForegroundColor Yellow
    & $CaminhoFB50_Gbak -c -v "$ArquivoBackupTemp" "$ConexaoFB50" -user $UsuarioFB -password $SenhaFB

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ArquivoBancoNovo)) {
        Write-Error "Falha ao restaurar banco no Firebird 5.0."
        continue
    }
    Write-Host "[OK] Restauracao concluida com exito." -ForegroundColor Green

    # Limpeza do temporario de backup
    if (Test-Path $ArquivoBackupTemp) {
        Remove-Item $ArquivoBackupTemp -Force
    }

    # Renomeia banco legado caso exista o arquivo de destino padrao
    if (Test-Path $ArquivoBancoFinal) {
        $DataHora = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupAntigo = "${ArquivoBancoFinal}_OLD_${DataHora}"
        Write-Host "Preservando base anterior em: $BackupAntigo" -ForegroundColor Yellow
        Rename-Item -Path $ArquivoBancoFinal -NewName (Split-Path $BackupAntigo -Leaf) -Force
    }

    Move-Item -Path $ArquivoBancoNovo -Destination $ArquivoBancoFinal -Force
    Write-Host "[OK] Base oficial do sistema pronta em: $ArquivoBancoFinal" -ForegroundColor Green

    # --- ATUALIZACAO DO ARQUIVO .INI ---
    Write-Host "`n--- Atualizando arquivo de configuracao (.INI) ---" -ForegroundColor Cyan
    $CaminhoIni = Join-Path $DiretorioDados $NomeArquivoIni
    if (-not (Test-Path $CaminhoIni)) {
        $CaminhoIni = Join-Path $PastaPadraoFortes $NomeArquivoIni
    }

    if (Test-Path $CaminhoIni) {
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupIni = "${CaminhoIni}_BKP_${Timestamp}"
        Copy-Item -Path $CaminhoIni -Destination $BackupIni -Force
        Write-Host "Backup do .ini salvo em: $BackupIni"

        $ConteudoIni = Get-Content -Path $CaminhoIni -Raw -Encoding Default
        $NovoConteudoIni = $ConteudoIni.Replace('/53052:', '/53055:').Replace(':53052:', ':53055:').Replace('$153055:', '/53055:')

        [System.IO.File]::WriteAllText($CaminhoIni, $NovoConteudoIni, [System.Text.Encoding]::Default)
        Write-Host "[OK] Portas atualizadas para 53055 no arquivo $NomeArquivoIni!" -ForegroundColor Green
    } else {
        Write-Host "[AVISO] Arquivo $NomeArquivoIni nao foi encontrado. Atualize as portas manualmente se necessario." -ForegroundColor Yellow
    }

    $BancosMigradosComSucesso.Add("$SistemaDetectado ($ArquivoBancoFinal)")
    Write-Host "`n>>> Sistema $SistemaDetectado MIGRADO COM SUCESSO! <<<" -ForegroundColor Green

    # Pergunta antes de seguir
    $PerguntaOutro = Read-Host "`nDeseja migrar OUTRO sistema da Fortes agora (ex: Ponto, Patrio, AG, etc) (S/N)?"
    $ContinuarMigrandoOutro = ($PerguntaOutro -match "^[sS]")
}

# ==========================================
# 4. FINALIZACAO E DESATIVACAO DO FB 2.5
# ==========================================
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "FINALIZACAO: Remocao dos Servicos Antigos" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($BancosMigradosComSucesso.Count -gt 0) {
    Write-Host "Todos os sistemas selecionados foram migrados com sucesso." -ForegroundColor Green
    
    $ConfirmarDesativacao = Read-Host "`nTem certeza de que TODOS os sistemas Fortes deste servidor ja estao no FB 5.0 e deseja DESATIVAR o Firebird 2.5 (S/N)?"
    if ($ConfirmarDesativacao -match "^[sS]") {
        Write-Host "Desativando servicos do Firebird 2.5..." -ForegroundColor Yellow
        Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
        Stop-Service -Name $ServicoFB25_Server -Force -ErrorAction SilentlyContinue

        sc.exe delete $ServicoFB25_Guardian | Out-Null
        sc.exe delete $ServicoFB25_Server | Out-Null
        Write-Host "[OK] Servicos do Firebird 2.5 desativados e removidos com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "[AVISO] Os servicos do Firebird 2.5 NAO foram removidos e continuam operacionais para os demais sistemas legados." -ForegroundColor Yellow
    }
} else {
    Write-Host "Nenhum banco foi migrado nesta execucao. Os servicos do FB 2.5 foram mantidos intactos." -ForegroundColor Yellow
}

# ==========================================
# 5. RESUMO FINAL DA OPERACAO
# ==========================================
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "           RELATORIO FINAL DE MIGRACAO                  " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
if ($BancosMigradosComSucesso.Count -gt 0) {
    Write-Host "Bancos migrados para o Firebird 5.0 (Porta 53055):" -ForegroundColor Cyan
    foreach ($item in $BancosMigradosComSucesso) {
        Write-Host " - $item" -ForegroundColor Green
    }
} else {
    Write-Host "Nenhuma base foi processada." -ForegroundColor Yellow
}
Write-Host "========================================================" -ForegroundColor Green