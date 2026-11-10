<#
.SYNOPSIS
    Migrador Firebird 2.5 para 5.0 (Fortes Tecnologia) - UI Completa e Fluida
    Sistemas suportados: AC, Ponto, AG, Patrio, Cargas e Frota.
    Desenvolvido por: Pedro Mesquita (pedromesquita@fortestecnologia.com.br)
    Auxílio de IA: Arquitetura e rotinas auxiliadas por Google Gemini.
#>

[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- CONFIGURAÇÃO DA JANELA PRINCIPAL ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Migrador Firebird 2.5 -> 5.0 (Fortes Tecnologia)"
$Form.Size = New-Object System.Drawing.Size(820, 765)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false

$FontPadrao = New-Object System.Drawing.Font("Segoe UI", 9)
$FontTitulo = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$FontGbak   = New-Object System.Drawing.Font("Consolas", 8)
$Form.Font  = $FontPadrao

# 1. Seção: Fila de Bancos
$GrpBancos = New-Object System.Windows.Forms.GroupBox
$GrpBancos.Text = "Fila de Bancos Selecionados para Migração"
$GrpBancos.Location = New-Object System.Drawing.Point(15, 10)
$GrpBancos.Size = New-Object System.Drawing.Size(775, 160)
$Form.Controls.Add($GrpBancos)

$ListaBancos = New-Object System.Windows.Forms.ListView
$ListaBancos.Location = New-Object System.Drawing.Point(15, 22)
$ListaBancos.Size = New-Object System.Drawing.Size(620, 125)
$ListaBancos.View = [System.Windows.Forms.View]::Details
$ListaBancos.FullRowSelect = $true
$ListaBancos.GridLines = $true
$ListaBancos.Columns.Add("Sistema", 75) | Out-Null
$ListaBancos.Columns.Add("Status", 130) | Out-Null
$ListaBancos.Columns.Add("Caminho do Banco (.FDB)", 405) | Out-Null
$GrpBancos.Controls.Add($ListaBancos)

$BtnAdicionar = New-Object System.Windows.Forms.Button
$BtnAdicionar.Text = "Adicionar..."
$BtnAdicionar.Location = New-Object System.Drawing.Point(645, 22)
$BtnAdicionar.Size = New-Object System.Drawing.Size(115, 30)
$GrpBancos.Controls.Add($BtnAdicionar)

$BtnRemover = New-Object System.Windows.Forms.Button
$BtnRemover.Text = "Remover"
$BtnRemover.Location = New-Object System.Drawing.Point(645, 56)
$BtnRemover.Size = New-Object System.Drawing.Size(115, 30)
$GrpBancos.Controls.Add($BtnRemover)

$BtnIniciar = New-Object System.Windows.Forms.Button
$BtnIniciar.Text = "INICIAR"
$BtnIniciar.Location = New-Object System.Drawing.Point(645, 96)
$BtnIniciar.Size = New-Object System.Drawing.Size(115, 51)
$BtnIniciar.BackColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
$BtnIniciar.ForeColor = [System.Drawing.Color]::White
$BtnIniciar.Font = $FontTitulo
$BtnIniciar.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GrpBancos.Controls.Add($BtnIniciar)

# 2. Seção: Progresso e Etapa Atual
$GrpProgresso = New-Object System.Windows.Forms.GroupBox
$GrpProgresso.Text = "Status da Operação"
$GrpProgresso.Location = New-Object System.Drawing.Point(15, 175)
$GrpProgresso.Size = New-Object System.Drawing.Size(775, 80)
$Form.Controls.Add($GrpProgresso)

$LblStatus = New-Object System.Windows.Forms.Label
$LblStatus.Text = "Aguardando seleção de bases para iniciar..."
$LblStatus.Location = New-Object System.Drawing.Point(15, 20)
$LblStatus.Size = New-Object System.Drawing.Size(745, 20)
$LblStatus.Font = $FontTitulo
$GrpProgresso.Controls.Add($LblStatus)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(15, 45)
$ProgressBar.Size = New-Object System.Drawing.Size(745, 22)
$GrpProgresso.Controls.Add($ProgressBar)

# 3. Seção: Monitor em Tempo Real do GBAK (Tabelas / Índices)
$GrpGbak = New-Object System.Windows.Forms.GroupBox
$GrpGbak.Text = "Acompanhamento do GBAK em Tempo Real (Tabelas e Índices)"
$GrpGbak.Location = New-Object System.Drawing.Point(15, 260)
$GrpGbak.Size = New-Object System.Drawing.Size(775, 210)
$Form.Controls.Add($GrpGbak)

$TxtGbak = New-Object System.Windows.Forms.TextBox
$TxtGbak.Location = New-Object System.Drawing.Point(15, 22)
$TxtGbak.Size = New-Object System.Drawing.Size(745, 175)
$TxtGbak.Multiline = $true
$TxtGbak.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$TxtGbak.ReadOnly = $true
$TxtGbak.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 25)
$TxtGbak.ForeColor = [System.Drawing.Color]::Cyan
$TxtGbak.Font = $FontGbak
$GrpGbak.Controls.Add($TxtGbak)

# 4. Seção: Log Geral do Sistema
$GrpLogs = New-Object System.Windows.Forms.GroupBox
$GrpLogs.Text = "Log Geral de Operações"
$GrpLogs.Location = New-Object System.Drawing.Point(15, 475)
$GrpLogs.Size = New-Object System.Drawing.Size(775, 220)
$Form.Controls.Add($GrpLogs)

$TxtLogs = New-Object System.Windows.Forms.TextBox
$TxtLogs.Location = New-Object System.Drawing.Point(15, 22)
$TxtLogs.Size = New-Object System.Drawing.Size(745, 185)
$TxtLogs.Multiline = $true
$TxtLogs.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$TxtLogs.ReadOnly = $true
$TxtLogs.BackColor = [System.Drawing.Color]::Black
$TxtLogs.ForeColor = [System.Drawing.Color]::LightGray
$TxtLogs.Font = $FontGbak
$GrpLogs.Controls.Add($TxtLogs)

# 5. Rodapé: Créditos do Desenvolvedor
$LblCreditos = New-Object System.Windows.Forms.Label
$LblCreditos.Text = "Desenvolvido por Pedro Mesquita (pedromesquita@fortestecnologia.com.br)"
$LblCreditos.Location = New-Object System.Drawing.Point(15, 702)
$LblCreditos.Size = New-Object System.Drawing.Size(775, 18)
$LblCreditos.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$LblCreditos.ForeColor = [System.Drawing.Color]::Gray
$LblCreditos.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$Form.Controls.Add($LblCreditos)

# --- ESTRUTURA SINCRONIZADA ---
$SyncHash = [hashtable]::Synchronized(@{
    StatusText    = ""
    LogQueue      = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    GbakQueue     = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    ItemUpdates   = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    Progress      = 0
    MaxProgress   = 100
    Concluido     = $false
    Erro          = $null
})

# Timer regulado para 150ms com Flush em Bloco
$TimerAtualizacao = New-Object System.Windows.Forms.Timer
$TimerAtualizacao.Interval = 150
$TimerAtualizacao.Add_Tick({
    if ($SyncHash.StatusText) {
        $LblStatus.Text = $SyncHash.StatusText
    }

    $ProgressBar.Maximum = $SyncHash.MaxProgress
    $ProgressBar.Value   = [Math]::Min($SyncHash.Progress, $SyncHash.MaxProgress)

    # 1. Drena logs gerais em bloco único
    if ($SyncHash.LogQueue.Count -gt 0) {
        $logsParaEscrever = @()
        [System.Threading.Monitor]::Enter($SyncHash.LogQueue.SyncRoot)
        try {
            $logsParaEscrever = $SyncHash.LogQueue.ToArray()
            $SyncHash.LogQueue.Clear()
        } finally {
            [System.Threading.Monitor]::Exit($SyncHash.LogQueue.SyncRoot)
        }
        if ($logsParaEscrever.Count -gt 0) {
            $TxtLogs.AppendText([string]::Join("`r`n", $logsParaEscrever) + "`r`n")
        }
    }

    # 2. Drena saída do GBAK em bloco único e limita tamanho do buffer na tela
    if ($SyncHash.GbakQueue.Count -gt 0) {
        $gbakParaEscrever = @()
        [System.Threading.Monitor]::Enter($SyncHash.GbakQueue.SyncRoot)
        try {
            $gbakParaEscrever = $SyncHash.GbakQueue.ToArray()
            $SyncHash.GbakQueue.Clear()
        } finally {
            [System.Threading.Monitor]::Exit($SyncHash.GbakQueue.SyncRoot)
        }
        if ($gbakParaEscrever.Count -gt 0) {
            if ($TxtGbak.TextLength -gt 30000) {
                $TxtGbak.Text = $TxtGbak.Text.Substring($TxtGbak.TextLength - 15000)
            }
            $TxtGbak.AppendText([string]::Join("`r`n", $gbakParaEscrever) + "`r`n")
        }
    }

    # 3. Drena atualizações de status das linhas da tabela
    if ($SyncHash.ItemUpdates.Count -gt 0) {
        $updatesParaProcessar = @()
        [System.Threading.Monitor]::Enter($SyncHash.ItemUpdates.SyncRoot)
        try {
            $updatesParaProcessar = $SyncHash.ItemUpdates.ToArray()
            $SyncHash.ItemUpdates.Clear()
        } finally {
            [System.Threading.Monitor]::Exit($SyncHash.ItemUpdates.SyncRoot)
        }

        foreach ($up in $updatesParaProcessar) {
            $idx = $up.Index
            if ($idx -lt $ListaBancos.Items.Count) {
                $item = $ListaBancos.Items[$idx]
                $item.SubItems[1].Text = $up.Status
                
                switch ($up.Tipo) {
                    "Processando" {
                        $item.BackColor = [System.Drawing.Color]::FromArgb(255, 249, 196)
                        $item.ForeColor = [System.Drawing.Color]::FromArgb(100, 70, 0)
                    }
                    "Concluido" {
                        $item.BackColor = [System.Drawing.Color]::FromArgb(200, 230, 201)
                        $item.ForeColor = [System.Drawing.Color]::FromArgb(27, 94, 32)
                        $item.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
                    }
                    "Erro" {
                        $item.BackColor = [System.Drawing.Color]::FromArgb(255, 205, 210)
                        $item.ForeColor = [System.Drawing.Color]::FromArgb(183, 28, 28)
                    }
                }
            }
        }
    }

    [System.Windows.Forms.Application]::DoEvents()

    if ($SyncHash.Concluido) {
        $TimerAtualizacao.Stop()
        $BtnAdicionar.Enabled = $true
        $BtnRemover.Enabled   = $true
        $BtnIniciar.Enabled   = $true

        if ($SyncHash.Erro) {
            [System.Windows.Forms.MessageBox]::Show("A migração falhou:`n$($SyncHash.Erro)", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Processo de migração concluído com sucesso!", "Sucesso", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
})

# --- EVENTOS DOS BOTÕES ---
$BtnAdicionar.Add_Click({
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    $Dialog.Title = "Selecione a base Firebird (.FDB)"
    $Dialog.InitialDirectory = "C:\Fortes"
    $Dialog.Filter = "Banco Firebird (*.fdb)|*.fdb|Todos os Arquivos (*.*)|*.*"

    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $Caminho = $Dialog.FileName
        $Nome = [System.IO.Path]::GetFileNameWithoutExtension($Caminho)
        $Minusculo = $Caminho.ToLower()

        if ($Nome -like "*Ponto*" -or $Minusculo -match "\\ponto\\") {
            $Sistema = "Ponto"
        } elseif ($Nome -like "*Patrio*" -or $Minusculo -match "\\patrio\\") {
            $Sistema = "Patrio"
        } elseif ($Nome -like "*Cargas*" -or $Minusculo -match "\\cargas\\") {
            $Sistema = "Cargas"
        } elseif ($Nome -like "*Frota*" -or $Minusculo -match "\\frota\\") {
            $Sistema = "Frota"
        } elseif ($Nome -match "(^|_)AG($|_)" -or $Minusculo -match "\\ag\\") {
            $Sistema = "AG"
        } else {
            $Sistema = "AC"
        }

        # Validação preventiva de ODS
        try {
            $Stream = [System.IO.File]::OpenRead($Caminho)
            $Buf = New-Object byte[] 32
            $Stream.Read($Buf, 0, 32) | Out-Null
            $Stream.Close()
            if ([int]$Buf[18] -ge 13) {
                $Res = [System.Windows.Forms.MessageBox]::Show("A base de dados selecionada já está no formato do Firebird 5.0 (ODS $([int]$Buf[18])). Deseja incluí-la mesmo assim?", "Aviso", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                if ($Res -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            }
        } catch {}

        $Item = New-Object System.Windows.Forms.ListViewItem($Sistema)
        $Item.SubItems.Add("Aguardando...") | Out-Null
        $Item.SubItems.Add($Caminho) | Out-Null
        $ListaBancos.Items.Add($Item) | Out-Null
    }
})

$BtnRemover.Add_Click({
    foreach ($Item in $ListaBancos.SelectedItems) {
        $ListaBancos.Items.Remove($Item)
    }
})

$BtnIniciar.Add_Click({
    if ($ListaBancos.Items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Selecione pelo menos uma base na fila antes de iniciar.", "Atenção", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $Confirmar = [System.Windows.Forms.MessageBox]::Show("Deseja iniciar a migração de $($ListaBancos.Items.Count) base(s)?`nCertifique-se de que os sistemas estão fechados nos terminais.", "Confirmar Início", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($Confirmar -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $BtnAdicionar.Enabled = $false
    $BtnRemover.Enabled   = $false
    $BtnIniciar.Enabled   = $false
    $TxtLogs.Clear()
    $TxtGbak.Clear()

    $Fila = @()
    for ($i = 0; $i -lt $ListaBancos.Items.Count; $i++) {
        $Item = $ListaBancos.Items[$i]
        $Item.SubItems[1].Text = "Na Fila"
        $Item.BackColor = [System.Drawing.Color]::White
        $Item.ForeColor = [System.Drawing.Color]::Black

        $Sis = $Item.Text
        $Cam = $Item.SubItems[2].Text
        $Dir = [System.IO.Path]::GetDirectoryName($Cam)

        $Fila += [PSCustomObject]@{
            Index             = $i
            Sistema           = $Sis
            BancoOrigem       = $Cam
            ArquivoBackupTemp = Join-Path $Dir "temp_migracao_$Sis.fbk"
            ArquivoBancoNovo  = Join-Path $Dir "temp_fb50_$Sis.fdb"
            ArquivoBancoFinal = Join-Path $Dir "$Sis.fdb"
        }
    }

    $SyncHash.Concluido   = $false
    $SyncHash.Erro        = $null
    $SyncHash.Progress    = 0
    $SyncHash.MaxProgress = 2 + ($Fila.Count * 2) + 1
    $SyncHash.StatusText  = "Iniciando checagens de ambiente..."

    $TimerAtualizacao.Start()

    # --- SCRIPT WORKER ---
    $ScriptBlockWorker = {
        param($Sync, $Fila, $ScriptDir)

        function Log($txt) {
            $timestamp = (Get-Date).ToString("HH:mm:ss")
            $Sync.LogQueue.Add("[$timestamp] $txt") | Out-Null
        }

        function ExecutarGbakComMonitor($executavel, $argumentos) {
            $logTemp = [System.IO.Path]::GetTempFileName()

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c `"`"$executavel`" $argumentos > `"$logTemp`" 2>&1`""
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            $proc = [System.Diagnostics.Process]::Start($psi)

            $lastPos = 0
            while (-not $proc.HasExited) {
                if (Test-Path $logTemp) {
                    try {
                        $fs = New-Object System.IO.FileStream($logTemp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        if ($fs.Length -gt $lastPos) {
                            $fs.Seek($lastPos, [System.IO.SeekOrigin]::Begin) | Out-Null
                            $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::Default)
                            while (-not $sr.EndOfStream) {
                                $linha = $sr.ReadLine()
                                if ($linha) {
                                    $Sync.GbakQueue.Add($linha) | Out-Null
                                }
                            }
                            $lastPos = $fs.Position
                            $sr.Close()
                        }
                        $fs.Close()
                    } catch {}
                }
                Start-Sleep -Milliseconds 250
            }

            if (Test-Path $logTemp) {
                try {
                    $fs = New-Object System.IO.FileStream($logTemp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    if ($fs.Length -gt $lastPos) {
                        $fs.Seek($lastPos, [System.IO.SeekOrigin]::Begin) | Out-Null
                        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::Default)
                        while (-not $sr.EndOfStream) {
                            $linha = $sr.ReadLine()
                            if ($linha) {
                                $Sync.GbakQueue.Add($linha) | Out-Null
                            }
                        }
                        $sr.Close()
                    }
                    $fs.Close()
                    Remove-Item $logTemp -Force -ErrorAction SilentlyContinue
                } catch {}
            }

            return $proc.ExitCode
        }

        try {
            $PastaDestinoFB50     = "C:\Fortes\Firebird\Firebird_5_0"
            $ZipOrigemFB50        = Join-Path $ScriptDir "Binarios\Firebird_5_0.zip"
            $CaminhoFB25_Gbak     = "C:\Fortes\Firebird\Firebird_2_5\bin\gbak.exe"
            $CaminhoFB50_Gbak     = Join-Path $PastaDestinoFB50 "gbak.exe"
            $CaminhoFB50_InstSvc  = Join-Path $PastaDestinoFB50 "instsvc.exe"
            $CaminhoFB50_InstReg  = Join-Path $PastaDestinoFB50 "instreg.exe"
            $PortaPadrao          = "53052"
            $UsuarioFB            = "SYSDBA"
            $SenhaFB              = "masterkey"
            $ServicoFB25_Server   = "FirebirdServerFortes_FB2_5"
            $ServicoFB25_Guardian = "FirebirdGuardianFortes_FB2_5"
            $NomeInstanciaFB50    = "Fortes_FB5_0"
            $ServicoFB50_Server   = "FirebirdServer$NomeInstanciaFB50"

            # 1. Configuração do FB 5.0
            $Sync.StatusText = "Etapa 1: Preparando o Firebird 5.0..."
            Log "Checando binários do Firebird 5.0..."

            if (-not (Test-Path $CaminhoFB50_Gbak)) {
                if (-not (Test-Path $ZipOrigemFB50)) {
                    throw "Pacote ZIP não encontrado em: $ZipOrigemFB50"
                }
                Log "Extraindo binários para $PastaDestinoFB50..."
                if (-not (Test-Path $PastaDestinoFB50)) { New-Item -ItemType Directory -Path $PastaDestinoFB50 -Force | Out-Null }
                Expand-Archive -Path $ZipOrigemFB50 -DestinationPath $PastaDestinoFB50 -Force
                Log "Extração finalizada."
            }

            if (Test-Path $CaminhoFB50_InstReg) {
                & $CaminhoFB50_InstReg install "$PastaDestinoFB50" 2>$null | Out-Null
            }

            $ServicoFB50 = Get-Service -Name $ServicoFB50_Server -ErrorAction SilentlyContinue
            if (-not $ServicoFB50) {
                Log "Registrando serviço do Firebird 5.0..."
                & $CaminhoFB50_InstSvc install -auto -name $NomeInstanciaFB50
                Start-Sleep -Seconds 2
            }

            Log "Garantindo porta $PortaPadrao no Firewall do Windows..."
            $NomeRegra = "Firebird Fortes (Porta $PortaPadrao)"
            netsh advfirewall firewall delete rule name="$NomeRegra" >$null 2>&1
            netsh advfirewall firewall add rule name="$NomeRegra" dir=in action=allow protocol=TCP localport=$PortaPadrao profile=any >$null
            Log "Firewall validado para a porta $PortaPadrao."

            $Sync.Progress++

            # 2. Backups via FB 2.5
            Log "Reiniciando Firebird 2.5 para fechar conexões ativas..."
            if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) { Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue }
            if (Get-Service -Name $ServicoFB25_Server -ErrorAction SilentlyContinue) { Restart-Service -Name $ServicoFB25_Server -Force }
            if (Get-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue) { Start-Service -Name $ServicoFB25_Guardian -ErrorAction SilentlyContinue }

            foreach ($item in $Fila) {
                $Sync.StatusText = "Extraindo backup do sistema: $($item.Sistema)..."
                Log "Iniciando gbak (Backup) para $($item.Sistema)..."
                $Sync.ItemUpdates.Add(@{ Index = $item.Index; Status = "Extraindo Backup..."; Tipo = "Processando" }) | Out-Null

                $ConexaoFB25 = "localhost/${PortaPadrao}:$($item.BancoOrigem)"
                $argsGbak = "-b -v -g `"$ConexaoFB25`" `"$($item.ArquivoBackupTemp)`" -user $UsuarioFB -password $SenhaFB"
                
                $exitCode = ExecutarGbakComMonitor $CaminhoFB25_Gbak $argsGbak

                if ($exitCode -ne 0 -or -not (Test-Path $item.ArquivoBackupTemp)) {
                    $Sync.ItemUpdates.Add(@{ Index = $item.Index; Status = "Erro no Backup"; Tipo = "Erro" }) | Out-Null
                    throw "Falha ao extrair backup da base $($item.Sistema)."
                }
                
                Log "Backup do $($item.Sistema) extraído com sucesso."
                $Sync.ItemUpdates.Add(@{ Index = $item.Index; Status = "Backup Concluído"; Tipo = "Processando" }) | Out-Null
                $Sync.Progress++
            }

            # 3. Transição dos Serviços
            $Sync.StatusText = "Realizando transição de motores na porta $PortaPadrao..."
            Log "Parando e desinstalando serviços do Firebird 2.5..."
            Stop-Service -Name $ServicoFB25_Guardian -Force -ErrorAction SilentlyContinue
            Stop-Service -Name $ServicoFB25_Server -Force -ErrorAction SilentlyContinue
            sc.exe delete $ServicoFB25_Guardian | Out-Null
            sc.exe delete $ServicoFB25_Server | Out-Null
            Start-Sleep -Seconds 2

            Log "Iniciando serviço do Firebird 5.0 na porta $PortaPadrao..."
            Start-Service -Name $ServicoFB50_Server
            Start-Sleep -Seconds 3

            if ((Get-Service -Name $ServicoFB50_Server).Status -ne "Running") {
                throw "O Firebird 5.0 não conseguiu iniciar na porta $PortaPadrao. Verifique o firebird.conf."
            }
            Log "Firebird 5.0 operacional na porta $PortaPadrao."
            $Sync.Progress++

            # 4. Restaurações via FB 5.0
            foreach ($item in $Fila) {
                $Sync.StatusText = "Restaurando base do sistema: $($item.Sistema)..."
                Log "Iniciando gbak (Restore) de $($item.Sistema) (ODS 13.x, Page Size 8192)..."
                $Sync.ItemUpdates.Add(@{ Index = $item.Index; Status = "Restaurando..."; Tipo = "Processando" }) | Out-Null

                if (Test-Path $item.ArquivoBancoNovo) { Remove-Item $item.ArquivoBancoNovo -Force }

                $ConexaoFB50 = "localhost/${PortaPadrao}:$($item.ArquivoBancoNovo)"
                $argsGbakRestore = "-c -v -p 8192 `"$($item.ArquivoBackupTemp)`" `"$ConexaoFB50`" -user $UsuarioFB -password $SenhaFB"

                $exitCode = ExecutarGbakComMonitor $CaminhoFB50_Gbak $argsGbakRestore

                if ($exitCode -ne 0 -or -not (Test-Path $item.ArquivoBancoNovo)) {
                    $Sync.ItemUpdates.Add(@{ Index = $item.Index; Status = "Erro no Restore"; Tipo = "Erro" }) | Out-Null
                    throw "Falha ao restaurar $($item.Sistema) no Firebird 5.0."
                }

                if (Test-Path $item.ArquivoBackupTemp) { Remove-Item $item.ArquivoBackupTemp -Force }

                if (Test-Path $item.ArquivoBancoFinal) {
                    $BackupAntigo = "$($item.ArquivoBancoFinal)_OLD_$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
                    Rename-Item -Path $item.ArquivoBancoFinal -NewName (Split-Path $BackupAntigo -Leaf) -Force
                    Log "Base anterior arquivada em: $(Split-Path $BackupAntigo -Leaf)"
                }

                Move-Item -Path $item.ArquivoBancoNovo -Destination $item.ArquivoBancoFinal -Force
                Log "Base $($item.Sistema) disponível em: $($item.ArquivoBancoFinal)"

                # SINALIZAÇÃO VISUAL: Base finalizada com destaque em verde
                $Sync.ItemUpdates.Add(@{ Index = $item.Index; Status = "Concluído [OK]"; Tipo = "Concluido" }) | Out-Null
                $Sync.Progress++
            }

            $Sync.StatusText = "Migração concluída com sucesso!"
            Log "Todas as bases foram migradas e os arquivos .INI mantidos intactos."
        } catch {
            $Sync.Erro = $_.Exception.Message
            Log "[FALHA CRÍTICA] $($_.Exception.Message)"
            $Sync.StatusText = "Erro durante o processamento."
        } finally {
            $Sync.Concluido = $true
        }
    }

    $PowerShellWorker = [powershell]::Create().AddScript($ScriptBlockWorker).AddArgument($SyncHash).AddArgument($Fila).AddArgument($ScriptDir)
    $PowerShellWorker.BeginInvoke() | Out-Null
})

# Exibe o formulário
$Form.ShowDialog() | Out-Null