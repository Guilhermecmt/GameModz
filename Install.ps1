[CmdletBinding()]
param(
 [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version='1.2.1',
 [string]$SourcePath,
 [string]$DesktopDirectory=[Environment]::GetFolderPath('DesktopDirectory'),
 [string]$StartMenuDirectory=[Environment]::GetFolderPath('Programs')
)
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT' -or $PSVersionTable.PSVersion -lt [version]'5.1'){throw 'Use Windows PowerShell 5.1 ou superior no Windows.'}
$downloadRoot=$null;$stage=$null;$backup=$null;$locked=$false;$promoted=$false;$shortcutBackups=@{}
try{
 if(-not $SourcePath -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'GameModz.exe'))){$SourcePath=$PSScriptRoot}
 if(-not $SourcePath){
  $downloadRoot=Join-Path $env:TEMP ('GameModz-Download-'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $downloadRoot|Out-Null
  $archive=Join-Path $downloadRoot 'source.zip';$extracted=Join-Path $downloadRoot 'source'
  [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  Write-Host ('Baixando GameModz '+$Version+'...')
  Invoke-WebRequest -Uri ('https://github.com/Guilhermecmt/GameModz/archive/refs/tags/v'+$Version+'.zip') -OutFile $archive -UseBasicParsing
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=[IO.Compression.ZipFile]::OpenRead($archive)
  try{
   $prefix=[IO.Path]::GetFullPath($extracted)+'\'
   foreach($entry in $zip.Entries){
    $target=[IO.Path]::GetFullPath((Join-Path $extracted $entry.FullName))
    if(-not $target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Arquivo ZIP com caminho invalido.'}
   }
  }finally{$zip.Dispose()}
  Expand-Archive -LiteralPath $archive -DestinationPath $extracted
  $folders=@(Get-ChildItem -LiteralPath $extracted -Directory)
  if($folders.Count -ne 1){throw 'Formato inesperado do pacote.'}
  $SourcePath=$folders[0].FullName
  if((Get-Content -LiteralPath (Join-Path $SourcePath 'VERSION') -Raw).Trim() -ne $Version){throw 'Versao do pacote diferente da solicitada.'}
 }
 $SourcePath=(Resolve-Path -LiteralPath $SourcePath).ProviderPath
 $files=@('GameModz.exe','GameModz-UI.ps1','GameModz.ps1','Engine.ps1','Safety.ps1','Recovery.Worker.ps1','SessionGuard.cs','Process.Common.ps1','Monitor.Worker.ps1','Interface.Helpers.ps1','Interface.Session.ps1','Interface.xaml','Installer.Common.ps1','Uninstall.ps1','VERSION','README.md','SAFETY.md','CHANGELOG.md','assets\GameModz.ico','assets\power-core.png')
 foreach($file in $files){if(-not(Test-Path -LiteralPath (Join-Path $SourcePath $file) -PathType Leaf)){throw ('Pacote incompleto: '+$file)}}
 $packageVersion=(Get-Content -LiteralPath (Join-Path $SourcePath 'VERSION') -Raw).Trim()
 if($packageVersion -notmatch '^\d+\.\d+\.\d+$'){throw 'Versao invalida no pacote.'}
 . (Join-Path $SourcePath 'Installer.Common.ps1')
 Enter-InstallLock;$locked=$true
 Repair-InstallTransaction
 [void](Assert-ManagedDirectory $script:installDirectory)
 if(Test-Path -LiteralPath $script:installDirectory){[void](Get-InstallManifest $script:installDirectory)}
 if(-not $DesktopDirectory -or -not $StartMenuDirectory){throw 'O Windows nao informou o local dos atalhos.'}
 foreach($folder in @($DesktopDirectory,$StartMenuDirectory)){New-Item -ItemType Directory -Path $folder -Force|Out-Null}
 $desktopLink=Join-Path $DesktopDirectory 'GameModz.lnk';$menuLink=Join-Path $StartMenuDirectory 'GameModz.lnk'
 $uninstallLink=Join-Path $StartMenuDirectory 'Desinstalar GameModz.lnk'
 foreach($link in @($desktopLink,$menuLink,$uninstallLink)){
  if(Test-Path -LiteralPath $link){$shortcutBackups[$link]=[IO.File]::ReadAllBytes($link)}else{$shortcutBackups[$link]=$null}
 }
 New-Item -ItemType Directory -Path $script:installParent -Force|Out-Null
 $stage=Join-Path $script:installParent ('GameModz.stage-'+[guid]::NewGuid().ToString('N'))
 [void](Assert-ManagedDirectory $stage);New-Item -ItemType Directory -Path $stage|Out-Null
 New-Item -ItemType Directory -Path (Join-Path $stage 'assets')|Out-Null
 foreach($file in $files){Copy-Item -LiteralPath (Join-Path $SourcePath $file) -Destination (Join-Path $stage $file) -Force;Unblock-File -LiteralPath (Join-Path $stage $file)}
 $manifest=[ordered]@{Product='GameModz';InstallerSchema=1;Version=$packageVersion;InstallDirectory=$script:installDirectory;DesktopShortcut=$desktopLink;MenuShortcut=$menuLink;UninstallShortcut=$uninstallLink;Installed=(Get-Date).ToString('o')}
 $manifest|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $stage $script:installMarker) -Encoding UTF8
 $hadPrevious=Test-Path -LiteralPath $script:installDirectory
 if($hadPrevious){$backup=Join-Path $script:installParent ('GameModz.backup-'+[guid]::NewGuid().ToString('N'));[void](Assert-ManagedDirectory $backup)}
 $links=@(foreach($link in $shortcutBackups.Keys){[pscustomobject]@{Path=$link;Existed=($null -ne $shortcutBackups[$link]);Bytes=if($null -ne $shortcutBackups[$link]){[Convert]::ToBase64String($shortcutBackups[$link])}else{''}}})
 $transaction=[pscustomobject]@{Product='GameModz';Schema=1;Stage=$stage;Backup=$backup;HadPrevious=[bool]$hadPrevious;Committed=$false;Shortcuts=$links}
 Write-InstallTransaction $transaction
 if($hadPrevious){Move-Item -LiteralPath $script:installDirectory -Destination $backup}
 [void](Assert-ManagedDirectory $stage);Move-Item -LiteralPath $stage -Destination $script:installDirectory;$stage=$null;$promoted=$true
 $exe=Join-Path $script:installDirectory 'GameModz.exe'
 Set-GameModzShortcut $desktopLink $exe;Set-GameModzShortcut $menuLink $exe
 $hostPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
 Set-GameModzShortcut $uninstallLink $hostPath ('-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $script:installDirectory 'Uninstall.ps1')+'"')
 $transaction.Committed=$true
 Write-InstallTransaction $transaction
 Repair-InstallTransaction
 $backup=$null
}catch{
 $failure=$_
 if($locked -and (Test-Path -LiteralPath $script:transactionPath)){
  try{Repair-InstallTransaction;$stage=$null;$backup=$null}catch{Write-Warning ('Recuperacao pendente; execute o instalador novamente. '+$_)}
 }
 throw $failure
}finally{
 if($stage -and -not(Test-Path -LiteralPath $script:transactionPath) -and (Test-Path -LiteralPath $stage)){Remove-ManagedDirectory $stage}
 if($locked){Exit-InstallLock}
 if($downloadRoot -and (Test-Path -LiteralPath $downloadRoot)){
  $full=[IO.Path]::GetFullPath($downloadRoot)
  if((Split-Path $full -Parent) -ieq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') -and (Split-Path $full -Leaf) -match '^GameModz-Download-[a-f0-9]{32}$'){Remove-Item -LiteralPath $full -Recurse -Force}
 }
}
if($backup){try{Remove-ManagedDirectory $backup}catch{Write-Warning ('Instalacao concluida; backup anterior preservado em '+$backup)}}
Write-Host ('GameModz '+$packageVersion+' instalado em '+$script:installDirectory)
Write-Host ('Atalho criado na area de trabalho: '+$desktopLink)
