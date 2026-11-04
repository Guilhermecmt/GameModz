param([int]$OwnerId=0,[string]$OwnerStarted,[string]$ReadyFile,[switch]$LoginRecovery)
$ErrorActionPreference='Stop'
$base=Join-Path $env:LOCALAPPDATA 'GameModz'
$stateFile=Join-Path $base 'estado.json'
$backend=Join-Path $PSScriptRoot 'GameModz.ps1'
$hostPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Owner-Alive {
 if($OwnerId -le 0){return $false}
 $p=Get-Process -Id $OwnerId -ErrorAction SilentlyContinue
 if(-not $p){return $false}
 try{return $p.StartTime.ToUniversalTime().Ticks.ToString() -eq $OwnerStarted}catch{return $false}finally{$p.Dispose()}
}
function State-Present { (Test-Path $stateFile) -or (Test-Path ($stateFile+'.bak')) }
function Recover {
 & $hostPath -NoProfile -ExecutionPolicy Bypass -File $backend -Acao Desativar -NaoInterativo -RecoveryOnly *>> (Join-Path $base 'recovery.log')
}
try {
 Add-Type -Path (Join-Path $PSScriptRoot 'SessionGuard.cs')
 [GMSessionGuard]::HostPath=$hostPath;[GMSessionGuard]::BackendPath=$backend
 [GMSessionGuard]::Install()
 if($ReadyFile){[IO.File]::WriteAllText($ReadyFile,'ready')}
 if(-not $LoginRecovery){
  # Activation owns the backend mutex while the snapshot is created.
  while(Owner-Alive){
   if(State-Present){break}
   Start-Sleep -Milliseconds 250
  }
  while((Owner-Alive) -and (State-Present)){Start-Sleep -Milliseconds 500}
 }
 # Login worker must not undo a session already owned by a live interface.
 if($LoginRecovery -and (State-Present)){
  try{$s=Get-Content $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
   if($s.Owner){$OwnerId=$s.Owner.Id;$OwnerStarted=$s.Owner.Started;if(Owner-Alive){return}}
  }catch{}
 }
 if($LoginRecovery -and -not(State-Present)){Recover}
 for($attempt=0;$attempt -lt 3 -and (State-Present);$attempt++){
  # Native stderr is a terminating error under Windows PowerShell with Stop.
  # Catch each attempt so a transient backend failure cannot skip the rest.
  try{Recover}catch{try{$_|Out-String|Add-Content -LiteralPath (Join-Path $base 'recovery.log')}catch{}}
  if($attempt -lt 2 -and (State-Present)){Start-Sleep -Seconds 2}
 }
} catch {$_|Out-String|Add-Content -LiteralPath (Join-Path $base 'recovery.log')}
finally{if('GMSessionGuard' -as [type]){[GMSessionGuard]::Uninstall()}}
