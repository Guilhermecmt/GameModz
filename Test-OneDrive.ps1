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
