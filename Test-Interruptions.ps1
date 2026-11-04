$ErrorActionPreference='Stop'
$testRoot=Join-Path $env:TEMP ('GameModz-Interruptions-'+[guid]::NewGuid().ToString('N'))
$previousLocal=$env:LOCALAPPDATA
New-Item -ItemType Directory -Path $testRoot|Out-Null
function Assert($condition,$message){if(-not $condition){throw $message}}
try{
 $env:LOCALAPPDATA=Join-Path $testRoot 'profile'
 $data=Join-Path $env:LOCALAPPDATA 'GameModz'
 New-Item -ItemType Directory -Path $data -Force|Out-Null
 $workerRoot=Join-Path $testRoot 'worker';New-Item -ItemType Directory -Path $workerRoot|Out-Null
 foreach($file in @('Recovery.Worker.ps1','SessionGuard.cs')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $workerRoot}
 $stub=@'
$base=Join-Path $env:LOCALAPPDATA 'GameModz'
$counter=Join-Path $base 'attempts.txt'
Add-Content -LiteralPath $counter -Value 'attempt'
if((Test-Path (Join-Path $base 'always-fail')) -or @(Get-Content $counter).Count -lt 2){throw 'Simulated transient failure'}
Remove-Item -LiteralPath (Join-Path $base 'estado.json')
'@
 Set-Content -LiteralPath (Join-Path $workerRoot 'GameModz.ps1') -Value $stub -Encoding UTF8
 Set-Content -LiteralPath (Join-Path $data 'estado.json') -Value '{}'
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $workerRoot 'Recovery.Worker.ps1') -LoginRecovery
 Assert (@(Get-Content (Join-Path $data 'attempts.txt')).Count -eq 2) 'Falha transitoria nao foi repetida.'
 Assert (-not(Test-Path (Join-Path $data 'estado.json'))) 'Segunda tentativa nao recuperou estado.'
 Write-Output 'PASS: erro real no stderr da primeira tentativa nao impede sucesso na segunda.'
 Remove-Item -LiteralPath (Join-Path $data 'attempts.txt')
 Set-Content -LiteralPath (Join-Path $data 'always-fail') -Value 'test'
 Set-Content -LiteralPath (Join-Path $data 'estado.json') -Value '{}'
 & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $workerRoot 'Recovery.Worker.ps1') -LoginRecovery
 Assert (@(Get-Content (Join-Path $data 'attempts.txt')).Count -eq 3) 'Nao executou exatamente tres tentativas.'
 Assert (Test-Path (Join-Path $data 'estado.json')) 'Falhas perderam snapshot.'
 Remove-Item -LiteralPath (Join-Path $data 'estado.json')
 Write-Output 'PASS: falha persistente executa tres tentativas e preserva snapshot.'
 $desktop=Join-Path $testRoot 'desktop';$menu=Join-Path $testRoot 'menu'
 & (Join-Path $PSScriptRoot 'Install.ps1') -SourcePath $PSScriptRoot -DesktopDirectory $desktop -StartMenuDirectory $menu
 . (Join-Path $PSScriptRoot 'Installer.Common.ps1')
 $original=Get-Content -LiteralPath (Join-Path $script:installDirectory $script:installMarker) -Raw
 $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Install.ps1'))
 foreach($point in @('BeforePromotion','AfterPromotion','ViaInstaller')){
  $needle=if($point -ne 'AfterPromotion'){' [void](Assert-ManagedDirectory $stage);Move-Item -LiteralPath $stage -Destination $script:installDirectory;'}else{' $exe=Join-Path $script:installDirectory ''GameModz.exe'''}
  Assert ($source.Contains($needle)) 'Ponto de interrupcao nao encontrado.'
  $injected=$source.Replace($needle,(' [Environment]::Exit(23)'+[Environment]::NewLine+$needle))
  $scriptFile=Join-Path $testRoot 'Interrupted-Install.ps1';[IO.File]::WriteAllText($scriptFile,$injected,[Text.UTF8Encoding]::new($true))
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptFile -SourcePath $PSScriptRoot -DesktopDirectory $desktop -StartMenuDirectory $menu
  Assert ($LASTEXITCODE -eq 23) 'Instalador nao foi interrompido no ponto esperado.'
  Assert (Test-Path $script:transactionPath) 'Registro persistente nao sobreviveu.'
  if($point -eq 'ViaInstaller'){
   & (Join-Path $PSScriptRoot 'Install.ps1') -SourcePath $PSScriptRoot -DesktopDirectory $desktop -StartMenuDirectory $menu
   Assert (Test-Path (Join-Path $script:installDirectory 'GameModz.exe')) 'Nova execucao nao recuperou aplicativo.'
   Assert (-not(Test-Path $script:transactionPath)) 'Nova execucao nao concluiu registro.'
   Write-Output 'PASS: nova execucao do instalador recupera interrupcao automaticamente e conclui atualizacao.'
   continue
  }
  Enter-InstallLock
  try{Repair-InstallTransaction;Repair-InstallTransaction}finally{Exit-InstallLock}
  Assert ((Get-Content -LiteralPath (Join-Path $script:installDirectory $script:installMarker) -Raw) -ceq $original) 'Instalacao original nao recuperada.'
  Assert (-not(Test-Path $script:transactionPath)) 'Registro nao foi finalizado.'
  Assert (@(Get-ChildItem $script:installParent -Directory).Count -eq 1) 'Staging ou backup abandonado.'
  Write-Output ('PASS: encerramento forcado '+$point+' recupera instalacao original; repeticao e segura.')
 }
 & (Join-Path $PSScriptRoot 'Install.ps1') -SourcePath $PSScriptRoot -DesktopDirectory $desktop -StartMenuDirectory $menu
 Write-Output 'PASS: instalador continua utilizavel depois da recuperacao.'
}finally{
 $env:LOCALAPPDATA=$previousLocal
 $full=[IO.Path]::GetFullPath($testRoot)
 if((Split-Path $full -Parent) -ieq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') -and (Split-Path $full -Leaf) -match '^GameModz-Interruptions-[a-f0-9]{32}$'){Remove-Item -LiteralPath $full -Recurse -Force}
}
