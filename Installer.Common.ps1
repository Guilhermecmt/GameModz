$ErrorActionPreference='Stop'
$script:installParent=Join-Path $env:LOCALAPPDATA 'Programs'
$script:installDirectory=Join-Path $script:installParent 'GameModz'
$script:installMarker='.gamemodz-install.json'
function Assert-ManagedDirectory([string]$Path) {
 $full=[IO.Path]::GetFullPath($Path).TrimEnd('\')
 $parent=[IO.Path]::GetFullPath($script:installParent).TrimEnd('\')
 if((Split-Path $full -Parent) -ine $parent -or (Split-Path $full -Leaf) -notmatch '^GameModz(?:\.(?:stage|backup)-[a-f0-9]{32})?$'){throw 'Caminho de instalacao fora do destino permitido.'}
 foreach($candidate in @($parent,$full)){
  if((Test-Path -LiteralPath $candidate) -and ((Get-Item -LiteralPath $candidate -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Links de diretorio nao sao permitidos no destino da instalacao.'}
 }
 if(Test-Path -LiteralPath $full){
  if(Get-ChildItem -LiteralPath $full -Recurse -Force|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}){throw 'Link de diretorio encontrado dentro da instalacao.'}
 }
 return $full
}
function Remove-ManagedDirectory([string]$Path) {
 $full=Assert-ManagedDirectory $Path
 if(Test-Path -LiteralPath $full){Remove-Item -LiteralPath $full -Recurse -Force}
}
function Get-InstallManifest([string]$Path) {
 $full=Assert-ManagedDirectory $Path
 $manifest=Get-Content -LiteralPath (Join-Path $full $script:installMarker) -Raw -Encoding UTF8|ConvertFrom-Json
 if($manifest.Product -cne 'GameModz' -or $manifest.InstallerSchema -ne 1 -or $manifest.InstallDirectory -ine $script:installDirectory){throw 'Pasta nao reconhecida como instalacao gerenciada do GameModz.'}
 return $manifest
}
function Enter-InstallLock {
 $script:installLocks=@()
 try{
  $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  foreach($name in @('GameModzInstall','GameModzInterface','GameModzScript')){
   $mutex=[Threading.Mutex]::new($false,('Global\'+$name+'-'+$sid))
   $acquired=$false
   try{$acquired=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$acquired=$true}
   if(-not $acquired){$mutex.Dispose();throw 'Feche o GameModz antes de instalar, atualizar ou remover.'}
   $script:installLocks+= $mutex
  }
  $state=Join-Path $env:LOCALAPPDATA 'GameModz\estado.json'
  if((Test-Path -LiteralPath $state) -or (Test-Path -LiteralPath ($state+'.bak'))){throw 'Existe restauracao pendente. Abra o GameModz e restaure antes de continuar.'}
 }catch{Exit-InstallLock;throw}
}
function Exit-InstallLock {
 foreach($mutex in @($script:installLocks)){$mutex.ReleaseMutex();$mutex.Dispose()}
 $script:installLocks=@()
}
function Test-SameInstalledFile([string]$Left,[string]$Right) {
 if(-not(Test-Path -LiteralPath $Left -PathType Leaf) -or -not(Test-Path -LiteralPath $Right -PathType Leaf)){return $false}
 $fs=New-Object -ComObject Scripting.FileSystemObject
 return $fs.GetFile($Left).ShortPath -ieq $fs.GetFile($Right).ShortPath
}
function Set-GameModzShortcut([string]$Path,[string]$Target,[string]$Arguments='') {
 $shell=New-Object -ComObject WScript.Shell
 $shortcut=$shell.CreateShortcut($Path)
 $shortcut.TargetPath=$Target;$shortcut.Arguments=$Arguments
 $shortcut.WorkingDirectory=$script:installDirectory
 $shortcut.IconLocation=(Join-Path $script:installDirectory 'assets\GameModz.ico')+',0'
 $shortcut.Description='GameModz - preparar e restaurar o ambiente de jogo'
 $shortcut.Save()
 $saved=$shell.CreateShortcut($Path)
 if(-not(Test-Path -LiteralPath $Path) -or -not(Test-SameInstalledFile $saved.TargetPath $Target)){throw ('Nao foi possivel criar o atalho: '+$Path)}
}
function Remove-OwnedShortcut([string]$Path,[string]$Target) {
 if(Test-Path -LiteralPath $Path){
  $shell=New-Object -ComObject WScript.Shell
  if(Test-SameInstalledFile $shell.CreateShortcut($Path).TargetPath $Target){Remove-Item -LiteralPath $Path -Force}
 }
}
