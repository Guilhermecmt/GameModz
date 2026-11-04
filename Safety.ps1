# Recovery assets are independent of the installation directory.
$recoveryRoot=Join-Path $base 'Recovery'
$recoveryRunKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
function Get-StatePresent { (Test-Path $stateFile) -or (Test-Path ($stateFile+'.bak')) }
function Test-StateOwnerAlive($s) {
 if(-not $s.Owner -or $s.Owner.Id -le 0){return $false}
 $p=Get-Process -Id $s.Owner.Id -ErrorAction SilentlyContinue
 if(-not $p){return $false}
 try{return $p.StartTime.ToUniversalTime().Ticks.ToString() -eq $s.Owner.Started}catch{return $false}finally{$p.Dispose()}
}
function Write-DurableState($s) {
 $json=$s|ConvertTo-Json -Depth 12
 $bytes=[Text.Encoding]::UTF8.GetBytes($json)
 $stream=[IO.File]::Open($stateFile+'.tmp',[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 if(Test-Path $stateFile){[IO.File]::Replace($stateFile+'.tmp',$stateFile,$stateFile+'.bak',$true)}
 else{[IO.File]::Move($stateFile+'.tmp',$stateFile)}
 # Both copies must contain the latest pending flags before any mutation.
 [IO.File]::Copy($stateFile,$stateFile+'.bak',$true)
}
function Read-DurableState {
 foreach($path in @($stateFile,($stateFile+'.bak'))){
  if(Test-Path $path){try{
   $s=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
   foreach($field in @('Pending','Wallpaper','Effects','TransparencyExists','Transparency','Power','OneDrive','ClosedApps')){
    if(-not $s -or -not $s.PSObject.Properties[$field]){throw 'Snapshot incompleto.'}
   }
   foreach($field in @('Wallpaper','Effects','Transparency','Power','OneDrive')){
    if(-not $s.Pending.PSObject.Properties[$field] -or $s.Pending.$field -isnot [bool]){throw 'Pendencias invalidas.'}
   }
   if($s.Wallpaper -isnot [string] -or $s.Effects -notin @(0,1) -or $s.TransparencyExists -isnot [bool]){throw 'Valores originais invalidos.'}
   return $s
  }catch{Write-Warning ('Snapshot indisponivel: '+$path)}}
 }
 throw 'Nenhum snapshot valido. Os arquivos foram preservados para recuperacao; ativacao bloqueada.'
}
function Remove-RecoveryRegistration {
 if((Test-Path $recoveryRunKey) -and (Get-ItemProperty $recoveryRunKey).PSObject.Properties['GameModzRecovery']){Remove-ItemProperty -LiteralPath $recoveryRunKey -Name GameModzRecovery -ErrorAction Stop}
}
function Install-Recovery {
 New-Item -ItemType Directory -Path $recoveryRoot -Force|Out-Null
 foreach($name in @('GameModz.ps1','Engine.ps1','Process.Common.ps1','Safety.ps1','Recovery.Worker.ps1','SessionGuard.cs')){
  $source=Join-Path $PSScriptRoot $name;$destination=Join-Path $recoveryRoot $name
  if($source -ine $destination){Copy-Item -LiteralPath $source -Destination $destination -Force}
 }
 $hostPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $recoveryScript=Join-Path $recoveryRoot 'Recovery.Worker.ps1'
 $command='"'+$hostPath+'" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$recoveryScript+'" -LoginRecovery'
 if(-not(Test-Path $recoveryRunKey)){New-Item -Path $recoveryRunKey -Force|Out-Null}
 New-ItemProperty -LiteralPath $recoveryRunKey -Name GameModzRecovery -Value $command -PropertyType String -Force|Out-Null
 if((Get-ItemProperty $recoveryRunKey).GameModzRecovery -cne $command){throw 'Recuperacao no login nao foi registrada.'}
}
function Start-RecoveryGuard {
 if($OwnerId -le 0 -or -not $OwnerStarted){throw 'Ativacao exige uma interface proprietaria para restauracao automatica.'}
 $owner=Get-Process -Id $OwnerId -ErrorAction Stop
 try{if($owner.StartTime.ToUniversalTime().Ticks.ToString() -ne $OwnerStarted){throw 'Identidade da interface invalida.'}}finally{$owner.Dispose()}
 Install-Recovery
 $ready=Join-Path $base ('guard-'+[guid]::NewGuid().ToString('N')+'.ready')
 $guardPath=Join-Path $recoveryRoot 'Recovery.Worker.ps1'
 $args='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$guardPath+'" -OwnerId '+$OwnerId+' -OwnerStarted '+$OwnerStarted+' -ReadyFile "'+$ready+'"'
 $guard=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -WindowStyle Hidden -ArgumentList $args -PassThru
 try{
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while(-not(Test-Path $ready)){
   if($guard.HasExited -or $watch.ElapsedMilliseconds -gt 15000){throw 'Protecao independente nao confirmou inicializacao. Nenhum ajuste aplicado.'}
   Start-Sleep -Milliseconds 100
  }
  $script:guardIdentity=[pscustomobject]@{Id=$guard.Id;Started=$guard.StartTime.ToUniversalTime().Ticks.ToString()}
 }finally{$guard.Dispose();Remove-Item -LiteralPath $ready -ErrorAction SilentlyContinue}
}
