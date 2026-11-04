$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path $compiler)){$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
if(-not(Test-Path $compiler)){throw 'Compilador C# do .NET Framework nao encontrado.'}
& $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll ('/win32icon:'+(Join-Path $PSScriptRoot 'assets\GameModz.ico')) ('/out:'+(Join-Path $PSScriptRoot 'GameModz.exe')) (Join-Path $PSScriptRoot 'Launcher.cs')
if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o lancador.'}
Write-Output 'GameModz.exe compilado.'
