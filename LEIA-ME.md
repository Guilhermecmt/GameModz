# GameModz 1.2.0

Instalacao: extraia o ZIP e execute Install.cmd. Tambem pode usar powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1. Cria atalhos na area de trabalho e menu Iniciar; detalhes e comando de download no README.

Protecoes e limites: [SAFETY.md](SAFETY.md). Versoes: [CHANGELOG.md](CHANGELOG.md).

## Checklist e aplicativos

**Checklist:** cada ajuste registra fase, resultado e detalhe em `%LOCALAPPDATA%\GameModz\checklist.json`. Selecione uma etapa com falha e use Repetir item selecionado. A repeticao usa o snapshot original e nao refaz etapas concluidas. Falhas de restauracao mantem estado.json ate serem resolvidas. Estados salvos de versoes anteriores continuam restauraveis; suas etapas aparecerao como estado anterior ate a restauracao. O checklist persiste apos fechar a janela. O detalhe de reabertura se refere ao aplicativo, nao a recuperacao de documentos ou abas.

**Aplicativos:** monitor somente enquanto esta pagina esta aberta e a janela nao esta minimizada. Coleta a cada 2 segundos, fora da interface. Mostra processos desktop acessiveis da sessao atual agrupados por nome, excluindo componentes dentro da pasta Windows e os hosts do GameModz. CPU e a fracao do tempo total de CPU, normalizada pelos processadores logicos; pode diferir da coluna de utilizacao do Gerenciador de Tarefas. A primeira amostra ainda nao possui intervalo para medir CPU. RAM soma conjuntos de trabalho e pode contar memoria compartilhada mais de uma vez. Tres amostras consecutivas de CPU >= 5% ou RAM >= 512 MB em segundo plano geram alerta; esses limites sao apenas indicativos.

Nenhuma intervencao e automatica. Com o modo ativo, selecione um aplicativo compativel e escolha Reduzir prioridade ou Solicitar fechamento. Acoes permitidas: chrome, msedge, firefox, opera, brave, discord, spotify, wallpaper32, wallpaper64 e thunderbird. Outros programas aparecem como somente leitura. Processos em primeiro plano e de outra sessao sao recusados. O backend revalida PID, instante de criacao e caminho; nao depende apenas dos dados exibidos na tabela.

Reduzir prioridade usa BelowNormal somente quando a prioridade original e Normal. A restauracao recupera o valor original no mesmo processo; se ele encerrou ou a prioridade foi alterada depois, preserva essa situacao. Aplicativos que ja estavam em BelowNormal nao sao assumidos pelo GameModz. O fechamento solicita CloseMainWindow e nunca mata processos; janelas podem recusar, e processos residentes podem continuar. Fechar a interface restaura automaticamente; sair apenas do jogo mantem o modo enquanto a interface estiver aberta. Consulte SAFETY.md para recuperacao apos falhas e desligamento.

Testes: Test-Session.ps1 cobre repeticao isolada, restauracao parcial, migracao e prioridade em processo descartavel; Test-Monitor.ps1 verifica coleta real e encerramento; -TestarCiclo testa tambem o encaminhamento dos botoes novos com backend simulado. Esses testes nao medem ganho de FPS.

## Interface visual

Abra **GameModz.exe** ou **GameModz.lnk** para iniciar sem janela de terminal. O executavel e um lancador grafico pequeno, compilado a partir de Launcher.cs; inicia o PowerShell com CreateNoWindow. Mantenha-o junto dos scripts e de Interface.xaml. O icone verde permanece na janela e no atalho. A imagem decorativa lateral foi removida; o unico botao principal usa verde, simbolo de energia e textos de progresso. Os arquivos .cmd sao atalhos legados e podem mostrar um breve console ao serem abertos pelo Windows; prefira o .exe ou .lnk.

OneDrive: o pedido de encerramento espera no maximo 5 segundos pela saida do processo original. Se nao houver confirmacao, registra aviso e continua os outros ajustes; nao mata o OneDrive. Como ele estava aberto antes, a restauracao ainda solicita sua abertura, inclusive quando o encerramento nao foi confirmado. O progresso aparece no painel Atividade. A opcao de sincronizacao nao garante que o OneDrive aceitou o comando.

Validacoes: Test-OneDrive.ps1 testa encerramento e timeout com processos simulados. GameModz-UI.ps1 -TestarCiclo testa ativacao, restauracao e falha com backend simulado, sem modificar o computador. Os testes verificam que o botao volta a ficar disponivel.

Abra **Abrir-GameModz.cmd** para usar a interface grafica WPF. Escolha as opcoes em Preferencias e use o unico botao principal para ativar ou restaurar. Fechar a janela aguarda a operacao atual e restaura antes de sair. Se houver falhas, mantem a janela e o snapshot disponiveis. O painel de atividade mostra o relatorio real do script. Reduzir movimento desliga as transicoes de navegacao. A restauracao ocorre ao fechar o GameModz, por botao e pelos mecanismos de recuperacao; sair apenas do jogo nao encerra o modo. As preferencias do aplicativo sao salvas ao fechar a janela.

A versao clean usa controles nativos estilizados, sem pulsacao permanente. A arte anterior, gerada por image_gen, foi preservada em assets/power-core.png, com prompt em assets/PROMPT.md. CPU, GPU e memoria sao detectados uma vez, fora da interface, e exibidos no rodape. Nenhuma dependencia de navegador ou servico externo para ativar/restaurar. Os atalhos da pagina Melhorias abrem Configuracoes do Windows ou documentacao online.

As cinco melhorias de FPS sao recomendacoes guiadas; nao sao aplicadas nem restauradas automaticamente. Consulte PESQUISA-UX-DESEMPENHO.md para as fontes e proximos passos.

Correcao de aparencia: a versao atual altera somente a propriedade de transparencia, preservando a escolha de tema dos aplicativos e do Windows. Test-Appearance.ps1 verifica essa preservacao em uma chave de teste descartavel, sem alterar o tema real.

Abra GameModz.cmd e escolha Ativar ou Desativar. Nao exige administrador.

Ao ativar: fundo preto, efeitos de interface reduzidos e transparencia desabilitada. O Windows pode demorar para refletir a transparencia em janelas ja abertas. As preferencias originais ficam em `%LOCALAPPDATA%\GameModz\estado.json`. Nao apague esse arquivo enquanto houver restauracao pendente.

Opcoes pelo terminal, na pasta do projeto:

```powershell
# Para ativar, abra GameModz.exe (a interface fornece a identidade do proprietario).
.\GameModz.ps1 -Acao Desativar
.\GameModz.ps1 -Acao Status
```

O plano de energia atual e mantido para preservar o brilho. O parametro legado AltoDesempenho apenas informa essa restricao e nao troca o plano. OneDrive e encerrado pelo comando do proprio aplicativo e reiniciado ao restaurar, somente se estava rodando. Nao e uma pausa universal de downloads: Steam e outros launchers devem ter seus downloads pausados na propria interface.

FecharApps e optativo: somente chrome, msedge, firefox, opera, brave, discord, spotify, wallpaper32 e wallpaper64. Envia um pedido normal de fechamento apenas para janelas visiveis; nao mata processos. Salve seu trabalho antes. Aplicativos residentes podem continuar na bandeja. A restauracao oferece reabri-los, mas nao recupera documentos, abas ou argumentos de inicializacao. Papel de parede animado so para se o aplicativo correspondente aceitar o pedido de fechamento. Fundos dinamicos detectados e configuracoes com varios monitores sao preservados. Uma copia do wallpaper estatico permite restaurar se o original desaparecer.

Se o computador reiniciar ou a interface for interrompida, o guardiao e a recuperacao no login tentam restaurar automaticamente. A reabertura do GameModz tambem inicia a restauracao pendente. Consulte SAFETY.md para limites e recuperacao manual. Nao altera firewall, antivirus, servicos, prioridades do jogo ou anticheat. Nao monitora FPS e nao promete aumento de desempenho.

O GameModz nao ajusta brilho nem troca o plano de energia ao ativar. A opcao de alto desempenho foi retirada da interface. Estados antigos ainda podem restaurar seu plano original; novos estados nao ativam essa alteracao.
