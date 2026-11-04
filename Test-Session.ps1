$ErrorActionPreference='Stop'
$testRoot=Join-Path $env:TEMP ('GameModz-EngineTest-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot|Out-Null
$base=$testRoot;$stateFile=Join-Path $base 'estado.json'
$NaoInterativo=$true;$ReabrirApps=$false
function Save-State($s){$s|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $stateFile -Encoding UTF8}
function Wallpaper($path){$script:wallCalls++;if($script:wallFails){throw 'Falha de wallpaper simulada'}}
function Effects($value){$script:effectCalls++}
function Set-TransparencyValue($key,$value){$script:transCalls++}
function New-TestState {
 [pscustomobject]@{Mode='Active';Wallpaper='original.bmp';Effects=$true;TransparencyExists=$true;Transparency=1;Power='';OneDrive=$null;SyncRequested=$false;ClosedApps=@();AppTargets=@();Priorities=@();Pending=[pscustomobject]@{Wallpaper=$false;Effects=$false;Transparency=$false;Power=$false;OneDrive=$false}}
}
. (Join-Path $PSScriptRoot 'Engine.ps1')
$fixture=$null
try {
 $script:wallCalls=0;$script:effectCalls=0;$script:wallFails=$true
 $s=New-TestState;Save-State $s
 Apply-One $s Wallpaper;Apply-One $s Effects
 $report=Get-Content $reportFile -Raw|ConvertFrom-Json
 if(($report.Steps|Where-Object Id -eq Wallpaper).Status -ne 'Falhou'){throw 'Falha nao registrada.'}
 $script:wallFails=$false;Retry-Step Wallpaper
 $loaded=Read-State
 if($script:wallCalls -ne 2 -or $script:effectCalls -ne 1 -or $loaded.Wallpaper -ne 'original.bmp'){throw 'Repeticao refez outra etapa ou perdeu snapshot.'}
 Write-Output 'PASS: repeticao isolada preserva snapshot e nao refaz etapas concluidas.'
 $script:wallFails=$true;Restore
 if(-not(Test-Path $stateFile)){throw 'Restauracao com falha perdeu estado.'}
 $loaded=Read-State
 if(-not $loaded.Pending.Wallpaper -or $loaded.Pending.Effects){throw 'Pendencias de restauracao incorretas.'}
 $script:wallFails=$false;Retry-Step Wallpaper
 if(Test-Path $stateFile){throw 'Restauracao nao finalizou apos repeticao.'}
 Write-Output 'PASS: restauracao parcial preserva estado e finaliza ao repetir somente a falha.'
 $source=Join-Path $testRoot 'fixture.cs';$exe=Join-Path $testRoot 'wallpaper64.exe'
 Set-Content $source 'class Fixture { static void Main() { System.Threading.Thread.Sleep(45000); } }'
 $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
 & $compiler /nologo /target:winexe ('/out:'+$exe) $source
 if($LASTEXITCODE -ne 0){throw 'Falha ao criar fixture.'}
 $fixture=Start-Process -FilePath $exe -PassThru
 Start-Sleep -Milliseconds 200
 $identity=Get-ProcessIdentity $fixture
 $target=Join-Path $testRoot 'target.json';@($identity)|ConvertTo-Json|Set-Content $target
 $original=$fixture.PriorityClass.ToString()
 Save-State (New-TestState)
 Invoke-ProcessAction ReduzirPrioridade $target
 $fixture.Refresh()
 if($fixture.PriorityClass.ToString() -ne 'BelowNormal'){throw 'Prioridade nao reduzida no processo de teste.'}
 $s=Read-State
 if(@($s.Priorities).Count -ne 1 -or $s.Priorities[0].Original -ne $original){throw 'Prioridade original nao registrada.'}
 Invoke-ProcessAction ReduzirPrioridade $target
 if(@((Read-State).Priorities).Count -ne 1){throw 'Snapshot de prioridade foi duplicado.'}
 Restore
 $fixture.Refresh()
 if($fixture.PriorityClass.ToString() -ne $original){throw 'Prioridade original nao restaurada.'}
 $wrong=[pscustomobject]@{Id=$identity.Id;Started='0';Path=$identity.Path;Name=$identity.Name}
 if(Get-VerifiedProcess $wrong -ForAction){throw 'Identidade de processo incorreta aceita.'}
 $self=Get-ProcessIdentity ([Diagnostics.Process]::GetCurrentProcess())
 $blocked=$false
 try{$candidate=Get-VerifiedProcess $self -ForAction}catch{$blocked=$true}
 if(-not $blocked){throw 'Processo protegido aceito.'}
 Write-Output 'PASS: prioridade real reduzida/restaurada em fixture; snapshot unico; identidade incorreta e processo protegido recusados.'
 Save-State (New-TestState);Invoke-ProcessAction ReduzirPrioridade $target
 $fixture.PriorityClass=[Diagnostics.ProcessPriorityClass]::Idle
 Restore;$fixture.Refresh()
 if($fixture.PriorityClass -ne [Diagnostics.ProcessPriorityClass]::Idle){throw 'Escolha posterior de prioridade foi sobrescrita.'}
 Write-Output 'PASS: restauracao preserva alteracao de prioridade feita depois da acao.'
 $legacy=New-TestState
 $legacy.PSObject.Properties.Remove('Priorities');$legacy.PSObject.Properties.Remove('AppTargets');$legacy.PSObject.Properties.Remove('Mode')
 Save-State $legacy
 $migrated=Read-State
 if(@($migrated.Priorities).Count -ne 0 -or @($migrated.AppTargets).Count -ne 0 -or $migrated.Mode -ne 'Active'){throw 'Migracao de estado antigo incorreta.'}
 Restore
 Write-Output 'PASS: estados antigos continuam restauraveis.'
 # Ativacao completa com efeitos nativos simulados; Windows real permanece intacto.
 Add-Type @'
public class GMNative {
 public static bool GetBool(uint a,uint b,ref int c,uint d){c=1;return true;}
}
'@
 $PausarOneDrive=$false;$FecharApps=@();$script:transCalls=0
 Activate
 $report=Get-Content $reportFile -Raw|ConvertFrom-Json
 if(@($report.Steps).Count -ne 5 -or ($report.Steps|Where-Object Id -eq Wallpaper).Name -ne 'Fundo preto'){throw 'Checklist completo incorreto.'}
 if($script:transCalls -ne 1 -or (Read-State).Pending.Power){throw 'Ativacao alterou plano ou nao aplicou transparencia simulada.'}
 Restore
 if(Test-Path $stateFile){throw 'Ciclo completo nao restaurado.'}
 Write-Output 'PASS: ciclo completo com ajustes nativos simulados e checklist por etapa, sem trocar plano de energia.'
} finally {
 if($fixture){try{if(-not $fixture.HasExited){$fixture.Kill();$fixture.WaitForExit(2000)|Out-Null}}finally{$fixture.Dispose()}}
 Get-ChildItem -LiteralPath $testRoot -File|Remove-Item -Force
 Remove-Item -LiteralPath $testRoot
}
