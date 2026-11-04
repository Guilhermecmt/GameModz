if(-not ('GMForeground' -as [type])) {
 Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GMForeground {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
}
'@
}
function Get-ActionAllowlist { @('chrome','msedge','firefox','opera','brave','discord','spotify','wallpaper32','wallpaper64','thunderbird') }
function Get-ForegroundProcessId {
 $foregroundId=[uint32]0
 [void][GMForeground]::GetWindowThreadProcessId([GMForeground]::GetForegroundWindow(),[ref]$foregroundId)
 return [int]$foregroundId
}
function Get-ProcessIdentity($Process) {
 [pscustomobject]@{Id=$Process.Id;Started=$Process.StartTime.ToUniversalTime().Ticks.ToString();Path=$Process.Path;Name=$Process.ProcessName}
}
function Get-VerifiedProcess($Identity,[switch]$ForAction) {
 $process=Get-Process -Id ([int]$Identity.Id) -ErrorAction SilentlyContinue
 if(-not $process){return $null}
 try {
  if($process.StartTime.ToUniversalTime().Ticks.ToString() -ne [string]$Identity.Started -or $process.Path -ine $Identity.Path){$process.Dispose();return $null}
  if($ForAction){
   if($process.ProcessName -notin (Get-ActionAllowlist)){throw 'Aplicativo protegido ou fora da lista permitida.'}
   if($process.SessionId -ne [Diagnostics.Process]::GetCurrentProcess().SessionId){throw 'Processo de outra sessao.'}
   if($process.Path.StartsWith($env:WINDIR,[StringComparison]::OrdinalIgnoreCase)){throw 'Componentes do Windows sao protegidos.'}
   $foreground=Get-Process -Id (Get-ForegroundProcessId) -ErrorAction SilentlyContinue
   if($foreground){try{if($foreground.ProcessName -ieq $process.ProcessName){throw 'O aplicativo esta em primeiro plano.'}}finally{$foreground.Dispose()}}
  }
  return $process
 }catch{$process.Dispose();throw}
}
