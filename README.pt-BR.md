# Clipstack

Histórico da área de transferência para macOS, nativo, na barra de menus. Feito para
substituir o CopyClip, com tudo o que o CopyClip 2 tem e mais imagens, arquivos,
cores e snippets com variáveis.

*[English](README.md)*

## O que faz

- Guarda texto, texto formatado, links, cores (`#RRGGBB`), imagens e arquivos copiados no Finder.
- Painel no estilo Spotlight (Liquid Glass no macOS 26): busca instantânea, filtros, prévia ao lado.
- Cola direto no app em uso, sem ⌘V; ⇧↩ cola como texto puro.
- Fixar itens no topo, editar e renomear, salvar como snippet.
- Snippets com `{date}`, `{time}`, `{datetime}`, `{weekday}`, `{clipboard}`, `{uuid}` e `{date:FORMATO}`.
- Menu compacto no cursor, com um segundo atalho.
- Ignora senhas (`org.nspasteboard.ConcealedType` e afins) e apps que você escolher.
- Pausar a gravação por 15 minutos, 1 hora ou até retomar.
- Mostra de que app veio cada item.

## Idiomas

Inglês (idioma-base), português (Brasil), espanhol, francês, alemão, italiano, japonês e
chinês simplificado. O app segue o idioma do macOS e, em Ajustes → Geral → Language, dá
para escolher outro só para ele.

Os textos ficam em `Resources/Localizable.xcstrings`, que o Xcode abre como um editor de
traduções. Depois de criar textos novos no código, `Scripts/update-strings.sh` adiciona
as chaves ao catálogo, sem perder as traduções que já existem.

## Atalhos

| Atalho | Ação |
|---|---|
| ⇧⌘V | Abrir o histórico |
| ⌃⇧V | Menu no cursor |
| ↩ / ⇧↩ / ⌥↩ | Colar / texto puro / só copiar |
| ⌘1 … ⌘0 | Colar um dos dez primeiros |
| ⇥ | Trocar de filtro |
| Espaço ou ⌘Y | Mostrar ou esconder a prévia |
| ⌘P · ⌘E · ⌘S · ⌘⌫ | Fixar · editar · salvar como snippet · apagar |

Os dois atalhos globais mudam em Ajustes → Atalhos.

## Build

Precisa do Xcode 16 ou mais novo (Swift 6.2).

```sh
Scripts/build-app.sh            # build/Clipstack.app
Scripts/build-app.sh --install  # e instala em /Applications
Scripts/notarize.sh             # notariza e gera um zip para distribuir
```

O script assina com o certificado **Developer ID Application** do Keychain, o mesmo do
Speakly e do Hippocampus. A assinatura precisa ser estável: o macOS liga a permissão
de Acessibilidade a ela, e uma assinatura ad hoc pediria a permissão de novo a cada build.

O ícone é `Resources/AppIcon.icon`, no formato do Icon Composer: o build o compila com o
`actool` num `Assets.car`, que o macOS 26 desenha no formato e no vidro dele, e num `.icns`
para versões anteriores. Um ícone só em `.icns` aparece no macOS 26 encolhido dentro de um
quadrado cinza. Para trocar a arte, rode `Scripts/make-icon-layer.swift` com a imagem nova.

A notarização reaproveita a credencial `hippocampus` do `notarytool`. Só é necessária
para instalar em outro Mac.

## Permissões

- **Acessibilidade**: para colar direto no app em uso (o Clipstack simula ⌘V). Sem ela, o
  item é copiado e você cola com ⌘V. O próprio app pede na primeira vez.
- Nenhuma outra. O app não é sandboxed e não acessa a rede.

## Sincronizar pelo iCloud

O código já está pronto (SwiftData com CloudKit), mas a Apple só libera o iCloud para
apps com um App ID e um perfil de provisionamento:

1. Em [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list),
   crie o App ID `com.rodolfobortolin.Clipstack` com a capability **iCloud** (CloudKit) e o
   container `iCloud.com.rodolfobortolin.Clipstack`.
2. Crie um perfil **Developer ID** para esse App ID e salve como
   `Resources/embedded.provisionprofile`.
3. Crie `Resources/Clipstack.entitlements`:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.application-identifier</key>
       <string>T39P8Y6S8L.com.rodolfobortolin.Clipstack</string>
       <key>com.apple.developer.team-identifier</key>
       <string>T39P8Y6S8L</string>
       <key>com.apple.developer.icloud-container-identifiers</key>
       <array><string>iCloud.com.rodolfobortolin.Clipstack</string></array>
       <key>com.apple.developer.icloud-services</key>
       <array><string>CloudKit</string></array>
       <key>com.apple.developer.icloud-container-environment</key>
       <string>Production</string>
   </dict>
   </plist>
   ```

4. Rode `Scripts/build-app.sh --install` e ligue em Ajustes → Privacidade.

## Como é feito

| Parte | Onde |
|---|---|
| Captura (polling do `changeCount` a cada 0,5 s) | `Core/ClipboardMonitor.swift` |
| Histórico e snippets (SwiftData) | `Core/ClipStore.swift`, `Models/` |
| Colar (pasteboard + ⌘V via `CGEvent`) | `Core/Paster.swift` |
| Atalhos globais (Carbon `RegisterEventHotKey`) | `Core/HotKeyCenter.swift` |
| Painel (`NSPanel` não ativante + SwiftUI) | `UI/Panel/` |
| Barra de menus e menu no cursor | `UI/Menus.swift` |
| Ajustes | `UI/Settings/` |

O histórico fica em `~/Library/Application Support/Clipstack/Clipstack.store`.
