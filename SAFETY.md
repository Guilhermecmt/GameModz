# Recuperação do ambiente

## O que é protegido

A versão 1.0 mantinha ajustes ao fechar a interface. A versão 1.1 restaura automaticamente ao fechar. Se uma operação estiver em andamento, espera sua conclusão e então restaura. Se houver falha, a janela permanece disponível e o estado não é descartado. Sair do jogo sozinho não encerra o modo: feche o GameModz ou use **Desativar e restaurar**.

Antes de alterar o Windows, o backend salva os valores originais, registra recuperação no login e exige confirmação de um guardião independente. O guardião verifica PID e instante de criação da interface e tenta restaurar se ela encerrar inesperadamente. A interface também verifica se o guardião continua vivo. A restauração e a ativação usam o mesmo mutex para não escrever o estado simultaneamente.

O guardião escuta `SystemEvents.SessionEnding`. No desligamento, reinício ou logout normal, solicita a restauração e espera até quatro segundos, sem cancelar o encerramento do Windows. Nessa fase não reabre aplicativos nem o OneDrive. Pendências permanecem para o próximo login. O Windows pode encerrar processos antes que essa tentativa termine.

A recuperação usa `%LOCALAPPDATA%\GameModz\Recovery`, independente da pasta original do projeto, e um valor **GameModzRecovery** em `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. No próximo login do mesmo usuário, tenta restaurar até três vezes. Não desfaz uma sessão cujo proprietário ainda esteja vivo. O registro é removido quando a restauração termina. Não exige administrador, serviço ou tarefa com elevação.

## Snapshot e falhas

`estado.json` é gravado com flush em disco e substituição atômica. `estado.json.bak` mantém uma segunda cópia. O estado e cada pendência são gravados **antes** da respectiva alteração. JSON inválido ou incompleto usa a cópia de segurança; se ambas falharem, os arquivos são preservados e nenhuma nova ativação é permitida. Não apague esses arquivos com restauração pendente.

Cada ajuste é restaurado separadamente e somente é marcado concluído depois do retorno da operação. Falha de wallpaper não impede restaurar efeitos e transparência. Um checklist corrompido é reconstruído e não impede a recuperação. A prioridade é restaurada apenas no processo original, se ainda estiver com o valor aplicado pelo GameModz.

O fundo preto e a redução de efeitos são aplicados sem `SPIF_UPDATEINIFILE`; não substituem a preferência persistente do perfil. A restauração explícita também corrige snapshots legados, que aplicavam mudanças permanentes. Uma cópia da imagem estática original permite recuperação se o arquivo original desaparecer. Spotlight, slideshow detectável, aplicativos conhecidos de wallpaper animado e configurações com mais de um monitor são preservados, pois a API simples não consegue reproduzi-los integralmente.

Na recuperação automática de falha/login, aplicativos fechados não são reabertos indiscriminadamente; o OneDrive é retomado se estiver registrado como pendente. No fechamento normal, a opção **Reabrir aplicativos ao restaurar** é respeitada. Nenhum mecanismo consegue recuperar documentos ou abas que o próprio aplicativo não tenha salvo.

## Limites verificáveis

Falta de energia, desligamento forçado, falha de disco, exclusão das duas cópias, bloqueio do PowerShell e desativação da entrada de inicialização pelo usuário/Windows impedem garantir restauração imediata. A recuperação ocorre no login seguinte quando os arquivos, permissões e execução estiverem disponíveis. A inscrição em `Run` pode ocorrer depois de a área de trabalho aparecer. O programa não modifica políticas de segurança para contornar bloqueios.

Não se deve prometer garantia absoluta diante dessas condições. Os testes simulam falhas sem reiniciar nem desligar o computador. O callback real de encerramento é invocado com backend descartável; isso valida o encaminhamento, mas não substitui uma prova de desligamento real em uma VM.

## Recuperação manual

Reabra o GameModz; uma restauração pendente começa automaticamente. Alternativamente:

```powershell
.\GameModz.ps1 -Acao Desativar -NaoInterativo
# Se a pasta original foi movida:
& "$env:LOCALAPPDATA\GameModz\Recovery\GameModz.ps1" -Acao Desativar -NaoInterativo
```

Falhas aparecem no checklist e em `%LOCALAPPDATA%\GameModz\recovery.log`. O script retorna erro se ainda houver estado pendente. Logs e snapshots são locais e não entram no Git.

Ativação direta por script exige `-OwnerId` e `-OwnerStarted` (ticks UTC de criação de um processo proprietário vivo). Use preferencialmente a interface, que fornece essa identidade e fica aberta enquanto o modo está ativo.

## Fontes da implementação

- [SystemParametersInfoW e flags de persistência](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow)
- [SystemEvents.SessionEnding](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.systemevents.sessionending)
