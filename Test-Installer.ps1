param([ValidatePattern('^\d+\.\d+\.\d+$')][string]$DownloadVersion)
$ErrorActionPreference='Stop'
$testRoot=Join-Path $env:TEMP ('GameModz-InstallerTest-'+[guid]::NewGuid().ToString('N'))
$oldLocal=$env:LOCALAPPDATA
$env:LOCALAPPDATA=Join-Path $testRoot 'Perfil com espacos'
$desktop=Join-Path $testRoot 'Area de trabalho';$menu=Join-Path $testRoot 'Menu Iniciar'
$installed=Join-Path $env:LOCALAPPDATA 'Programs\GameModz'
function Assert($value,$message){if(-not $value){throw $message}}
function Install-Test {& (Join-Path $PSScriptRoot 'Install.ps1') -SourcePath $PSScriptRoot -DesktopDirectory $desktop -StartMenuDirectory $menu}
try{
 Install-Test
 Assert (Test-Path (Join-Path $installed 'GameModz.exe')) 'Executavel nao instalado.'
 $expectedVersion=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()+'.0'
 Assert ((Get-Item -LiteralPath (Join-Path $installed 'GameModz.exe')).VersionInfo.FileVersion -eq $expectedVersion) 'Lancador nao foi compilado com a versao do pacote.'
 Assert (-not(Get-Item -LiteralPath (Join-Path $installed 'GameModz.exe') -Stream Zone.Identifier -ErrorAction SilentlyContinue)) 'Lancador compilado ficou marcado como baixado da internet.'
 $shell=New-Object -ComObject WScript.Shell
 $shortcut=$shell.CreateShortcut((Join-Path $desktop 'GameModz.lnk'))
 $fs=New-Object -ComObject Scripting.FileSystemObject
 Assert ($fs.GetFile($shortcut.TargetPath).ShortPath -ieq $fs.GetFile((Join-Path $installed 'GameModz.exe')).ShortPath) 'Destino incorreto no atalho.'
 Assert ($fs.GetFolder($shortcut.WorkingDirectory).ShortPath -ieq $fs.GetFolder($installed).ShortPath) 'Diretorio de trabalho incorreto.'
 Assert (Test-Path (Join-Path $menu 'Desinstalar GameModz.lnk')) 'Atalho de desinstalacao ausente.'
 Write-Output 'PASS: instalacao offline em caminho com espacos e atalhos reais na area de trabalho e menu Iniciar.'
 $data=Join-Path $env:LOCALAPPDATA 'GameModz';New-Item -ItemType Directory -Path $data -Force|Out-Null
 Set-Content -LiteralPath (Join-Path $data 'preferencias.json') -Value '{"preservar":true}'
 Install-Test
 Assert (Test-Path (Join-Path $data 'preferencias.json')) 'Atualizacao apagou preferencias.'
 Assert (@(Get-ChildItem (Split-Path $installed -Parent) -Directory).Count -eq 1) 'Atualizacao deixou staging ou backup.'
 Write-Output 'PASS: reinstalacao/atualizacao preserva dados e limpa staging.'
 Set-Content -LiteralPath (Join-Path $data 'estado.json.bak') -Value '{}'
 $blocked=$false;try{Install-Test}catch{$blocked=$true}
 Assert $blocked 'Instalador aceitou restauracao pendente.'
 $blocked=$false;try{& (Join-Path $installed 'Uninstall.ps1')}catch{$blocked=$true}
 Assert $blocked 'Desinstalador aceitou restauracao pendente.'
 Remove-Item -LiteralPath (Join-Path $data 'estado.json.bak')
 Write-Output 'PASS: instalacao e desinstalacao bloqueadas com snapshot pendente, inclusive backup isolado.'
 # Force a shortcut failure after promotion: existing installation must return intact.
 $oldBytes=[IO.File]::ReadAllBytes((Join-Path $desktop 'GameModz.lnk'))
 $badDesktop=Join-Path $testRoot 'Atalho bloqueado';New-Item -ItemType Directory -Path (Join-Path $badDesktop 'GameModz.lnk') -Force|Out-Null
 $blocked=$false
 try{& (Join-Path $PSScriptRoot 'Install.ps1') -SourcePath $PSScriptRoot -DesktopDirectory $badDesktop -StartMenuDirectory $menu}catch{$blocked=$true}
 Assert $blocked 'Falha de atalho nao detectada.'
 Assert (Test-Path (Join-Path $installed '.gamemodz-install.json')) 'Instalacao anterior perdida.'
 Assert ([Convert]::ToBase64String($oldBytes) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $desktop 'GameModz.lnk')))) 'Atalho anterior alterado.'
 Write-Output 'PASS: falha ao preparar atalhos preserva instalacao e atalho anteriores.'
 $manifestBefore=Get-Content -LiteralPath (Join-Path $installed '.gamemodz-install.json') -Raw
 $badSource=Join-Path $testRoot 'Pacote com falha simulada'
 Copy-Item -LiteralPath $installed -Destination $badSource -Recurse
 Add-Content -LiteralPath (Join-Path $badSource 'Installer.Common.ps1') -Value "`nfunction Set-GameModzShortcut {throw 'Falha de atalho simulada depois da troca'}" -Encoding UTF8
 $blocked=$false
 try{& (Join-Path $PSScriptRoot 'Install.ps1') -SourcePath $badSource -DesktopDirectory $desktop -StartMenuDirectory $menu}catch{$blocked=$true}
 Assert $blocked 'Falha depois da troca nao detectada.'
 Assert ((Get-Content -LiteralPath (Join-Path $installed '.gamemodz-install.json') -Raw) -ceq $manifestBefore) 'Rollback nao restaurou instalacao anterior.'
 Assert ([Convert]::ToBase64String($oldBytes) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $desktop 'GameModz.lnk')))) 'Rollback nao restaurou atalho anterior.'
 Write-Output 'PASS: falha apos troca dos arquivos desfaz instalacao e preserva atalhos anteriores.'
 # Deleting an unrelated replacement shortcut is forbidden.
 $replacement=$shell.CreateShortcut((Join-Path $desktop 'GameModz.lnk'));$replacement.TargetPath=Join-Path $env:WINDIR 'notepad.exe';$replacement.Save()
 & (Join-Path $installed 'Uninstall.ps1')
 Assert (-not(Test-Path $installed)) 'Instalacao nao removida.'
 Assert (Test-Path (Join-Path $data 'preferencias.json')) 'Desinstalacao apagou dados pessoais.'
 Assert (Test-Path (Join-Path $desktop 'GameModz.lnk')) 'Atalho de outro programa apagado.'
 Assert (-not(Test-Path (Join-Path $menu 'GameModz.lnk'))) 'Atalho proprio nao removido.'
 Write-Output 'PASS: desinstalacao remove programa e atalhos proprios, preservando dados e atalhos substituidos.'
 New-Item -ItemType Directory -Path $installed -Force|Out-Null
 Set-Content -LiteralPath (Join-Path $installed 'arquivo-do-usuario.txt') -Value 'preservar'
 $blocked=$false;try{Install-Test}catch{$blocked=$true}
 Assert $blocked 'Pasta desconhecida foi sobrescrita.'
 Assert (Test-Path (Join-Path $installed 'arquivo-do-usuario.txt')) 'Arquivo de pasta desconhecida foi perdido.'
 Write-Output 'PASS: pasta sem manifesto nao e sobrescrita.'
 if($DownloadVersion){
  Remove-Item -LiteralPath (Join-Path $installed 'arquivo-do-usuario.txt');Remove-Item -LiteralPath $installed
  $standalone=Join-Path $testRoot 'Install-Standalone.ps1';Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install.ps1') -Destination $standalone
  & $standalone -Version $DownloadVersion -DesktopDirectory $desktop -StartMenuDirectory $menu
  Assert ((Get-Content -LiteralPath (Join-Path $installed 'VERSION') -Raw).Trim() -eq $DownloadVersion) 'Download nao instalou a versao solicitada.'
  & (Join-Path $installed 'Uninstall.ps1')
  Assert (-not(Test-Path $installed)) 'Pacote baixado nao foi removido.'
  Write-Output 'PASS: instalador avulso baixou pacote publico por HTTPS, instalou a tag solicitada e desinstalou.'
 }
}finally{
 $env:LOCALAPPDATA=$oldLocal
 $full=[IO.Path]::GetFullPath($testRoot)
 if((Split-Path $full -Parent) -ieq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') -and (Split-Path $full -Leaf) -match '^GameModz-InstallerTest-[a-f0-9]{32}$'){Remove-Item -LiteralPath $full -Recurse -Force}
}
