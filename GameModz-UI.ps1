param([switch]$Verificar,[switch]$TestarCiclo)
$ErrorActionPreference='Stop'
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
$script:active=$false
$script:logPath=$null
$script:resultPath=$null
$script:backendPath=Join-Path $root 'GameModz.ps1'
function Refresh {
 $script:active=Test-Path -LiteralPath $stateFile
 if($script:active){$MainAction.Content='Desativar e restaurar';$Badge.Text='●  Estado salvo';$Headline.Text='Seu ambiente está preparado.';$StateLabel.Text='Restauração disponível';$HeroHint.Text='Ao terminar, restaure aqui as configurações anteriores.'}
 else{$MainAction.Content='Ativar modo de jogo';$Badge.Text='●  Em espera';$Headline.Text='Modo de jogo';$StateLabel.Text='Restauração manual ao terminar';$HeroHint.Text='Fundo preto e interface leve. Seus ajustes ficam salvos.'}
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
 $apps=@();foreach($pair in @(@($Chrome,'chrome'),@($Edge,'msedge'),@($Discord,'discord'),@($Spotify,'spotify'))){if($pair[0].IsChecked){$apps+=$pair[1]}}
 Refresh
 $backend=$script:backendPath.Replace("'","''")
 $script:logPath=Join-Path $env:TEMP ('gamemodz-ui-'+[guid]::NewGuid().ToString('N')+'.log')
 $quotedLog=$script:logPath.Replace("'","''")
 $script:resultPath=$script:logPath+'.result'
 $quotedResult=$script:resultPath.Replace("'","''")
 $command="& '$backend' -Acao $action -NaoInterativo"
 if(-not $RequestedAction){
  if($Sync.IsChecked){$command+=' -PausarOneDrive'}
  if($Reopen.IsChecked){$command+=' -ReabrirApps'}
  if($apps.Count){$command+=' -FecharApps '+(($apps|ForEach-Object{"'$_'"}) -join ',')}
 }
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
 try{Update-Checklist;Update-Resources}catch{$Log.Text="Falha ao atualizar painel: $_"}
})
$window.Add_Closing({param($sender,$e)
 if($Verificar -or $TestarCiclo){return}
 if($script:worker){[Windows.MessageBox]::Show('Aguarde a operação terminar antes de fechar.','GameModz')|Out-Null;$e.Cancel=$true;return}
 if((Test-Path $stateFile) -and [Windows.MessageBox]::Show('Os ajustes continuam ativos. Fechar sem restaurar? Você poderá reabrir o GameModz para restaurar.','Modo ativo','YesNo','Question') -ne 'Yes'){$e.Cancel=$true}
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
 }finally{
  if($script:hardwareJob){Remove-Job $script:hardwareJob -Force -ErrorAction SilentlyContinue}
  Get-ChildItem -LiteralPath $testBase -File|Remove-Item
  Remove-Item -LiteralPath $testBase
 }
 $window.Close();return
}
Refresh
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
