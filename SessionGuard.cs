using System;
using System.Diagnostics;
using Microsoft.Win32;
// Runs on the SystemEvents thread: no PowerShell runspace is needed there.
public static class GMSessionGuard {
 public static string HostPath, BackendPath;
 public static void Install() { SystemEvents.SessionEnding += OnEnding; }
 public static void Uninstall() { SystemEvents.SessionEnding -= OnEnding; }
 static void OnEnding(object sender, SessionEndingEventArgs e) {
  try {
   var info = new ProcessStartInfo(HostPath, "-NoProfile -ExecutionPolicy Bypass -File \"" + BackendPath + "\" -Acao Desativar -NaoInterativo -RecoveryOnly -ShutdownRecovery");
   info.UseShellExecute = false; info.CreateNoWindow = true;
   using(var child = Process.Start(info)) { child.WaitForExit(4000); }
  } catch { /* Durable state and logon recovery remain armed. Never cancel shutdown. */ }
 }
}
