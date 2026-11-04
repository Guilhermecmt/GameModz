. (Join-Path $PSScriptRoot 'Process.Common.ps1')
$reportFile=Join-Path $base 'checklist.json'
function Write-JsonAtomic($Value,[string]$Path) {
 $Value|ConvertTo-Json -Depth 12|Set-Content -LiteralPath ($Path+'.tmp') -Encoding UTF8
 Move-Item -LiteralPath ($Path+'.tmp') -Destination $Path -Force
}
function Set-Step([string]$Id,[string]$Name,[string]$Status,[string]$Detail='', [string]$Phase='Ativar',[bool]$Retryable=$false) {
 $report=if(Test-Path $reportFile){Get-Content $reportFile -Raw|ConvertFrom-Json}else{[pscustomobject]@{Updated='';Steps=@()}}
 $step=@($report.Steps|Where-Object {$_.Id -eq $Id -and $_.Phase -eq $Phase})|Select-Object -First 1
 if(-not $step){$step=[pscustomobject]@{Id=$Id;Name=$Name;Status=$Status;Detail=$Detail;Phase=$Phase;Retryable=$Retryable};$report.Steps=@($report.Steps)+$step}
 $step.Name=$Name;$step.Status=$Status;$step.Detail=$Detail;$step.Retryable=$Retryable
 $report.Updated=(Get-Date).ToString('o');Write-JsonAtomic $report $reportFile
 Write-Host "$Name - $Status. $Detail"
}
function Read-State {
 if(-not(Test-Path $stateFile)){throw 'Ative o modo de jogo antes desta acao.'}
 $s=Get-Content $stateFile -Raw|ConvertFrom-Json
 foreach($name in @('Priorities','AppTargets')){if(-not $s.PSObject.Properties[$name]){$s|Add-Member -NotePropertyName $name -NotePropertyValue @()}}
 if(-not $s.PSObject.Properties['Mode']){$s|Add-Member NoteProperty Mode 'Active'}
 if(-not $s.PSObject.Properties['SyncRequested']){$s|Add-Member NoteProperty SyncRequested $false}
 return $s
}
function Close-Targets($s,$Targets,[string]$StepId,[string]$Title) {
 $failures=@();$closed=0
 foreach($identity in @($Targets)){
  $process=$null
  try{
   $process=Get-VerifiedProcess $identity -ForAction
   if(-not $process){continue}
   if($process.MainWindowHandle -eq 0){continue}
   if(-not $process.CloseMainWindow()){throw 'O aplicativo recusou o pedido de fechamento.'}
   if(-not $process.WaitForExit(2000)){throw 'O aplicativo nao encerrou; pode haver trabalho nao salvo.'}
   if(-not @($s.ClosedApps|Where-Object {$_.Path -ieq $identity.Path}).Count){$s.ClosedApps=@($s.ClosedApps)+[pscustomobject]@{Path=$identity.Path}}
   Save-State $s;$closed++
  }catch{$failures+= $_.Exception.Message}finally{if($process){$process.Dispose()}}
 }
 if($failures.Count){Set-Step $StepId $Title 'Não respondeu' ($failures -join ' ') 'Ativar' $true}
 elseif($closed){Set-Step $StepId $Title 'Aplicada' "$closed janela(s) encerrada(s), sem forcar."}
 else{Set-Step $StepId $Title 'Ignorada' 'Nenhuma janela elegivel; processos residentes podem continuar ativos.'}
}
function Apply-One($s,[string]$Id) {
 $titles=@{Wallpaper='Fundo preto';Effects='Efeitos visuais';Transparency='Transparência';OneDrive='OneDrive'}
 if($Id -like 'Close.*'){
  $entry=$s.AppTargets|Where-Object {$_.Id -eq $Id}|Select-Object -First 1
  if(-not $entry){throw 'Item nao pertence a esta sessao.'}
  Set-Step $Id $entry.Name 'Aplicando';Close-Targets $s $entry.Targets $Id $entry.Name;return
 }
 if(-not $titles.ContainsKey($Id)){throw 'Item de checklist invalido.'}
 $title=$titles[$Id];Set-Step $Id $title 'Aplicando'
 try{
  switch($Id){
   Wallpaper {$s.Pending.Wallpaper=$true;Save-State $s;Wallpaper (Join-Path $base 'preto.bmp')}
   Effects {$s.Pending.Effects=$true;Save-State $s;Effects $false}
   Transparency {$s.Pending.Transparency=$true;Save-State $s;Set-TransparencyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 0}
   OneDrive {
    if(-not $s.SyncRequested){Set-Step $Id $title 'Ignorada' 'Opcao nao selecionada.';return}
    if(-not $s.OneDrive){
     if($s.OneDriveWasRunning){throw 'O caminho do OneDrive nao estava acessivel. Nenhum encerramento foi feito.'}
     Set-Step $Id $title 'Ignorada' 'Nao estava em execucao ao ativar.';return
    }
    $s.Pending.OneDrive=$true;Save-State $s
    $od=Get-Process OneDrive -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq [Diagnostics.Process]::GetCurrentProcess().SessionId -and $_.Path -ieq $s.OneDrive}|Select-Object -First 1
    if($od -and -not(Request-OneDriveShutdown $s.OneDrive $od.Id)){
     Set-Step $Id $title 'Não respondeu' 'Sem confirmacao em 5 segundos; os demais ajustes continuam.' 'Ativar' $true;return
    }
   }
  }
  Set-Step $Id $title 'Aplicada' 'Estado anterior salvo para restauracao.'
 }catch{Set-Step $Id $title 'Falhou' $_.Exception.Message 'Ativar' $true}
}
function Activate {
 if(Test-Path $stateFile){throw 'Existe estado salvo. Restaure antes de ativar novamente.'}
 $effects=0;if(-not[GMNative]::GetBool(0x103E,0,[ref]$effects,0)){throw 'Nao foi possivel ler os efeitos atuais.'}
 $trans=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue
 $wall=(Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallPaper
 if($wall -and -not(Test-Path -LiteralPath $wall)){throw 'Papel de parede atual inacessivel; restauracao nao pode ser garantida.'}
 $od=if($PausarOneDrive){Get-Process OneDrive -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq [Diagnostics.Process]::GetCurrentProcess().SessionId}|Select-Object -First 1}else{$null}
 $s=[pscustomobject]@{
  Created=(Get-Date).ToString('o');Mode='Active';Wallpaper=[string]$wall;Effects=$effects
  TransparencyExists=($null -ne $trans -and $null -ne $trans.PSObject.Properties['EnableTransparency']);Transparency=$trans.EnableTransparency
  Power='';OneDrive=if($od){$od.Path}else{$null};OneDriveWasRunning=($null -ne $od);SyncRequested=[bool]$PausarOneDrive;ClosedApps=@();AppTargets=@();Priorities=@()
  Pending=[pscustomobject]@{Wallpaper=$false;Effects=$false;Transparency=$false;Power=$false;OneDrive=$false}
 }
 foreach($name in $FecharApps){
  $name=$name -replace '\.exe$',''
  if($name -notin (Get-ActionAllowlist)){continue}
  $targets=@(Get-Process -Name $name -ErrorAction SilentlyContinue|Where-Object {$_.MainWindowHandle -ne 0}|ForEach-Object {try{Get-ProcessIdentity $_}catch{}})
  $s.AppTargets+= [pscustomobject]@{Id="Close.$name";Name="Fechar $name";Targets=$targets}
 }
 Add-Type -AssemblyName System.Drawing
 $bmp=New-Object Drawing.Bitmap 8,8;$g=[Drawing.Graphics]::FromImage($bmp)
 try{$g.Clear([Drawing.Color]::Black);$bmp.Save((Join-Path $base 'preto.bmp'),[Drawing.Imaging.ImageFormat]::Bmp)}finally{$g.Dispose();$bmp.Dispose()}
 Save-State $s
 Write-JsonAtomic ([pscustomobject]@{Updated=(Get-Date).ToString('o');Steps=@()}) $reportFile
 foreach($id in @('Wallpaper','Effects','Transparency','OneDrive')){Set-Step $id $id 'Aguardando'}
 foreach($app in $s.AppTargets){Set-Step $app.Id $app.Name 'Aguardando'}
 foreach($id in @('Wallpaper','Effects','Transparency','OneDrive')){Apply-One $s $id}
 foreach($app in $s.AppTargets){Apply-One $s $app.Id}
 Set-Step 'Display' 'Brilho e tema' 'Preservados' 'Plano de energia e preferencias de tema mantidos.'
 Write-Host 'Preparacao concluida. Confira o checklist; itens com falha podem ser repetidos individualmente.'
}
function Restore-One($s,[string]$Id) {
 $title=switch -Wildcard ($Id){'Priority.*'{'Prioridade do aplicativo'};'Reopen.*'{'Reabrir aplicativo'};'Wallpaper'{'Papel de parede'};'Effects'{'Efeitos visuais'};'Transparency'{'Transparência'};default{$Id}}
 $detail='Preferencia anterior restaurada.'
 Set-Step $Id $title 'Restaurando' '' 'Restaurar'
 try{
  switch -Wildcard ($Id){
   'Wallpaper' {Wallpaper $s.Wallpaper;$s.Pending.Wallpaper=$false}
   'Effects' {Effects ([bool]$s.Effects);$s.Pending.Effects=$false}
   'Transparency' {
    $key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if($s.TransparencyExists){Set-TransparencyValue $key ([int]$s.Transparency)}
    else{Remove-ItemProperty -Path $key -Name EnableTransparency -ErrorAction SilentlyContinue}
    $s.Pending.Transparency=$false
   }
   'Power' {& powercfg.exe /setactive $s.Power;if($LASTEXITCODE -ne 0){throw 'Falha ao restaurar plano legado.'};$s.Pending.Power=$false}
   'OneDrive' {
    Start-Process -FilePath $s.OneDrive -ArgumentList '/background'
    $watch=[Diagnostics.Stopwatch]::StartNew();$confirmed=$false
    while($watch.ElapsedMilliseconds -lt 5000){
     $running=Get-Process OneDrive -ErrorAction SilentlyContinue|Where-Object {$_.SessionId -eq [Diagnostics.Process]::GetCurrentProcess().SessionId -and $_.Path -ieq $s.OneDrive}|Select-Object -First 1
     if($running){$confirmed=$true;$running.Dispose();break}
     Start-Sleep -Milliseconds 150
    }
    if(-not $confirmed){throw 'O OneDrive nao confirmou abertura em 5 segundos. Tente novamente pelo checklist.'}
    $s.Pending.OneDrive=$false
    $detail='OneDrive aberto. A sincronizacao e gerenciada pelo proprio aplicativo.'
   }
   'Priority.*' {
    $entry=$s.Priorities|Where-Object {$_.Key -eq $Id}|Select-Object -First 1
    if(-not $entry){throw 'Registro de prioridade nao encontrado.'}
    $p=Get-VerifiedProcess $entry.Identity
    if($p){try{if($p.PriorityClass.ToString() -eq 'BelowNormal'){$p.PriorityClass=[Enum]::Parse([Diagnostics.ProcessPriorityClass],$entry.Original)}else{$detail='A prioridade foi alterada depois do GameModz; essa escolha foi preservada.'}}finally{$p.Dispose()}}
    else{$detail='O processo original encerrou. Nenhum outro processo foi modificado.'}
    $s.Priorities=@($s.Priorities|Where-Object {$_.Key -ne $Id})
   }
   'Reopen.*' {
    $index=[int]$Id.Substring(7);$entry=$s.ClosedApps|Where-Object {$_.Key -eq $Id}|Select-Object -First 1
    if($entry){Start-Process -FilePath $entry.Path;$s.ClosedApps=@($s.ClosedApps|Where-Object {$_.Key -ne $Id});$detail='Abertura solicitada. Abas e documentos dependem do aplicativo.'}
   }
   default {throw 'Item de restauracao invalido.'}
  }
  Save-State $s;Set-Step $Id $title 'Restaurada' $detail 'Restaurar'
 }catch{Set-Step $Id $title 'Falhou' $_.Exception.Message 'Restaurar' $true}
}
function Complete-Restore($s) {
 $pending=@($s.Pending.PSObject.Properties|Where-Object {$_.Value -eq $true}).Count -gt 0
 if(-not $pending -and @($s.Priorities).Count -eq 0 -and @($s.ClosedApps).Count -eq 0){Remove-Item -LiteralPath $stateFile;Write-Host 'Restauracao concluida.'}
 else{Write-Warning 'Existem itens pendentes. Use o checklist para repetir apenas o item que falhou.'}
}
function Restore {
 if(-not(Test-Path $stateFile)){Write-Host 'Nenhuma restauracao pendente.';return}
 $s=Read-State;$s.Mode='Restoring';Save-State $s
 foreach($id in @('Wallpaper','Effects','Transparency','Power','OneDrive')){if($s.Pending.$id){Restore-One $s $id}}
 foreach($entry in @($s.Priorities)){Restore-One $s $entry.Key}
 $reopen=$ReabrirApps
 if(-not $NaoInterativo -and @($s.ClosedApps).Count){$reopen=(Read-Host 'Reabrir aplicativos fechados? [s/N]') -eq 's'}
 if($reopen){
  $index=0;foreach($entry in @($s.ClosedApps)){if(-not $entry.PSObject.Properties['Key']){$entry|Add-Member NoteProperty Key ('Reopen.'+$index)};$index++}
  Save-State $s
  foreach($entry in @($s.ClosedApps)){Restore-One $s $entry.Key}
 }else{$s.ClosedApps=@();Save-State $s}
 Complete-Restore $s
}
function Retry-Step([string]$Id) {
 $s=Read-State
 $report=Get-Content $reportFile -Raw|ConvertFrom-Json
 $phase=if($s.Mode -eq 'Restoring'){'Restaurar'}else{'Ativar'}
 $entry=$report.Steps|Where-Object {$_.Id -eq $Id -and $_.Phase -eq $phase -and $_.Retryable}|Select-Object -First 1
 if(-not $entry){throw 'Este item nao permite repeticao nesta fase.'}
 if($phase -eq 'Restaurar'){Restore-One $s $Id;Complete-Restore $s}
 elseif($Id -like 'Priority.*'){
  $request=$s.AppTargets|Where-Object {$_.Id -eq $Id}|Select-Object -First 1
  if(-not $request){throw 'Selecao original indisponivel.'}
  $path=Join-Path $base ('retry-'+[guid]::NewGuid().ToString('N')+'.json')
  try{Write-JsonAtomic @($request.Targets) $path;Invoke-ProcessAction 'ReduzirPrioridade' $path}finally{Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
 }else{Apply-One $s $Id}
}
function Invoke-ProcessAction([string]$Action,[string]$TargetFile) {
 $s=Read-State;if($s.Mode -ne 'Active'){throw 'Conclua a restauracao antes de alterar aplicativos.'}
 $targets=@(Get-Content -LiteralPath $TargetFile -Raw|ConvertFrom-Json)
 if(-not $targets.Count -or $targets.Count -gt 200){throw 'Selecao invalida.'}
 if($Action -eq 'FecharProcesso'){
  $stepId='Close.'+$targets[0].Name
  $s.AppTargets=@($s.AppTargets|Where-Object {$_.Id -ne $stepId})+[pscustomobject]@{Id=$stepId;Name=('Fechar '+$targets[0].Name);Targets=$targets};Save-State $s
  Close-Targets $s $targets $stepId ('Fechar '+$targets[0].Name);return
 }
 foreach($identity in $targets){
  $key='Priority.'+$identity.Id+'.'+$identity.Started;$p=$null
  $s.AppTargets=@($s.AppTargets|Where-Object {$_.Id -ne $key})+[pscustomobject]@{Id=$key;Name=$identity.Name;Targets=@($identity)};Save-State $s
  try{
   $p=Get-VerifiedProcess $identity -ForAction
   if(-not $p){Set-Step $key $identity.Name 'Ignorada' 'O processo ja encerrou.';continue}
   if($p.PriorityClass.ToString() -notin @('Normal','BelowNormal')){throw 'Prioridade especial preservada; acao nao aplicada.'}
   if($p.PriorityClass.ToString() -eq 'BelowNormal' -and -not @($s.Priorities|Where-Object {$_.Key -eq $key}).Count){
    Set-Step $key ('Prioridade: '+$identity.Name) 'Ignorada' 'Ja estava abaixo do normal antes do GameModz; nenhuma alteracao.';continue
   }
   if($p.PriorityClass.ToString() -eq 'Normal'){
    if(-not @($s.Priorities|Where-Object {$_.Key -eq $key}).Count){$s.Priorities=@($s.Priorities)+[pscustomobject]@{Key=$key;Identity=$identity;Original=$p.PriorityClass.ToString()};Save-State $s}
    $p.PriorityClass=[Diagnostics.ProcessPriorityClass]::BelowNormal
   }
   Set-Step $key ('Prioridade: '+$identity.Name) 'Aplicada' 'Abaixo do normal; restauracao registrada.'
  }catch{Set-Step $key ('Prioridade: '+$identity.Name) 'Falhou' $_.Exception.Message 'Ativar' $true}
  finally{if($p){$p.Dispose()}}
 }
}
