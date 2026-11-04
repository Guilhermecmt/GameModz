param([string]$OutputFile,[string]$MarkerFile,[int]$UserSession,[string]$ProgramRoot)
$ErrorActionPreference='Stop'
. (Join-Path $ProgramRoot 'Process.Common.ps1')
$previous=@{};$streak=@{};$last=[DateTime]::UtcNow
while(Test-Path -LiteralPath $MarkerFile){
 try{
  $now=[DateTime]::UtcNow;$seconds=($now-$last).TotalSeconds;$rows=@();$current=@{}
  $foregroundId=Get-ForegroundProcessId
  $foreground=Get-Process -Id $foregroundId -ErrorAction SilentlyContinue
  $foregroundName=if($foreground){$foreground.ProcessName}else{''}
  if($foreground){$foreground.Dispose()}
  foreach($process in (Get-Process)){
   try{
    if($process.SessionId -ne $UserSession -or -not $process.Path -or $process.Path.StartsWith($env:WINDIR,[StringComparison]::OrdinalIgnoreCase)){continue}
    if($process.ProcessName -match '^(powershell|pwsh|conhost|GameModz)$'){continue}
    $identity=Get-ProcessIdentity $process;$key=$identity.Id.ToString()+'.'+$identity.Started
    $cpuTime=$process.TotalProcessorTime.TotalSeconds;$current[$key]=$cpuTime
    $cpu=0.0
    if($previous.ContainsKey($key) -and $seconds -gt 0){$cpu=[math]::Max(0,100*($cpuTime-$previous[$key])/$seconds/[Environment]::ProcessorCount)}
    $rows+=[pscustomobject]@{Name=$process.ProcessName;Cpu=$cpu;Ram=($process.WorkingSet64/1MB);Identity=$identity}
   }catch{}finally{$process.Dispose()}
  }
  $groups=@(foreach($group in ($rows|Group-Object Name)){
   $cpu=[math]::Round(($group.Group|Measure-Object Cpu -Sum).Sum,1)
   $ram=[math]::Round(($group.Group|Measure-Object Ram -Sum).Sum)
   $background=$group.Name -ine $foregroundName
   $high=$background -and ($cpu -ge 5 -or $ram -ge 512)
   if($high){$streak[$group.Name]=[int]$streak[$group.Name]+1}else{$streak[$group.Name]=0}
   $eligible=$group.Name -in (Get-ActionAllowlist) -and $background
   $status=if(-not $background){'Em primeiro plano'}elseif($streak[$group.Name] -ge 3){'Consumo sustentado'}elseif($high){'Observando'}else{'Sem alerta'}
   [pscustomobject]@{Name=$group.Name;Cpu=$cpu;Ram=$ram;Status=$status;Eligible=$eligible;Targets=@($group.Group.Identity);Count=$group.Count}
  })
  $data=[pscustomobject]@{Updated=$now.ToString('o');Rows=@($groups|Sort-Object @{Expression={$_.Status -eq 'Consumo sustentado'};Descending=$true},@{Expression='Cpu';Descending=$true},@{Expression='Ram';Descending=$true})}
  $data|ConvertTo-Json -Depth 8|Set-Content -LiteralPath ($OutputFile+'.tmp') -Encoding UTF8
  Move-Item -LiteralPath ($OutputFile+'.tmp') -Destination $OutputFile -Force
  $previous=$current;$last=$now
 }catch{
  [pscustomobject]@{Updated=[DateTime]::UtcNow.ToString('o');Rows=@();Error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath $OutputFile -Encoding UTF8
 }
 Start-Sleep -Seconds 2
}
