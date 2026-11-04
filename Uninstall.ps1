[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Installer.Common.ps1')
$locked=$false
try{
 Enter-InstallLock;$locked=$true
 if(-not(Test-Path -LiteralPath $script:installDirectory)){Write-Host 'GameModz nao esta instalado neste perfil.';return}
 $manifest=Get-InstallManifest $script:installDirectory
 $exe=Join-Path $script:installDirectory 'GameModz.exe'
 foreach($link in @($manifest.DesktopShortcut,$manifest.MenuShortcut)){
  if($link -and [IO.Path]::GetFileName($link) -eq 'GameModz.lnk'){Remove-OwnedShortcut $link $exe}
 }
 if($manifest.UninstallShortcut -and [IO.Path]::GetFileName($manifest.UninstallShortcut) -eq 'Desinstalar GameModz.lnk'){
  $shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut($manifest.UninstallShortcut)
  $expected='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $script:installDirectory 'Uninstall.ps1')+'"'
  $hostPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if($shortcut.Arguments -ceq $expected -and (Test-SameInstalledFile $shortcut.TargetPath $hostPath)){Remove-Item -LiteralPath $manifest.UninstallShortcut -Force -ErrorAction SilentlyContinue}
 }
 Remove-ManagedDirectory $script:installDirectory
 Write-Host 'GameModz removido. Preferencias e arquivos de recuperacao foram preservados em LOCALAPPDATA\GameModz.'
}finally{if($locked){Exit-InstallLock}}
