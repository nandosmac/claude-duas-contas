# Claude Duas Contas

Use **duas contas do Claude Desktop ao mesmo tempo no mesmo Mac**, por exemplo a pessoal e a do trabalho, sem ficar saindo e entrando toda hora.

O script cria uma cópia do Claude com um login separado ("Claude - Pessoal", "Claude - Profissional" ou o nome que você quiser). Tudo é feito por janelas do próprio macOS, sem precisar digitar comandos.

> Não é um app oficial da Anthropic. Use por sua conta e risco. Se o Mac for da empresa, confira antes com a TI.

## Como usar

1. Baixe o arquivo **`Claude Duas Contas.command`** (botão **Code > Download ZIP** e descompacte).
2. Abra o **Terminal** (Cmd + Espaço, digite "Terminal" e aperte Enter).
3. Digite `bash` seguido de **um espaço**, **arraste o arquivo** para dentro da janela do Terminal e aperte **Enter**.
4. Siga as janelas: escolha **"Criar ou atualizar a segunda conta"**, dê um nome e, se quiser, escolha uma imagem para o ícone.

> Por que não dar dois cliques? O macOS bloqueia scripts baixados da internet. O jeito com `bash` + arrastar evita esse bloqueio.

## Primeiro login (importante)

Faça o login **um app de cada vez**:

1. Feche todos os Claudes (Cmd + Q).
2. Abra só o app novo e entre com a conta dele. Se o Mac pedir sua senha (Keychain), digite e clique em **Permitir sempre**.
3. Feche ele, abra o Claude original e entre com a outra conta.

Depois disso, os dois podem ficar abertos juntos.

## Quando o Claude atualizar

Se os dois apps começarem a abrir na mesma conta, rode o script de novo e escolha **"Criar ou atualizar"**. O login e o histórico são mantidos.

## Remover

Rode o script e escolha **"Remover a segunda conta"**. O Claude original não é alterado.

## Como funciona

O Claude Desktop é feito em Electron, que aceita a opção `--user-data-dir`. O script copia o app, faz a cópia guardar os dados numa pasta própria (`~/Library/Application Support/Claude-<nome>`), troca o identificador do app e reassina a cópia localmente para o macOS aceitar abrir.

## Créditos

Este script reúne e simplifica o método descrito por:

- **Rafael Pazini**: [Claude Desktop com duas contas no macOS](https://dev.to/rflpazini/claude-desktop-com-duas-contas-no-macos-como-rodar-pessoal-e-empresa-lado-a-lado-5aik) ([scripts originais](https://github.com/rflpazini/articles/tree/main/claude-desktop-dual-account))
- **Rodrigo Peixoto**: [Como usar duas contas do Claude Desktop no Mac — guia simples](https://www.linkedin.com/pulse/como-usar-duas-contas-do-claude-desktop-mac-pessoal-e-rodrigo-peixoto-zmfnf/)

Feito por [@nandosmac](https://www.youtube.com/@nandosmac). Assista ao tutorial no canal.
