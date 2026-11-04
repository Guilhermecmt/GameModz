$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'GameModz.ps1'),[ref]$tokens,[ref]$errors)
$fn=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Request-OneDriveShutdown'},$true)
. ([scriptblock]::Create($fn.Extent.Text))
# Mocks somente neste processo de teste. Nenhum OneDrive real e iniciado/encerrado.
function Start-Process { param($FilePath,$ArgumentList,[switch]$PassThru) return [IO.MemoryStream]::new() }
function Get-Process { param($Id,$ErrorAction) if($script:running){[pscustomobject]@{Id=$Id}} }
$script:running=$false
if(-not(Request-OneDriveShutdown 'simulado.exe' 123 300)){throw 'Encerramento nao detectado.'}
$script:running=$true
$watch=[Diagnostics.Stopwatch]::StartNew()
if(Request-OneDriveShutdown 'simulado.exe' 123 300){throw 'Timeout deveria retornar falso.'}
if($watch.ElapsedMilliseconds -gt 2000){throw 'Espera ultrapassou limite tolerado.'}
Write-Output 'PASS: OneDrive encerrado e OneDrive sem resposta; timeout respeitado, sem encerramento forcado.'
# Apps reabertos pelo Engine nao podem herdar a pasta do GameModz (prende a pasta instalada).
$engine=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Engine.ps1'),[ref]$tokens,[ref]$errors)
$launch=$engine.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-LaunchDirectory'},$true)
. ([scriptblock]::Create($launch.Extent.Text))
$exe=Join-Path $env:WINDIR 'System32\notepad.exe'
if((Get-LaunchDirectory $exe) -ine (Split-Path -Parent $exe)){throw 'Diretorio de abertura deveria ser a pasta do aplicativo.'}
$missing=Join-Path $env:TEMP ('GameModz-inexistente-'+[guid]::NewGuid().ToString('N')+'\app.exe')
if((Get-LaunchDirectory $missing) -ine $env:USERPROFILE){throw 'Pasta inexistente deveria usar o perfil do usuario.'}
$calls=@($engine.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Start-Process'},$true))
if($calls.Count -lt 2){throw 'Chamadas de abertura nao encontradas no Engine.'}
foreach($call in $calls){if($call.Extent.Text -notmatch '-WorkingDirectory'){throw ('Start-Process sem -WorkingDirectory: '+$call.Extent.Text)}}
Write-Output 'PASS: OneDrive e apps reabertos iniciam na pasta do proprio aplicativo, sem prender a pasta do GameModz.'
