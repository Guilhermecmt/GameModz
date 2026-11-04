using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher
{
    [STAThread]
    private static void Main()
    {
        try
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(root, "GameModz-UI.ps1");
            if (!File.Exists(script))
                throw new FileNotFoundException("GameModz-UI.ps1 nao encontrado. Mantenha o aplicativo na pasta do projeto.");
            var info = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                    @"System32\WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File \"" + script + "\"",
                WorkingDirectory = root,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (Process child = Process.Start(info)) { }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "GameModz", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
