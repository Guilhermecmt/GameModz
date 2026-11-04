param([string]$OutputPath=(Join-Path $PSScriptRoot 'GameModz.exe'))
$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path $compiler)){$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'}
if(-not(Test-Path $compiler)){throw 'Compilador C# do .NET Framework nao encontrado.'}
$version=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
if($version -notmatch '^\d+\.\d+\.\d+$'){throw 'VERSION deve usar MAJOR.MINOR.PATCH.'}
# O arquivo temporario fica fora da pasta de origem, que pode ser somente leitura.
$info=Join-Path ([IO.Path]::GetTempPath()) ('GameModz-AssemblyInfo-'+[guid]::NewGuid().ToString('N')+'.cs')
try{
 [IO.File]::WriteAllText($info,('[assembly: System.Reflection.AssemblyVersion("'+$version+'.0")]'+[Environment]::NewLine+'[assembly: System.Reflection.AssemblyFileVersion("'+$version+'.0")]'))
 & $compiler /nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll ('/win32icon:'+(Join-Path $PSScriptRoot 'assets\GameModz.ico')) ('/out:'+$OutputPath) (Join-Path $PSScriptRoot 'Launcher.cs') $info
 if($LASTEXITCODE -ne 0){throw 'Falha ao compilar o lancador.'}
}finally{Remove-Item -LiteralPath $info -ErrorAction SilentlyContinue}
if(-not(Test-Path -LiteralPath $OutputPath -PathType Leaf)){throw 'Lancador nao foi gerado.'}
Write-Output 'GameModz.exe compilado.'
