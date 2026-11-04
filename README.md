# GameModz

**Prepare o Windows para jogar e recupere suas configurações ao terminar.**

**Versão 1.3.0 · Windows · Instalação sem administrador**

GameModz é um utilitário com interface gráfica para ajustar temporariamente a aparência do Windows, reduzir distrações e acompanhar o uso de recursos. Salva o estado anterior e restaura os ajustes ao fechar a janela. Não promete aumento de FPS e não altera antivírus, firewall, serviços, jogos ou anticheats.

## Instalar

A instalação é por usuário e **cria automaticamente um atalho na área de trabalho**, além de atalhos para abrir e desinstalar o GameModz no menu Iniciar. Não exige administrador, Git, Python, Node.js nem ferramentas extras: o lançador `GameModz.exe` é compilado durante a instalação, a partir de `Launcher.cs`, com o compilador C# que já vem no .NET Framework do Windows.

### Opção 1 — baixar e clicar

1. [Baixe o GameModz 1.3.0 em ZIP](https://github.com/Guilhermecmt/GameModz/archive/refs/tags/v1.3.0.zip).
2. Clique com o botão direito no ZIP e escolha **Extrair tudo**.
3. Na pasta extraída, dê dois cliques em **`Install.cmd`**.
4. Aguarde a confirmação e abra **GameModz** pelo atalho da área de trabalho.

Depois da instalação, você pode apagar o ZIP e a pasta extraída. **O instalador é `Install.cmd` / `Install.ps1`**; o pacote não traz nenhum executável pronto, só código-fonte que você pode ler. Não há um pacote MSI ou `Setup.exe` nesta versão.

### Opção 2 — instalar pelo terminal

Abra o **PowerShell**, sem executar como administrador, e cole:

```powershell
$instalador = Join-Path $env:TEMP 'GameModz-Install.ps1'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Guilhermecmt/GameModz/v1.3.0/Install.ps1' -OutFile $instalador -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $instalador
```

O script baixa o pacote da tag **`v1.3.0`**, valida sua estrutura, instala os arquivos e cria os atalhos. Você pode [ler o instalador antes de executar](Install.ps1). `ExecutionPolicy Bypass` vale somente para esse processo; a instalação não altera a política permanente da máquina.

### A partir de uma cópia local

Se já baixou ou clonou o projeto, abra o terminal na pasta dele e execute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Nesse caso, usa os arquivos locais, sem baixar novamente. A versão instalada é a indicada no `VERSION` dessa pasta.

Para usar sem instalar, gere o lançador com `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1`, abra o `GameModz.exe` criado na pasta e mantenha os scripts, `Interface.xaml` e `assets` juntos. O modo portátil não cria atalhos automaticamente.

### Requisitos

- Windows com Windows PowerShell **5.1**, .NET Framework e suporte a WPF. Validado no **Windows 11**; Windows 10 não foi validado nesta versão.
- Permissão de escrita no perfil e na área de trabalho do usuário.
- Internet para baixar. Instalação a partir do ZIP completo e uso do aplicativo funcionam offline.

Os scripts não têm assinatura digital, e o lançador é compilado na sua máquina a partir do código do repositório. Se uma política da máquina bloquear a execução, verifique a origem dos arquivos e consulte a política da organização. O instalador não desativa proteções.

### Onde fica instalado

| Item | Local |
|---|---|
| Programa | `%LOCALAPPDATA%\Programs\GameModz` |
| Atalho principal | Área de trabalho do usuário |
| Abrir e desinstalar | Menu Iniciar do usuário |
| Preferências, checklist e snapshots | `%LOCALAPPDATA%\GameModz` |
| Recuperação independente | `%LOCALAPPDATA%\GameModz\Recovery` |

A área de trabalho é obtida das pastas especiais configuradas no Windows, incluindo redirecionamento para o OneDrive. A instalação só informa sucesso depois de verificar os atalhos.

## Como usar

1. Abra o GameModz pelo atalho.
2. Em **Preferências**, escolha as ações opcionais. Salve seu trabalho antes de solicitar o fechamento de aplicativos.
3. Clique em **Ativar modo de jogo**.
4. Confira o **Checklist** para ver o que foi aplicado, preservado ou falhou.
5. Ao terminar, clique em **Desativar e restaurar** ou feche a janela. O aplicativo restaura antes de sair; falhas mantêm a janela e o estado disponíveis para nova tentativa.

Sair apenas do jogo mantém o modo enquanto o GameModz estiver aberto. O programa não detecta automaticamente qual jogo você terminou.

## Recursos

| Recurso | Comportamento |
|---|---|
| Aparência temporária | Fundo preto em configurações compatíveis, redução de efeitos visuais e transparência. |
| Preferências preservadas | Mantém tema, brilho e plano de energia. Preserva fundos dinâmicos detectáveis e múltiplos monitores. |
| OneDrive opcional | Solicita encerramento com espera limitada e retoma na restauração se estava em execução. |
| Fechamento opcional | Solicita fechamento normal dos aplicativos selecionados, sem matar processos. |
| Checklist | Mostra resultado, detalhe e repetição individual das etapas com falha. |
| Monitor de aplicativos | Mostra CPU e RAM enquanto a página Aplicativos está aberta e a janela não está minimizada. |
| Prioridade manual | Reduz prioridade de aplicativos compatíveis e registra o valor original para restaurar. |
| Recuperação | Restaura ao fechar, acompanha falhas da interface e tenta recuperar no encerramento da sessão e no próximo login. |

As ações em processos verificam PID, instante de criação, caminho, sessão e lista de aplicativos permitidos. CPU é normalizada pelos processadores lógicos; RAM soma conjuntos de trabalho e pode incluir memória compartilhada. São dados aproximados, não benchmarks.

As sugestões da página **Melhorias de FPS** abrem configurações ou documentação. Não são aplicadas nem restauradas automaticamente.

## Atualizar

Desative o modo, feche o GameModz e execute o instalador da versão desejada. Ele substitui o programa e preserva preferências e recuperação. Não existe atualização automática em segundo plano.

A nova cópia é preparada antes de trocar a anterior. Se a instalação falhar, o instalador tenta desfazer a troca. Pastas desconhecidas, sem o manifesto do GameModz, não são sobrescritas. Instalação, atualização e remoção são bloqueadas com a interface aberta ou restauração pendente.

Se o computador ou o processo de instalação encerrar durante a troca, execute o instalador novamente. Um registro persistente permite recuperar a instalação anterior antes de continuar. Não apague as pastas `GameModz.backup-*`, `GameModz.stage-*` ou o arquivo `.GameModz-transaction.json` enquanto houver recuperação pendente.

## Desinstalar

Restaure os ajustes e feche o programa. Procure **Desinstalar GameModz** no menu Iniciar ou execute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\Programs\GameModz\Uninstall.ps1"
```

Remove os arquivos do programa e seus atalhos. **Preserva `%LOCALAPPDATA%\GameModz`**, com preferências e recuperação. Não há registro na lista Aplicativos instalados do Windows nesta versão; use o atalho ou o comando acima.

## Recuperação e segurança

Antes de aplicar ajustes, o GameModz grava os valores originais, prepara a recuperação no login e exige confirmação de um guardião independente. O estado usa gravação durável e cópia de segurança. Falhas parciais mantêm as pendências e bloqueiam nova ativação por cima.

No desligamento, reinício ou logout normal, tenta restaurar sem cancelar o encerramento do Windows. Após falta de energia ou encerramento forçado, tenta recuperar no próximo login do mesmo usuário, desde que os arquivos e a execução estejam disponíveis. Exclusão dos snapshots, bloqueio da inicialização e falha de disco limitam essa recuperação.

Para restaurar manualmente, reabra o GameModz ou execute:

```powershell
& "$env:LOCALAPPDATA\GameModz\Recovery\GameModz.ps1" -Acao Desativar -NaoInterativo
```

Não apague `estado.json` nem `estado.json.bak` com restauração pendente. Reabrir aplicativos não garante recuperar documentos ou abas. Leia **[SAFETY.md](SAFETY.md)** para conhecer as proteções e seus limites.

## Desenvolvimento e testes

```powershell
git clone https://github.com/Guilhermecmt/GameModz.git
cd GameModz
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Test-All.ps1
```

Para incluir prévias da interface e compilação:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Test-All.ps1 -Render -Build
```

Os testes cobrem restauração parcial, corrupção de snapshots, identidade/prioridade de processos, falha da interface, login, callback de desligamento, instalação, atualização e desinstalação. A aparência é simulada e os processos cuja prioridade é alterada são descartáveis. O monitor lê processos reais. A instalação é testada com atalhos reais em pastas temporárias; não substitui a instalação do usuário. Os testes não desligam a máquina nem medem FPS.

`Build.ps1` usa o compilador C# do .NET Framework e a versão em `VERSION`. Para abrir a interface sem recompilar:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\GameModz-UI.ps1
```

## Documentação e versões

- [Histórico de versões](CHANGELOG.md)
- [Proteções e recuperação](SAFETY.md)
- [Manual detalhado](LEIA-ME.md)
- [Pesquisa e decisões de desempenho](PESQUISA-UX-DESEMPENHO.md)
- [Origem da arte](assets/PROMPT.md)

O projeto usa `VERSION` e tags `vMAJOR.MINOR.PATCH`. Preferências, snapshots, logs e dados pessoais ficam fora do Git.
