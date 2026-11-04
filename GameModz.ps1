param(
    [ValidateSet('Menu','Ativar','Desativar','Status','TentarNovamente','ReduzirPrioridade','FecharProcesso')][string]$Acao = 'Menu',
    [string[]]$FecharApps = @(),
    [switch]$PausarOneDrive,
    [switch]$AltoDesempenho,
    [switch]$NaoInterativo,
    [switch]$ReabrirApps,
    [string]$Item,
    [string]$AlvoFile,
    [int]$OwnerId=0,
    [string]$OwnerStarted,
    [switch]$RecoveryOnly,
    [switch]$ShutdownRecovery
)
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:LOCALAPPDATA 'GameModz'
$stateFile = Join-Path $base 'estado.json'
New-Item -ItemType Directory -Path $base -Force | Out-Null
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GMNative {
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(uint a, uint b, string c, uint d);
 [DllImport("user32.dll", EntryPoint="SystemParametersInfoW")] public static extern bool GetBool(uint a, uint b, ref int c, uint d);
 [DllImport("user32.dll", EntryPoint="SystemParametersInfoW")] public static extern bool SetBool(uint a, uint b, IntPtr c, uint d);
}
'@
. (Join-Path $PSScriptRoot 'Safety.ps1')
function Save-State($s) { Write-DurableState $s }
function Wallpaper($path,[bool]$Persist=$true) {
    if (-not [GMNative]::SystemParametersInfo(20,0,$path,$(if($Persist){3}else{2}))) { throw 'Nao foi possivel alterar o papel de parede.' }
}
function Effects([bool]$enabled,[bool]$Persist=$true) {
    if (-not [GMNative]::SetBool(0x103F,0,[IntPtr]([int]$enabled),$(if($Persist){3}else{2}))) { throw 'Nao foi possivel alterar os efeitos visuais.' }
}
function Set-TransparencyValue([string]$Key,[int]$Value) {
    # New-Item -Force em uma chave existente apaga outras preferencias, inclusive o tema.
    if (-not (Test-Path -LiteralPath $Key)) { New-Item -Path $Key | Out-Null }
    New-ItemProperty -LiteralPath $Key -Name EnableTransparency -Value $Value -PropertyType DWord -Force | Out-Null
}
function Request-OneDriveShutdown([string]$Executable,[int]$OriginalProcessId,[int]$TimeoutMs=5000) {
    # Nao esperar o processo de lancamento: ele pode continuar residente.
    $launcher = Start-Process -FilePath $Executable -ArgumentList '/shutdown' -PassThru
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while ($watch.ElapsedMilliseconds -lt $TimeoutMs) {
            if (-not (Get-Process -Id $OriginalProcessId -ErrorAction SilentlyContinue)) { return $true }
            Start-Sleep -Milliseconds 150
        }
        return $false
    } finally { if ($launcher) { $launcher.Dispose() } }
}
. (Join-Path $PSScriptRoot 'Engine.ps1')
$mutexName='Global\GameModzScript-'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$mutex = New-Object System.Threading.Mutex($false,$mutexName)
$locked = $false
try {
    try { $locked = $mutex.WaitOne($(if($Acao -eq 'Desativar'){30000}else{0})) } catch [System.Threading.AbandonedMutexException] { $locked=$true }
    if (-not $locked) { throw 'Outra instancia do GameModz esta aberta.' }
    if ($Acao -eq 'Menu') {
        Write-Host 'GameModz | 1 - Ativar | 2 - Desativar/restaurar | 3 - Status'
        switch (Read-Host 'Escolha') {
            '1' { $Acao='Ativar' }
            '2' { $Acao='Desativar' }
            '3' { $Acao='Status' }
            default { return }
        }
    }
    switch ($Acao) {
        Ativar { Activate }
        Desativar { Restore; if((Get-StatePresent) -and -not $script:recoverySkipped){throw 'Restauracao incompleta. Snapshot e recuperacao no login foram preservados.'} }
        TentarNovamente { Retry-Step $Item }
        ReduzirPrioridade { Invoke-ProcessAction 'ReduzirPrioridade' $AlvoFile }
        FecharProcesso { Invoke-ProcessAction 'FecharProcesso' $AlvoFile }
        Status {
            if (Get-StatePresent) { Write-Host 'Modo ativo ou restauracao pendente:'; Read-State | ConvertTo-Json -Depth 12 }
            else { Write-Host 'Modo desligado. Nenhuma restauracao pendente.' }
        }
    }
} finally { if ($locked) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
