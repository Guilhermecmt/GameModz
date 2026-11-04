# Referencias e decisoes — 03/11/2026

## Interface

O design usa hierarquia, espacamento e navegacao lateral inspirados no macOS. Mantem os controles de janela do Windows e nao usa controles decorativos que fingem ser botoes. Uma unica acao principal alterna entre ativar e restaurar; a arte anterior foi preservada na pasta assets, mas saiu da tela principal.

As orientacoes de movimento da Apple recomendam animacoes breves, com funcao clara e opcionais. Implementamos transicao de opacidade de 180 ms com easing, somente ao navegar. Nao ha pulsacao permanente, blur de tela ou loop de particulas. O sistema respeita a preferencia de animacao do Windows e o controle Reduzir movimento.

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- https://developer.apple.com/design/human-interface-guidelines/motion

CPU, GPU e memoria ficam no rodape: sao contexto permanente, nao competem com a acao principal. A deteccao e feita uma vez em trabalho separado; nao ha consulta WMI constante durante o jogo. Os dados completos ficam nos tooltips. A GPU exibida e a dedicada detectada quando encontrada; isso nao comprova que o jogo esta usando essa GPU.

## Pares

| Produto | Referencia observada | Decisao para GameModz |
|---|---|---|
| Razer Cortex | Auto-Boost e ajustes de graficos por jogo; suporte mostra configuracoes otimizadas | Mostrar o que sera alterado e distinguir ajuste de sistema de configuracao do jogo |
| Process Lasso | Regras por processo, troca de plano de energia e ProBalance para responsividade | Priorizar intervencoes selecionadas e reversiveis; nao elevar processos indiscriminadamente |
| Windows | Modo de Jogo, preferencia de GPU e otimizacoes por aplicativo | Usar caminhos oficiais e verificar compatibilidade |

Fontes dos fabricantes, sem adotar suas alegacoes como medicao independente de FPS:

- https://mysupport.razer.com/app/answers/detail/a_id/6104/~/razer-cortex-10-support-%26-faqs
- https://bitsum.com/process-lasso-faq/
- https://bitsum.com/how-probalance-works/

## Cinco opcoes propostas na interface

1. GPU de alto desempenho por jogo: relevante em maquinas hibridas. Atalho para Graficos do Windows.
2. Revisar gravacao em segundo plano: util se estiver ativa e disputando recursos. Atalho para Capturas. O artigo Xbox abaixo e historico; o principio de custo da captura permanece, mas a interface atual e a do Windows instalado.
3. Conferir Modo de Jogo nativo: recurso do Windows, ganho dependente de carga. Atalho para Modo de Jogo.
4. Testar otimizacoes de jogos em janela: Windows 11, jogos DirectX 10/11 compativeis, com foco em latencia de apresentacao. Nao e garantia de mais FPS para todos os jogos.
5. Perfil grafico por jogo: sombras, distancia de visao e resolucao conforme gargalo. DLSS/FSR somente onde suportados; nao sao adicionados ao DayZ por este script.

Essas cinco opcoes sao recomendacoes guiadas, nao fazem parte da ativacao automatica nem da restauracao do GameModz. A interface informa isso explicitamente. Seus botoes abrem configuracoes oficiais ou documentacao.

- https://support.microsoft.com/en-us/windows/hardware/display-graphics/optimizations-for-windowed-games-in-windows-11
- https://devblogs.microsoft.com/directx/navigating-the-redesigned-graphics-settings-page/
- https://www.microsoft.com/en-is/windows/windows-11-pc-gaming
- https://news.xbox.com/en-us/2016/10/14/tips-on-windows-10-and-game-dvr-optimization/
- https://www.nvidia.com/en-us/geforce/technologies/dlss/

## Qualidade antes de prometer ganhos

Proximo passo recomendado: perfis por executavel e restauracao automatica com monitor independente da janela. Depois, comparar sessoes equivalentes com e sem os ajustes usando captura de frametime, FPS medio e 1% low. Repetir o mesmo trajeto, resolucao e condicoes; no DayZ, servidor e quantidade de jogadores podem influenciar bastante. Esses recursos ainda nao foram implementados.

Nao ha benchmark medido nesta entrega. Nenhuma porcentagem de ganho deve ser exibida. Prioridades em tempo real, limpeza recorrente de RAM, apagamento de caches e desativacao de seguranca nao fazem parte da implementacao.

## Correcao do tema dos aplicativos

Foi identificado que New-Item -Force em uma chave de Registro existente recria a chave e apaga seus valores. A versao inicial fazia isso em Themes/Personalize antes de alterar EnableTransparency, removendo preferencias de tema. A correcao cria a chave apenas quando ausente e usa New-ItemProperty para alterar exclusivamente EnableTransparency. Test-Appearance.ps1 exercita a funcao real em chave descartavel, com 8 combinacoes de temas claro/escuro e transparencia, preservando outro valor sentinela. Nenhum teste de regressao altera a chave de aparencia real.

Como os valores anteriores nao foram salvos pela versao antiga, nao foi possivel reconstruir todas as preferencias apagadas. AppsUseLightTheme foi devolvido a 0 (escuro), conforme o usuario informou. O tema de sistema nao foi presumido. Esta correcao nao fecha nem reabre o WhatsApp.
