# GameModz 1.1.0

Utilitário para Windows, com interface WPF, para preparar o ambiente antes de jogar e restaurar as configurações depois.

## Executar

1. Baixe o projeto completo pelo botão **Code → Download ZIP** ou clone o repositório.
2. Extraia os arquivos para uma pasta.
3. Abra **GameModz.exe**. Mantenha os scripts, `Interface.xaml` e a pasta `assets` junto do executável.
4. Selecione as preferências e clique em **Ativar modo de jogo**.
5. Ao terminar, clique em **Desativar e restaurar** ou feche a janela: ela restaura antes de sair.

O executável é um lançador gráfico pequeno, cujo código está em `Launcher.cs`. Ele abre a interface PowerShell sem console. Não é um instalador e não requer login. O funcionamento foi verificado em Windows 11 com Windows PowerShell 5.1 e WPF.

## Recursos

- Fundo preto temporário, redução de efeitos visuais e transparência.
- Preservação das preferências de tema, brilho e plano de energia durante a ativação.
- Pedido opcional de encerramento do OneDrive, com espera limitada e reabertura na restauração.
- Fechamento solicitado de aplicativos selecionados, sem matar processos.
- Checklist persistente com resultados, detalhes e repetição individual de etapas com falha.
- Monitor de CPU e RAM por aplicativo, ativo somente na página Aplicativos e com a janela não minimizada.
- Redução manual de prioridade para aplicativos compatíveis, com registro do valor original.
- Identificação de CPU, GPU e memória no rodapé.

As ações em processos verificam PID, instante de criação, caminho, sessão e lista de aplicativos permitidos. Jogos, anticheats e componentes essenciais não fazem parte da lista de ações. Os dados do monitor são aproximados: CPU é normalizada pelo total de processadores lógicos, e RAM soma conjuntos de trabalho, incluindo memória compartilhada.

## Restauração e limites

O estado fica em `%LOCALAPPDATA%\GameModz`, com snapshot e cópia de segurança. Ao fechar a janela, o GameModz restaura os ajustes; falhas preservam as pendências e mantêm a janela disponível. Um guardião independente recupera após falha da interface e tenta restaurar durante desligamento, reinício ou logout. A recuperação no próximo login cobre interrupções abruptas, desde que a execução esteja disponível.

A ativação é bloqueada se a proteção não iniciar ou houver estado pendente. Os scripts de recuperação são copiados para o perfil e continuam disponíveis se a pasta do projeto for movida. O fundo preto temporário não substitui a preferência persistente; fundos dinâmicos detectáveis e múltiplos monitores são preservados.

Sair apenas do jogo mantém o modo enquanto a interface estiver aberta. Nenhum programa consegue restaurar durante falta de energia ou garantir recuperação após exclusão dos snapshots ou bloqueio da inicialização. A reabertura de aplicativos não recupera documentos ou abas. Consulte [proteções, testes e limites](SAFETY.md).

As cinco sugestões da página Melhorias são orientações com atalhos para configurações: não são aplicadas nem restauradas automaticamente. O projeto não promete aumento de FPS; os resultados dependem do gargalo e precisam ser medidos.

## Compilar o lançador

No Windows PowerShell, na pasta do projeto:

```powershell
.\Build.ps1
```

O script usa o compilador C# do .NET Framework instalado no Windows. Também é possível executar a interface diretamente:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\GameModz-UI.ps1
```

`ExecutionPolicy Bypass` vale apenas para esse processo; os comandos não mudam a política permanente do computador.

## Testes

Execute toda a bateria com `./Test-All.ps1`. Use `./Test-All.ps1 -Render -Build` para incluir as prévias da interface e a compilação. Os testes também podem ser executados separadamente:

```powershell
.\Test-Appearance.ps1
.\Test-OneDrive.ps1
.\Test-Session.ps1
.\Test-Safety.ps1
.\Test-Monitor.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\GameModz-UI.ps1 -TestarCiclo
```

Os testes de sessão usam estado temporário, ajustes de aparência simulados e um processo descartável para testar prioridade. O teste do monitor apenas lê processos reais. Esses testes não são benchmarks de FPS.

Detalhes: [manual](LEIA-ME.md), [pesquisa e decisões](PESQUISA-UX-DESEMPENHO.md) e [origem da arte](assets/PROMPT.md).

## Versões

A versão está em `VERSION`, com alterações em [CHANGELOG.md](CHANGELOG.md). Tags `vMAJOR.MINOR.PATCH` identificam as versões publicadas. Estado e dados pessoais permanecem fora do repositório.
