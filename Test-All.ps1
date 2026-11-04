param([switch]$Render,[switch]$Build)
$ErrorActionPreference='Stop'
Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.ps1|ForEach-Object {
 $tokens=$null;$parseErrors=$null
 [void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$parseErrors)
 if($parseErrors.Count){throw ($parseErrors|Out-String)}
}
foreach($name in @('Test-Appearance.ps1','Test-OneDrive.ps1','Test-Session.ps1','Test-Monitor.ps1','Test-Safety.ps1','Test-Installer.ps1','Test-Interruptions.ps1')){
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $name)
 if($LASTEXITCODE -ne 0){throw ('Falhou: '+$name)}
}
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'GameModz-UI.ps1') -TestarCiclo
if($LASTEXITCODE -ne 0){throw 'Falha na regressao da interface.'}
if($Render){
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'GameModz-UI.ps1') -Verificar
 if($LASTEXITCODE -ne 0){throw 'Falha na renderizacao.'}
}
if($Build){
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Build.ps1')
 if($LASTEXITCODE -ne 0){throw 'Falha na compilacao.'}
}
Write-Output 'PASS: bateria completa.'
