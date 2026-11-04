$ErrorActionPreference='Stop'
$testStem=Join-Path $env:TEMP ('GameModz-SamplingTest-'+[guid]::NewGuid().ToString('N'))
$marker=$testStem+'.run';$outputFile=$testStem+'.json';$job=$null
try{
 Set-Content -LiteralPath $marker -Value run
 $job=Start-Job -FilePath (Join-Path $PSScriptRoot 'Monitor.Worker.ps1') -ArgumentList @($outputFile,$marker,[Diagnostics.Process]::GetCurrentProcess().SessionId,$PSScriptRoot)
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not(Test-Path $outputFile) -and $watch.ElapsedMilliseconds -lt 8000){Start-Sleep -Milliseconds 200}
 if(-not(Test-Path $outputFile)){Receive-Job $job;throw 'Monitor nao gerou amostra.'}
 $data=Get-Content $outputFile -Raw|ConvertFrom-Json
 if($data.Error){throw $data.Error}
 if(@($data.Rows|Where-Object {$_.Cpu -lt 0 -or $_.Cpu -gt 100}).Count){throw 'CPU fora da escala normalizada.'}
 Write-Output "PASS: monitor gerou amostra real de $(@($data.Rows).Count) grupos."
 Remove-Item -LiteralPath $marker
 Wait-Job $job -Timeout 5|Out-Null
 if($job.State -ne 'Completed'){throw 'Monitor nao encerrou ao remover marcador.'}
 Write-Output 'PASS: monitor encerra quando a pagina deixa de solicitar amostras.'
}finally{
 if($job){Remove-Job $job -Force -ErrorAction SilentlyContinue}
 foreach($path in @($marker,$outputFile,($outputFile+'.tmp'))){Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue}
}
