$ErrorActionPreference='Stop'
$testRoot=Join-Path $env:TEMP ('GameModz-Safety-'+[guid]::NewGuid().ToString('N'))
$oldLocal=$env:LOCALAPPDATA
$env:LOCALAPPDATA=$testRoot
$base=Join-Path $testRoot 'GameModz';$stateFile=Join-Path $base 'estado.json'
New-Item -ItemType Directory -Path $base -Force|Out-Null
. (Join-Path $PSScriptRoot 'Safety.ps1')
$recoveryRunKey='HKCU:\Software\GameModz-Safety-'+[guid]::NewGuid().ToString('N')
$owner=$null;$guard=$null
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function New-Snapshot {
 [pscustomobject]@{Wallpaper='';Effects=1;TransparencyExists=$true;Transparency=1;Power='';OneDrive=$null;Mode='Active';Owner=$null;ClosedApps=@();Priorities=@();Pending=[pscustomobject]@{Wallpaper=$false;Effects=$true;Transparency=$false;Power=$false;OneDrive=$false}}
}
function Wait-Until([scriptblock]$Condition,[int]$Timeout=15000){
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not(& $Condition)){if($watch.ElapsedMilliseconds -gt $Timeout){throw 'Tempo limite no teste de recuperacao.'};Start-Sleep -Milliseconds 100}
}
try{
 $s=New-Snapshot;Write-DurableState $s
 Assert ((Read-DurableState).Pending.Effects) 'Snapshot nao gravado.'
 Set-Content -LiteralPath $stateFile -Value '{invalid'
 Assert ((Read-DurableState).Pending.Effects) 'Copia de seguranca nao recuperou arquivo corrompido.'
 Remove-Item -LiteralPath $stateFile
 Assert (Get-StatePresent) 'Backup isolado nao foi detectado.'
 Assert ((Read-DurableState).Mode -eq 'Active') 'Backup isolado nao foi lido.'
 Set-Content -LiteralPath ($stateFile+'.bak') -Value '{}'
 $blocked=$false;try{Read-DurableState}catch{$blocked=$true}
 Assert $blocked 'Snapshot incompleto foi aceito.'
 Assert (Test-Path ($stateFile+'.bak')) 'Snapshot invalido foi apagado.'
 Remove-Item -LiteralPath ($stateFile+'.bak')
 Write-Output 'PASS: estado duravel, backup, JSON corrompido, backup isolado e bloqueio sem apagar evidencias.'

 $s=New-Snapshot;$s.Owner=[pscustomobject]@{Id=$PID;Started=[Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks.ToString()}
 Write-DurableState $s
 Assert (Test-StateOwnerAlive $s) 'Proprietario vivo nao reconhecido.'
 $output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'GameModz.ps1') -Acao Desativar -NaoInterativo -RecoveryOnly 2>&1
 Assert ((Read-DurableState).Mode -eq 'Active') 'Backend automatico alterou sessao viva apos adquirir mutex.'
 Assert ((Read-DurableState).Pending.Effects) 'Backend automatico restaurou pendencia de proprietario vivo.'
 Remove-Item -LiteralPath $stateFile,($stateFile+'.bak')
 Write-Output 'PASS: backend real revalida proprietario sob mutex e preserva nova sessao contra recuperacao atrasada.'

 $OwnerId=0;$OwnerStarted='';$blocked=$false
 try{Start-RecoveryGuard}catch{$blocked=$true}
 Assert $blocked 'Ativacao sem proprietario foi aceita.'
 Assert (-not(Get-StatePresent)) 'Falha da protecao criou snapshot.'
 Install-Recovery
 Assert ((Get-ItemProperty $recoveryRunKey).GameModzRecovery -match 'Recovery.Worker.ps1') 'Login nao registrado.'
 foreach($name in @('GameModz.ps1','Engine.ps1','Process.Common.ps1','Safety.ps1','Recovery.Worker.ps1','SessionGuard.cs')){Assert (Test-Path (Join-Path $recoveryRoot $name)) ('Asset ausente: '+$name)}
 Remove-RecoveryRegistration
 Assert (-not (Get-ItemProperty $recoveryRunKey).PSObject.Properties['GameModzRecovery']) 'Registro nao removido.'
 Write-Output 'PASS: ativacao sem proprietario recusada; assets independentes; registro e remocao do login.'

 # Start the real guard, but the recovery backend is a disposable stub.
 $owner=Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile -Command "Start-Sleep -Seconds 120"' -PassThru
 $OwnerId=$owner.Id;$OwnerStarted=$owner.StartTime.ToUniversalTime().Ticks.ToString()
 Start-RecoveryGuard
 $guard=Get-Process -Id $script:guardIdentity.Id
 $stub=@'
param($Acao,[switch]$NaoInterativo,[switch]$RecoveryOnly,[switch]$ShutdownRecovery)
$base=Join-Path $env:LOCALAPPDATA 'GameModz'
Add-Content -LiteralPath (Join-Path $base 'called.txt') -Value ($Acao+':'+$RecoveryOnly+':'+$ShutdownRecovery)
Remove-Item -LiteralPath (Join-Path $base 'estado.json') -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $base 'estado.json.bak') -ErrorAction SilentlyContinue
'@
 Set-Content -LiteralPath (Join-Path $recoveryRoot 'GameModz.ps1') -Value $stub -Encoding UTF8
 $s=New-Snapshot;$s.Owner=[pscustomobject]@{Id=$OwnerId;Started=$OwnerStarted};Write-DurableState $s
 Start-Sleep -Milliseconds 700
 Assert (Get-StatePresent) 'Guard restaurou enquanto proprietario estava vivo.'
 $owner.Kill();$owner.WaitForExit();$owner.Dispose();$owner=$null
 Wait-Until {-not(Get-StatePresent)}
 Assert ((Get-Content (Join-Path $base 'called.txt') -Raw) -match 'Desativar:True:False') 'Recuperacao apos queda nao encaminhada.'
 Wait-Until {$guard.HasExited}
 Write-Output 'PASS: guard real confirmou inicializacao, preservou sessao viva e recuperou apos termino forcado do proprietario.'

 $s=New-Snapshot;$s.Owner=[pscustomobject]@{Id=$PID;Started='0'};Write-DurableState $s
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $recoveryRoot 'Recovery.Worker.ps1') -LoginRecovery
 Assert (-not(Get-StatePresent)) 'Login nao recuperou PID reutilizado.'
 Write-Output 'PASS: login recupera sessao orfa e rejeita PID com instante de criacao diferente.'

 $s=New-Snapshot;$s.Owner=[pscustomobject]@{Id=$PID;Started=([Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks.ToString())};Write-DurableState $s
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $recoveryRoot 'Recovery.Worker.ps1') -LoginRecovery
 Assert (Get-StatePresent) 'Login desfez sessao viva.'
 Write-Output 'PASS: recuperacao de login preserva sessao com proprietario vivo.'

 Add-Type -Path (Join-Path $PSScriptRoot 'SessionGuard.cs')
 [GMSessionGuard]::HostPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
 [GMSessionGuard]::BackendPath=Join-Path $recoveryRoot 'GameModz.ps1'
 [GMSessionGuard]::Install()
 $method=[GMSessionGuard].GetMethod('OnEnding',[Reflection.BindingFlags]'NonPublic,Static')
 $event=[Microsoft.Win32.SessionEndingEventArgs]::new([Microsoft.Win32.SessionEndReasons]::SystemShutdown)
 $method.Invoke($null,@($null,$event))|Out-Null
 Assert (-not(Get-StatePresent)) 'Callback de encerramento nao recuperou.'
 Assert (-not $event.Cancel) 'Protecao cancelou desligamento do Windows.'
 Assert ((Get-Content (Join-Path $base 'called.txt') -Raw) -match 'Desativar:True:True') 'Callback nao usou modo de desligamento.'
 [GMSessionGuard]::Uninstall()
 Write-Output 'PASS: callback real de encerramento chama backend em modo de desligamento e nunca cancela o Windows (sem desligar o computador).'
}finally{
 if($owner){if(-not $owner.HasExited){$owner.Kill()};$owner.Dispose()}
 if($guard){if(-not $guard.HasExited){$guard.Kill()};$guard.Dispose()}
 if(Test-Path $recoveryRunKey){Remove-Item -LiteralPath $recoveryRunKey -Force}
 $env:LOCALAPPDATA=$oldLocal
 $resolved=[IO.Path]::GetFullPath($testRoot)
 if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP)+[IO.Path]::DirectorySeparatorChar) -and (Split-Path $resolved -Leaf) -like 'GameModz-Safety-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
