# Histórico de versões

## 1.2.0 — 2026-11-04

- Instalador por usuário via `Install.cmd` ou PowerShell, sem administrador, Git ou compilação.
- Instalação/atualização em `%LOCALAPPDATA%\Programs\GameModz` e atalhos automáticos na área de trabalho e no menu Iniciar.
- Download de versão identificada por tag, validação de pacote e cópia somente dos arquivos necessários.
- Atualização com staging e rollback; bloqueio com aplicativo aberto ou restauração pendente.
- Desinstalação que preserva preferências, recuperação e atalhos substituídos por outro programa.
- README reorganizado e testes isolados do instalador e desinstalador.

## 1.1.0 — 2026-11-04

- Restauração automática ao fechar a janela, inclusive quando o fechamento é solicitado durante uma operação. Falhas mantêm a janela e o snapshot disponíveis.
- Guardião independente com confirmação de inicialização e identidade do processo proprietário. A interface restaura se o guardião parar.
- Tentativa de restauração no encerramento da sessão do Windows, com limite de espera e sem cancelar o desligamento.
- Recuperação no próximo login após falta de energia, encerramento forçado ou falha parcial; scripts copiados para o perfil do usuário.
- Snapshot durável com substituição atômica, cópia de segurança, leitura de backup e bloqueio de ativação quando existe recuperação pendente.
- Wallpaper original copiado antes da alteração; fundos dinâmicos e múltiplos monitores são preservados. Fundo preto e efeitos temporários não são gravados permanentemente no perfil do Windows.
- Restauração independente de checklist corrompido; erros parciais retornam falha ao chamador e mantêm as pendências.
- Testes de fechamento, falhas, processo encerrado, PID reutilizado, login e callback de desligamento em ambiente isolado.

## 1.0.0 — 2026-11-03

- Primeira versão publicada, interface WPF, checklist, monitor e restauração manual.
