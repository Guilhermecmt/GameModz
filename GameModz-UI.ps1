param([switch]$Verificar,[switch]$TestarCiclo)
$ErrorActionPreference='Stop'
$uiMutexName='Global\GameModzInterface-'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$script:uiMutex=New-Object Threading.Mutex($false,$uiMutexName)
try{$uiLocked=$script:uiMutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$uiLocked=$true}
if(-not $uiLocked){$script:uiMutex.Dispose();return}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type @'
using System.Runtime.InteropServices;
public class GMAppIdentity {
 [DllImport("shell32.dll",CharSet=CharSet.Unicode)]
 public static extern int SetCurrentProcessExplicitAppUserModelID(string id);
}
'@
[void][GMAppIdentity]::SetCurrentProcessExplicitAppUserModelID('GameModz.Desktop')
$root=$PSScriptRoot
[xml]$xaml=[IO.File]::ReadAllText((Join-Path $root 'Interface.xaml'))
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$names=@('Badge','Headline','MainAction','HeroHint','Power','Sync','Chrome','Edge','Discord','Spotify','Reopen','Motion','Log','StateLabel','PageTitle','PageSubtitle','NavOverview','NavSettings','NavIdeas','Explore','OverviewPage','SettingsPage','IdeasPage','IdeasList','PageHost','CpuInfo','GpuInfo','RamInfo')
foreach($n in $names){Set-Variable -Name $n -Value $window.FindName($n)}
$powerArt=Join-Path $root 'assets\power-core.png'
if(Test-Path $powerArt){
 $source=[Windows.Media.Imaging.BitmapImage]::new([uri]$powerArt)
 $window.Icon=$source
}
$stateFile=Join-Path $env:LOCALAPPDATA 'GameModz\estado.json'
$script:worker=$null
$script:closeAfterRestore=$false
$script:active=$false
$script:logPath=$null
$script:resultPath=$null
$script:backendPath=Join-Path $root 'GameModz.ps1'
function Refresh {
 $script:active=(Test-Path -LiteralPath $stateFile) -or (Test-Path -LiteralPath ($stateFile+'.bak'))
 if($script:active){$MainAction.Content='Desativar e restaurar';$Badge.Text='●  Estado salvo';$Headline.Text='Seu ambiente está preparado.';$StateLabel.Text='Restauração disponível';$HeroHint.Text='Ao fechar, suas configurações serão restauradas automaticamente.'}
 else{$MainAction.Content='Ativar modo de jogo';$Badge.Text='●  Em espera';$Headline.Text='Modo de jogo';$StateLabel.Text='Restauração automática ao fechar';$HeroHint.Text='Fundo preto e interface leve. Seus ajustes ficam salvos.'}
 foreach($c in @($Power,$Sync,$Chrome,$Edge,$Discord,$Spotify)){$c.IsEnabled=(-not $script:active)}
 $Power.IsChecked=$false;$Power.IsEnabled=$false
 $MainAction.IsEnabled=($null -eq $script:worker)
 if($script:active){$MainAction.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#294338')}
 else{$MainAction.ClearValue([Windows.Controls.Control]::BackgroundProperty)}
 if($script:active){
  try{
   $saved=Get-Content $stateFile -Raw|ConvertFrom-Json
   if($saved.Mode -eq 'Restoring'){$Headline.Text='Restauração pendente.';$Badge.Text='●  Ver checklist';$HeroHint.Text='Repita os itens que falharam no checklist ou tente restaurar novamente.'}
   elseif(Test-Path (Join-Path $env:LOCALAPPDATA 'GameModz\checklist.json')){
    $report=Get-Content (Join-Path $env:LOCALAPPDATA 'GameModz\checklist.json') -Raw|ConvertFrom-Json
    if(@($report.Steps|Where-Object {$_.Phase -eq 'Ativar' -and $_.Retryable}).Count){$Headline.Text='Alguns ajustes precisam de atenção.';$Badge.Text='●  Ver checklist';$HeroHint.Text='Confira o resultado de cada operação no checklist.'}
   }
  }catch{}
 }
}
function Run-Action {
 param([string]$RequestedAction='',[string]$ExtraArguments='')
 if($script:worker){return}
 if(-not $RequestedAction -and -not $script:active -and ($Chrome.IsChecked -or $Edge.IsChecked -or $Discord.IsChecked -or $Spotify.IsChecked)){
  if([Windows.MessageBox]::Show('Salvou seu trabalho? Os aplicativos selecionados receberão um pedido de fechamento.','Preparar partida','OKCancel','Information') -ne 'OK'){return}
 }
 $action=if($RequestedAction){$RequestedAction}elseif($script:active){'Desativar'}else{'Ativar'}
 $script:runningAction=$action
 $apps=@();foreach($pair in @(@($Chrome,'chrome'),@($Edge,'msedge'),@($Discord,'discord'),@($Spotify,'spotify'))){if($pair[0].IsChecked){$apps+=$pair[1]}}
 Refresh
 $backend=$script:backendPath.Replace("'","''")
 $script:logPath=Join-Path $env:TEMP ('gamemodz-ui-'+[guid]::NewGuid().ToString('N')+'.log')
 $quotedLog=$script:logPath.Replace("'","''")
 $script:resultPath=$script:logPath+'.result'
 $quotedResult=$script:resultPath.Replace("'","''")
 $command="& '$backend' -Acao $action -NaoInterativo"
 if($action -eq 'Ativar'){
  $ownerProcess=[Diagnostics.Process]::GetCurrentProcess()
  $command+=' -OwnerId '+$ownerProcess.Id+' -OwnerStarted '+$ownerProcess.StartTime.ToUniversalTime().Ticks.ToString()
 }
 if(-not $RequestedAction){
  if($Sync.IsChecked){$command+=' -PausarOneDrive'}
  if($apps.Count){$command+=' -FecharApps '+(($apps|ForEach-Object{"'$_'"}) -join ',')}
 }
 if($action -eq 'Desativar' -and $Reopen.IsChecked -and $ExtraArguments -notmatch 'RecoveryOnly'){$command+=' -ReabrirApps'}
 if($ExtraArguments){$command+=' '+$ExtraArguments}
 $command="`$ErrorActionPreference='Stop'; `$code=0; try { $command *> '$quotedLog' } catch { `$_ | Out-String | Add-Content -LiteralPath '$quotedLog'; `$code=1 } finally { [IO.File]::WriteAllText('$quotedResult',[string]`$code) }; exit `$code"
 $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
 $script:worker=Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -PassThru
 $MainAction.IsEnabled=$false;
 $MainAction.Content=switch($action){'Ativar'{'Ativando…'};'Desativar'{'Restaurando…'};default{'Aplicando…'}}
 foreach($c in @($Power,$Sync,$Chrome,$Edge,$Discord,$Spotify,$Reopen)){$c.IsEnabled=$false}
 $StateLabel.Text='APLICANDO…';$Log.Text='Aguarde. Salvando e aplicando configurações…'
}
function Update-Operation {
 if(-not $script:worker){return}
 try {
  $script:worker.Refresh()
  if(-not $script:worker.HasExited){
   if(Test-Path $script:logPath){$live=Get-Content $script:logPath -Raw -ErrorAction SilentlyContinue;if($live){$Log.Text=$live}}
   return
  }
  try {
   $code=$script:worker.ExitCode
   if(Test-Path $script:resultPath){$code=[int]([IO.File]::ReadAllText($script:resultPath))}
   $Log.Text=if(Test-Path $script:logPath){Get-Content $script:logPath -Raw}else{'Operação encerrada sem relatório.'}
   if($code -ne 0){$Log.Text="Não foi possível concluir. Confira o relatório. Se houver estado salvo, use Restaurar.`n"+$Log.Text}
  } finally {
   $script:worker.Dispose();$script:worker=$null
   if($script:targetFile){Remove-Item -LiteralPath $script:targetFile -ErrorAction SilentlyContinue;$script:targetFile=$null}
   $Reopen.IsEnabled=$true;Refresh
   if($script:closeAfterRestore){
    $script:closeAfterRestore=$false
    if(-not $script:active){$window.Close()}
    elseif($script:runningAction -ne 'Desativar'){Run-Action 'Desativar';$script:closeAfterRestore=$true}
    else{if(-not $TestarCiclo){[Windows.MessageBox]::Show('A restauracao ficou pendente. A janela permanecera aberta; veja o checklist e tente novamente.','GameModz')|Out-Null}}
   }
  }
 } catch {
  $Log.Text="Falha ao atualizar a interface: $_"
  if($script:worker -and -not (Get-Process -Id $script:worker.Id -ErrorAction SilentlyContinue)){
   $script:worker.Dispose();$script:worker=$null;$Reopen.IsEnabled=$true;Refresh
  }
 }
}
$MainAction.Add_Click({try{Run-Action}catch{$Log.Text=$_.ToString();Refresh}})
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(400)
$timer.Add_Tick({
 try{Update-Hardware}catch{$Log.Text="Não foi possível atualizar o hardware: $_"}
 Update-Operation
 if(-not $Verificar -and -not $TestarCiclo -and $script:active -and -not $script:worker){
  try{
   $saved=Get-Content $stateFile -Raw -Encoding UTF8|ConvertFrom-Json
   if($saved.Mode -eq 'Active' -and $saved.Guard){
    $guard=Get-Process -Id $saved.Guard.Id -ErrorAction SilentlyContinue
    $healthy=$false
    if($guard){try{$healthy=$guard.StartTime.ToUniversalTime().Ticks.ToString() -eq $saved.Guard.Started}finally{$guard.Dispose()}}
    if(-not $healthy){$Log.Text='Protecao interrompida. Restaurando por seguranca.';Run-Action 'Desativar'}
   }
  }catch{$Log.Text='Falha na verificacao da protecao: '+$_}
 }
 try{Update-Checklist;Update-Resources}catch{$Log.Text="Falha ao atualizar painel: $_"}
})
function Handle-WindowClosing($sender,$e){
 if($script:worker){$e.Cancel=$true;$script:closeAfterRestore=$true;return}
 if((Test-Path $stateFile) -or (Test-Path ($stateFile+'.bak'))){
  $e.Cancel=$true;$script:closeAfterRestore=$true
  try{Run-Action 'Desativar'}catch{$script:closeAfterRestore=$false;$Log.Text=$_.ToString()}
 }
}
$window.Add_Closing({param($sender,$e)
 if($Verificar -or $TestarCiclo){return}
 Handle-WindowClosing $sender $e
})
. (Join-Path $root 'Interface.Helpers.ps1')
. (Join-Path $root 'Interface.Session.ps1')
if($TestarCiclo){
 # Backend simulado: verifica a interface sem alterar Windows, OneDrive ou aplicativos.
 $testBase=Join-Path $env:TEMP ('GameModz-Test-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $testBase|Out-Null
 $stateFile=Join-Path $testBase 'estado.json'
 $script:backendPath=Join-Path $testBase 'backend.ps1'
 $stub=@'
param($Acao,[switch]$NaoInterativo,[switch]$ReabrirApps,$Item,$AlvoFile)
$state='__STATE__'
if(Test-Path ($state+'.fail')){throw 'Falha simulada do backend'}
if($Acao -eq 'TentarNovamente'){Write-Host "Repeticao simulada: $Item"}
elseif($Acao -eq 'ReduzirPrioridade'){if(-not(Test-Path -LiteralPath $AlvoFile)){throw 'Selecao nao recebida'};Write-Host 'Prioridade simulada'}
elseif($Acao -eq 'Ativar'){[IO.File]::WriteAllText($state,'{}');Write-Host 'Ativacao simulada'}
else{Remove-Item -LiteralPath $state;Write-Host 'Restauracao simulada'}
'@
 $stub=$stub.Replace('__STATE__',$stateFile.Replace("'","''"))
 Set-Content -LiteralPath $script:backendPath -Value $stub -Encoding UTF8
 foreach($control in @($Power,$Sync,$Chrome,$Edge,$Discord,$Spotify)){$control.IsChecked=$false}
 try{
  Refresh
  foreach($step in @('Ativar','Desativar','Falha')){
   if($step -eq 'Falha'){Set-Content -LiteralPath ($stateFile+'.fail') -Value 'test'}
   Run-Action
   if($MainAction.IsEnabled){throw 'Botao nao bloqueou durante operacao.'}
   $watch=[Diagnostics.Stopwatch]::StartNew()
   while($script:worker -and $watch.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 100;Update-Operation}
   if($script:worker){throw 'Operacao nao concluiu dentro do limite.'}
   if(-not $MainAction.IsEnabled){throw 'Botao nao liberou apos operacao.'}
   if($step -eq 'Ativar' -and (-not $script:active -or $MainAction.Content -ne 'Desativar e restaurar')){throw 'Restauracao nao disponibilizada.'}
   if($step -eq 'Desativar' -and $script:active){throw 'Estado nao retornou a desligado.'}
   if($step -eq 'Falha' -and $Log.Text -notmatch 'Falha simulada'){throw 'Erro nao exibido na interface.'}
   Write-Output "PASS: $step - botao e estado corretos."
  }
  Remove-Item -LiteralPath ($stateFile+'.fail')
  Set-Content -LiteralPath $stateFile -Value '{}';Refresh
  $mockStep=[pscustomobject]@{Id='Wallpaper';Name='Fundo preto';Phase='Ativar';Status='Falhou';Retryable=$true;Detail='Falha simulada'}
  $ChecklistGrid.ItemsSource=@($mockStep);$ChecklistGrid.SelectedItem=$mockStep;Update-Checklist
  if(-not $RetryItem.IsEnabled){throw 'Repeticao individual nao habilitada.'}
  $RetryItem.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while($script:worker -and $watch.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 100;Update-Operation}
  if($script:worker -or $Log.Text -notmatch 'Repeticao simulada: Wallpaper'){throw 'Acao de repeticao individual nao foi encaminhada.'}
  Write-Output 'PASS: botao do checklist encaminha somente o item selecionado.'
  $mockRow=[pscustomobject]@{Name='chrome';Eligible=$true;Targets=@([pscustomobject]@{Id=123;Started='1';Path='simulado.exe';Name='chrome'})}
  $script:monitorData=[pscustomobject]@{Updated=[DateTime]::UtcNow.ToString('o')}
  $ResourceGrid.ItemsSource=@($mockRow);$ResourceGrid.SelectedItem=$mockRow;Update-ResourceActions
  if(-not $LowerPriority.IsEnabled){throw 'Acao de prioridade nao habilitada.'}
  $LowerPriority.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while($script:worker -and $watch.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 100;Update-Operation}
  if($script:worker -or $Log.Text -notmatch 'Prioridade simulada'){throw 'Selecao de aplicativo nao encaminhada.'}
  Write-Output 'PASS: botao de prioridade encaminha selecao por arquivo, sem alterar processos reais.'
  $closeEvent=[ComponentModel.CancelEventArgs]::new()
  Handle-WindowClosing $window $closeEvent
  if(-not $closeEvent.Cancel -or -not $script:worker){throw 'Fechamento nao aguardou restauracao.'}
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while($script:worker -and $watch.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 100;Update-Operation}
  if($script:worker -or (Test-Path $stateFile)){throw 'Fechamento nao restaurou estado.'}
  Write-Output 'PASS: fechar a janela aguarda restauracao e remove estado antes de concluir.'
  Set-Content -LiteralPath $stateFile -Value '{}';Set-Content -LiteralPath ($stateFile+'.fail') -Value 'test';Refresh
  $closeEvent=[ComponentModel.CancelEventArgs]::new();Handle-WindowClosing $window $closeEvent
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while($script:worker -and $watch.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 100;Update-Operation}
  if(-not(Test-Path $stateFile) -or $script:closeAfterRestore){throw 'Falha ao fechar perdeu estado ou deixou ciclo de fechamento ativo.'}
  Write-Output 'PASS: falha ao restaurar durante fechamento preserva estado e permite nova tentativa.'
  Remove-Item -LiteralPath ($stateFile+'.fail');Remove-Item -LiteralPath $stateFile
  Refresh;Run-Action 'Ativar'
  $closeEvent=[ComponentModel.CancelEventArgs]::new();Handle-WindowClosing $window $closeEvent
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while($script:worker -and $watch.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 100;Update-Operation}
  if($script:worker -or (Test-Path $stateFile)){throw 'Fechar durante ativacao nao restaurou em seguida.'}
  Write-Output 'PASS: fechar durante ativacao aguarda operacao e restaura em seguida.'

 }finally{
  if($script:hardwareJob){Remove-Job $script:hardwareJob -Force -ErrorAction SilentlyContinue}
  Get-ChildItem -LiteralPath $testBase -File|Remove-Item
  Remove-Item -LiteralPath $testBase
 }
 $window.Close();return
}
Refresh
if(-not $Verificar -and $script:active){
 # Recover leftovers before allowing a new activation; errors remain visible.
 Run-Action 'Desativar' '-RecoveryOnly'
}
if($Verificar){
 if($script:hardwareJob){Wait-Job $script:hardwareJob -Timeout 12|Out-Null;Update-Hardware}
 $originalMotion=$Motion.IsChecked;$Motion.IsChecked=$true
 $window.ShowActivated=$false;$window.Show();$window.UpdateLayout()
 foreach($view in @('Settings','Ideas','Checklist','Resources','Overview')){
  Show-Page $view;$window.UpdateLayout()
  if($view -eq 'Resources'){
   Start-ResourceMonitor
   $sampleWatch=[Diagnostics.Stopwatch]::StartNew()
   while(-not(Test-Path $script:monitorFile) -and $sampleWatch.ElapsedMilliseconds -lt 8000){Start-Sleep -Milliseconds 150}
   Update-Resources;$window.UpdateLayout()
  }
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
  $bitmap.Render($window)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $fileName=if($view -eq 'Overview'){'preview.png'}else{'preview-'+$view.ToLower()+'.png'}
  $stream=[IO.File]::Create((Join-Path $root $fileName))
  try{$encoder.Save($stream)}finally{$stream.Dispose()}
 }
 $Motion.IsChecked=$originalMotion
 Write-Output 'PASS: cinco paginas, controles, checklist e monitor renderizados.'
 $window.Close()
 if($script:hardwareJob){Remove-Job $script:hardwareJob -Force -ErrorAction SilentlyContinue}
 return
}
$timer.Start()
try{[void]$window.ShowDialog()}finally{
 $timer.Stop()
 if($script:hardwareJob){Remove-Job -Job $script:hardwareJob -Force -ErrorAction SilentlyContinue}
}
