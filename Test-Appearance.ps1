$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'GameModz.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Erro de sintaxe no backend.'}
$functionAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Set-TransparencyValue'},$true)
if(-not $functionAst){throw 'Funcao nao encontrada.'}
# Carrega somente a funcao testada. Nao executa o modo de jogo.
. ([scriptblock]::Create($functionAst.Extent.Text))
$testKey='HKCU:\Software\GameModz-Regression-'+[guid]::NewGuid().ToString('N')
try {
 New-Item -Path $testKey|Out-Null
 foreach($appTheme in @(0,1)){
  foreach($systemTheme in @(0,1)){
   New-ItemProperty -Path $testKey -Name AppsUseLightTheme -Value $appTheme -PropertyType DWord -Force|Out-Null
   New-ItemProperty -Path $testKey -Name SystemUsesLightTheme -Value $systemTheme -PropertyType DWord -Force|Out-Null
   New-ItemProperty -Path $testKey -Name OutroValor -Value 'preservar' -PropertyType String -Force|Out-Null
   foreach($value in @(0,1)){
    Set-TransparencyValue $testKey $value
    $after=Get-ItemProperty $testKey
    if($after.AppsUseLightTheme -ne $appTheme -or $after.SystemUsesLightTheme -ne $systemTheme -or $after.OutroValor -ne 'preservar' -or $after.EnableTransparency -ne $value){throw 'Preferencias de aparencia alteradas indevidamente.'}
   }
  }
 }
 Write-Output 'PASS: ativacao/restauracao da transparencia preservam temas claro/escuro e demais valores (8 combinacoes).'
}finally{Remove-Item -LiteralPath $testKey -ErrorAction SilentlyContinue}
