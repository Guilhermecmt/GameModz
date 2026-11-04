foreach($name in @('NavChecklist','NavResources','ChecklistPage','ResourcesPage','ChecklistGrid','ChecklistHint','RetryItem','StepDetail','ResourceGrid','MonitorHint','ResourceDetail','LowerPriority','CloseSelectedApp')){Set-Variable -Name $name -Value $window.FindName($name)}
$script:reportStamp='';$script:monitorJob=$null;$script:monitorTime='';$script:monitorData=$null
$script:monitorBase=Join-Path $env:TEMP ('GameModz-Monitor-'+[guid]::NewGuid().ToString('N'))
$script:monitorFile=$script:monitorBase+'.json';$script:monitorMarker=$script:monitorBase+'.run'
$sessionReport=Join-Path $env:LOCALAPPDATA 'GameModz\checklist.json'
function Set-SessionPage([string]$page){
 if($page -eq 'Resources' -and $window.WindowState -ne 'Minimized' -and -not $Verificar -and -not $TestarCiclo){Start-ResourceMonitor}
 else{Stop-ResourceMonitor}
}
function Start-ResourceMonitor {
 if($script:monitorJob){return}
 $script:monitorTime='';$script:monitorData=$null
 Set-Content -LiteralPath $script:monitorMarker -Value 'run'
 $script:monitorJob=Start-Job -FilePath (Join-Path $root 'Monitor.Worker.ps1') -ArgumentList @($script:monitorFile,$script:monitorMarker,[Diagnostics.Process]::GetCurrentProcess().SessionId,$root)
 $MonitorHint.Text='Coletando amostras… CPU é normalizada pelo total de processadores lógicos.'
}
function Stop-ResourceMonitor {
 if($script:monitorJob){
  Remove-Item -LiteralPath $script:monitorMarker -ErrorAction SilentlyContinue
  Remove-Job $script:monitorJob -Force -ErrorAction SilentlyContinue;$script:monitorJob=$null
 }
 foreach($path in @($script:monitorMarker,$script:monitorFile,($script:monitorFile+'.tmp'))){Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
 $script:monitorData=$null
}
function Update-ResourceActions {
 $row=$ResourceGrid.SelectedItem
 $fresh=$script:monitorData -and ([DateTime]::UtcNow-[DateTime]::Parse($script:monitorData.Updated).ToUniversalTime()).TotalSeconds -lt 8
 $canChange=$script:active
 if($canChange){try{$canChange=(Get-Content $stateFile -Raw|ConvertFrom-Json).Mode -ne 'Restoring'}catch{$canChange=$false}}
 $eligible=$null -ne $row -and $row.Eligible -and $fresh -and $canChange -and -not $script:worker
 $LowerPriority.IsEnabled=$eligible;$CloseSelectedApp.IsEnabled=$eligible
 if($row){
  if(-not $row.Eligible){$ResourceDetail.Text='Somente leitura: aplicativo protegido, não compatível ou em primeiro plano.'}
  elseif(-not $canChange){$ResourceDetail.Text='Ative o modo de jogo ou conclua a restauração pendente para usar ações.'}
  else{$ResourceDetail.Text='Ação manual. Prioridade abaixo do normal é restaurada ao desligar; fechamento não é forçado.'}
 }
}
function Update-Resources {
 if($script:page -ne 'Resources'){return}
 if($script:monitorJob -and $script:monitorJob.State -in @('Failed','Stopped','Completed')){
  $MonitorHint.Text='Monitor interrompido. Troque de página e volte para reiniciar.';Update-ResourceActions;return
 }
 if(Test-Path $script:monitorFile){
  try{
   $data=Get-Content $script:monitorFile -Raw|ConvertFrom-Json
   if($data.Updated -ne $script:monitorTime){
    $selected=if($ResourceGrid.SelectedItem){$ResourceGrid.SelectedItem.Name}else{''}
    $script:monitorData=$data;$script:monitorTime=$data.Updated
    $ResourceGrid.ItemsSource=@($data.Rows)
    if($selected){$ResourceGrid.SelectedItem=@($data.Rows|Where-Object Name -eq $selected)|Select-Object -First 1}
    $MonitorHint.Text=if($data.Error){$data.Error}else{'Amostras a cada 2 s • Alerta após 3 amostras com CPU ≥ 5% ou RAM ≥ 512 MB. RAM aproximada; não é memória exclusiva. Nenhuma ação automática.'}
   }
  }catch{} # Leitura concorrente: mantém a última amostra até a próxima atualização.
 }
 Update-ResourceActions
}
function Update-Checklist {
 $stamp=if(Test-Path $sessionReport){(Get-Item $sessionReport).LastWriteTimeUtc.Ticks.ToString()}else{''}
 if($stamp -ne $script:reportStamp){
  try{
   $report=Get-Content $sessionReport -Raw|ConvertFrom-Json
   $script:reportStamp=$stamp
   $selected=$ChecklistGrid.SelectedItem
   $ChecklistGrid.ItemsSource=@($report.Steps)
   if($selected){$ChecklistGrid.SelectedItem=$report.Steps|Where-Object {$_.Id -eq $selected.Id -and $_.Phase -eq $selected.Phase}|Select-Object -First 1}
   $ChecklistHint.Text='Resultados registrados em '+([DateTime]::Parse($report.Updated).ToString('dd/MM HH:mm:ss'))
  }catch{}
 }
 elseif(-not $stamp -and -not $ChecklistGrid.ItemsSource){
  $ChecklistHint.Text=if(Test-Path $stateFile){'Sessão anterior: use Restaurar para acompanhar o retorno dos ajustes.'}else{'Ative o modo de jogo para acompanhar o checklist.'}
  if(Test-Path $stateFile){
   try{
    $legacy=Get-Content $stateFile -Raw|ConvertFrom-Json
    $labels=@{Wallpaper='Papel de parede';Effects='Efeitos visuais';Transparency='Transparência';OneDrive='OneDrive';Power='Plano de energia legado'}
    $ChecklistGrid.ItemsSource=@(foreach($pending in $legacy.Pending.PSObject.Properties){if($pending.Value){[pscustomobject]@{Id=$pending.Name;Name=$labels[$pending.Name];Status='Estado salvo anterior';Detail='Preferencia anterior registrada. Use Desativar e restaurar.';Phase='Anterior';Retryable=$false}}})
   }catch{}
  }
 }
 $row=$ChecklistGrid.SelectedItem;$canRetry=$false
 if($row -and $row.Retryable -and -not $script:worker -and (Test-Path $stateFile)){
  try{$saved=Get-Content $stateFile -Raw|ConvertFrom-Json;$phase=if($saved.Mode -eq 'Restoring'){'Restaurar'}else{'Ativar'};$canRetry=$row.Phase -eq $phase}catch{}
 }
 $RetryItem.IsEnabled=$canRetry
}
$NavChecklist.Add_Click({Show-Page Checklist});$NavResources.Add_Click({Show-Page Resources})
$ChecklistGrid.Add_SelectionChanged({$row=$ChecklistGrid.SelectedItem;if($row){$StepDetail.Text=$row.Detail};Update-Checklist})
$RetryItem.Add_Click({
 try{$row=$ChecklistGrid.SelectedItem;if($row){Run-Action 'TentarNovamente' ("-Item '"+$row.Id.Replace("'","''")+"'")}}catch{$Log.Text=$_.ToString()}
})
$ResourceGrid.Add_SelectionChanged({Update-ResourceActions})
function Run-SelectedProcessAction([string]$action){
 $row=$ResourceGrid.SelectedItem
 if(-not $row -or -not $row.Eligible -or $script:worker){return}
 if($action -eq 'FecharProcesso' -and [Windows.MessageBox]::Show('Salve seu trabalho antes de continuar. Solicitar o fechamento de '+$row.Name+'?','Fechar aplicativo','OKCancel','Information') -ne 'OK'){return}
 $path=Join-Path $env:TEMP ('GameModz-Target-'+[guid]::NewGuid().ToString('N')+'.json')
 @($row.Targets)|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $path -Encoding UTF8
 $script:targetFile=$path
 Run-Action $action ("-AlvoFile '"+$path.Replace("'","''")+"'")
}
$LowerPriority.Add_Click({try{Run-SelectedProcessAction 'ReduzirPrioridade'}catch{$Log.Text=$_.ToString()}})
$CloseSelectedApp.Add_Click({try{Run-SelectedProcessAction 'FecharProcesso'}catch{$Log.Text=$_.ToString()}})
$window.Add_StateChanged({if($window.WindowState -eq 'Minimized'){Stop-ResourceMonitor}elseif($script:page -eq 'Resources'){Start-ResourceMonitor}})
$window.Add_Closed({Stop-ResourceMonitor})
Update-Checklist
