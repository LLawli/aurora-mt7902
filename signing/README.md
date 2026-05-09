# MT7902 Module Signing

Esta pasta contém a **chave pública** (`mt7902-signing.der`) usada para verificar
a assinatura dos módulos `mt7902e.ko` e `btusb_mt7902.ko` em sistemas com Secure
Boot ativo.

## Setup inicial (uma vez)

1. Gerar par de chaves MOK:
   ```bash
   openssl req -new -x509 -newkey rsa:2048 \
       -keyout mt7902-signing.priv -outform DER -out mt7902-signing.der \
       -nodes -days 36500 -subj "/CN=MT7902 Module Signing/"
   ```

2. Commitar a pública no repo (esta pasta):
   ```bash
   mv mt7902-signing.der signing/
   git add signing/mt7902-signing.der
   git commit -m "signing: add MT7902 module signing public key"
   ```

3. Adicionar a privada como secret no GitHub:
   ```bash
   base64 -w0 mt7902-signing.priv | gh secret set MT7902_SIGNING_KEY -R llawli/uBlue-mt7902
   ```

4. Apagar a privada local:
   ```bash
   shred -u mt7902-signing.priv
   ```

## Quando regenerar

Se a privada vazar ou for perdida, gere um novo par e refaça os passos 2-4.
Todos os dispositivos que já fizeram `ujust enroll-secure-boot-key-all` precisarão
fazer enroll novamente da nova chave.

## Build sem chave

Se `signing/mt7902-signing.der` não existir, o `build.sh` pula a assinatura e
imprime aviso. A imagem ainda builda — útil para testes em VM sem Secure Boot.
Não use essa imagem em sistema com Secure Boot ativo.
