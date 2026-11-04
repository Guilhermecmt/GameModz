$script:hardwareJob=$null
$settingsPath=Join-Path $env:LOCALAPPDATA 'GameModz\preferencias.json'
$hardwarePath=Join-Path $env:LOCALAPPDATA 'GameModz\hardware.json'
$script:page='Overview'
function Show-Page([string]$page) {
 $script:page=$page
 $OverviewPage.Visibility='Collapsed';$SettingsPage.Visibility='Collapsed';$IdeasPage.Visibility='Collapsed'
 if($ChecklistPage){$ChecklistPage.Visibility='Collapsed'};if($ResourcesPage){$ResourcesPage.Visibility='Collapsed'}
 foreach($nav in (@($NavOverview,$NavSettings,$NavIdeas,$NavChecklist,$NavResources)|Where-Object {$null -ne $_})){$nav.Background=[Windows.Media.Brushes]::Transparent;$nav.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#515B69')}
 switch($page){
  Overview {$OverviewPage.Visibility='Visible';$selected=$NavOverview;$PageTitle.Text='Tudo pronto para jogar.';$PageSubtitle.Text='Prepare o essencial. Depois, volte ao seu normal.'}
  Settings {$SettingsPage.Visibility='Visible';$selected=$NavSettings;$PageTitle.Text='Do seu jeito.';$PageSubtitle.Text='Escolha o que muda quando o modo de jogo é ativado.'}
  Ideas {$IdeasPage.Visibility='Visible';$selected=$NavIdeas;$PageTitle.Text='Desempenho com critério.';$PageSubtitle.Text='Cinco opções para testar conforme o jogo e o hardware.'}
  Checklist {$ChecklistPage.Visibility='Visible';$selected=$NavChecklist;$PageTitle.Text='Cada ajuste, às claras.';$PageSubtitle.Text='Acompanhe os resultados e repita somente o item necessário.';Update-Checklist}
  Resources {$ResourcesPage.Visibility='Visible';$selected=$NavResources;$PageTitle.Text='O que está consumindo recursos?';$PageSubtitle.Text='Observe os aplicativos. Você escolhe quando agir.'}
 }
 $selected.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#DAE5FA')
 $selected.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#2258AD')
 if(Get-Command Set-SessionPage -ErrorAction SilentlyContinue){Set-SessionPage $page}
 if(-not $Motion.IsChecked -and [Windows.SystemParameters]::ClientAreaAnimation){
  $animation=[Windows.Media.Animation.DoubleAnimation]::new(0.5,1,[Windows.Duration]::new([TimeSpan]::FromMilliseconds(180)))
  $animation.EasingFunction=[Windows.Media.Animation.CubicEase]::new()
  $animation.EasingFunction.EasingMode='EaseOut'
  $PageHost.BeginAnimation([Windows.UIElement]::OpacityProperty,$animation)
 }
}
$NavOverview.Add_Click({Show-Page Overview});$NavSettings.Add_Click({Show-Page Settings});$NavIdeas.Add_Click({Show-Page Ideas});$Explore.Add_Click({Show-Page Ideas})
function Set-Hardware($data){
 $CpuInfo.Text=$data.Cpu;$CpuInfo.ToolTip=$data.CpuFull
 $GpuInfo.Text=$data.Gpu;$GpuInfo.ToolTip=$data.AllGpus
 $RamInfo.Text="$($data.Ram) GB · $($data.Windows)";$RamInfo.ToolTip=$data.System
}
function Update-Hardware {
 if($script:hardwareJob -and $script:hardwareJob.State -in @('Completed','Failed','Stopped')){
  try{
   $data=Receive-Job $script:hardwareJob -ErrorAction Stop
   if($data){Set-Hardware $data;New-Item -ItemType Directory -Path (Split-Path $hardwarePath) -Force|Out-Null;$data|Select-Object Cpu,CpuFull,Gpu,AllGpus,Ram,Windows,System|ConvertTo-Json|Set-Content -LiteralPath $hardwarePath -Encoding UTF8}
  }catch{$CpuInfo.Text='Não disponível';$CpuInfo.ToolTip=$_.ToString()}
  finally{Remove-Job $script:hardwareJob -Force -ErrorAction SilentlyContinue;$script:hardwareJob=$null}
 }
}
if(Test-Path $hardwarePath){try{Set-Hardware (Get-Content $hardwarePath -Raw|ConvertFrom-Json)}catch{}}
$script:hardwareJob=Start-Job {
 $cpu=Get-CimInstance Win32_Processor -ErrorAction Stop|Select-Object -First 1
 $gpus=@(Get-CimInstance Win32_VideoController -ErrorAction Stop)
 $gpu=$gpus|Where-Object {$_.Name -match 'NVIDIA|Radeon|Arc'}|Select-Object -First 1
 if(-not $gpu){$gpu=$gpus|Select-Object -First 1}
 $pc=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
 $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
 [pscustomobject]@{
  Cpu=($cpu.Name -replace '\(R\)|\(TM\)','' -replace '^\d+th Gen ','').Trim()
  CpuFull=$cpu.Name;Gpu=($gpu.Name -replace '^NVIDIA (GeForce )?','' -replace ' Laptop GPU',' Laptop')
  AllGpus=($gpus.Name -join ' + ');Ram=[math]::Round($pc.TotalPhysicalMemory/1GB)
  Windows=if([int]$os.BuildNumber -ge 22000){'Windows 11'}else{'Windows 10'}
  System="$($os.Caption) · $($pc.Model)"
 }
}
$ideas=@(
 @{Title='Usar a GPU de alto desempenho';Description='Em PCs com duas GPUs, selecione a dedicada para o jogo. Evita renderizar na integrada quando ela é o gargalo.';Tag='POR JOGO · GRÁFICOS';Button='Abrir gráficos';Url='ms-settings:display-advancedgraphics'},
 @{Title='Revisar capturas em segundo plano';Description='Se não usa replay, teste desativar a gravação contínua. Pode reduzir disputa por GPU, memória e disco.';Tag='SE A GRAVAÇÃO ESTIVER ATIVA';Button='Abrir capturas';Url='ms-settings:gaming-gamedvr'},
 @{Title='Conferir o Modo de Jogo do Windows';Description='Use o recurso nativo para priorizar a experiência durante jogos. O benefício depende da carga em segundo plano.';Tag='RECURSO NATIVO';Button='Abrir Modo de Jogo';Url='ms-settings:gaming-gamemode'},
 @{Title='Testar otimizações para jogos em janela';Description='No Windows 11, pode reduzir a latência em jogos DirectX 10/11 compatíveis, em janela ou sem bordas. Compare no seu jogo.';Tag='WINDOWS 11 · DIRECTX 10/11';Button='Abrir gráficos';Url='ms-settings:display-advancedgraphics'},
 @{Title='Ajustar a renderização por jogo';Description='Reduza sombras ou distância de visão conforme o gargalo. Teste DLSS/FSR apenas quando o jogo oferecer suporte; não é um ajuste universal do DayZ.';Tag='DENTRO DO JOGO · COMPATIBILIDADE VARIÁVEL';Button='Sobre DLSS';Url='https://www.nvidia.com/en-us/geforce/technologies/dlss/'}
)
foreach($idea in $ideas){
 $card=[Windows.Controls.Border]::new();$card.Style=$window.Resources['Card'];$card.Margin='0,0,0,12';$card.Padding='18'
 $stack=[Windows.Controls.StackPanel]::new()
 $tag=[Windows.Controls.TextBlock]::new();$tag.Text=$idea.Tag;$tag.FontSize=9;$tag.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#7C8798')
 $title=[Windows.Controls.TextBlock]::new();$title.Text=$idea.Title;$title.FontSize=16;$title.FontWeight='SemiBold';$title.Margin='0,7,0,7'
 $desc=[Windows.Controls.TextBlock]::new();$desc.Text=$idea.Description;$desc.Style=$window.Resources['Muted']
 $button=[Windows.Controls.Button]::new();$button.Content=$idea.Button+' ↗';$button.HorizontalAlignment='Left';$button.Margin='0,12,0,0';$button.Tag=$idea.Url
 $button.Add_Click({param($sender,$eventArgs) try{Start-Process -FilePath ([string]$sender.Tag)}catch{$Log.Text=$_.ToString();Show-Page Overview}})
 [void]$stack.Children.Add($tag);[void]$stack.Children.Add($title);[void]$stack.Children.Add($desc);[void]$stack.Children.Add($button)
 $card.Child=$stack;[void]$IdeasList.Children.Add($card)
}
$preferenceNames=@('Power','Sync','Chrome','Edge','Discord','Spotify','Reopen','Motion')
if(Test-Path $settingsPath){
 try{
  $saved=Get-Content $settingsPath -Raw|ConvertFrom-Json
  foreach($name in $preferenceNames){if($null -ne $saved.PSObject.Properties[$name]){$window.FindName($name).IsChecked=[bool]$saved.$name}}
 }catch{$Log.Text='Não foi possível ler as preferências. Usando padrões.'}
}
$Motion.Add_Checked({$PageHost.BeginAnimation([Windows.UIElement]::OpacityProperty,$null);$PageHost.Opacity=1})
$window.Add_Closing({param($sender,$eventArgs)
 if($Verificar -or $TestarCiclo){return}
 if($eventArgs.Cancel){return}
 try{
  $prefs=[ordered]@{};foreach($name in $preferenceNames){$prefs[$name]=[bool]$window.FindName($name).IsChecked}
  New-Item -ItemType Directory -Path (Split-Path $settingsPath) -Force|Out-Null
  $prefs|ConvertTo-Json|Set-Content -LiteralPath $settingsPath -Encoding UTF8
 }catch{Write-Warning $_}
})
Show-Page Overview
