# Receitas ujust para enroll da MOK do MT7902.
# Ficheiro instalado pelo build da imagem aurora-mt7902 / bluefin-dx-mt7902.

# Enroll de TODAS as chaves MOK necessárias (uBlue akmods + MT7902 out-of-tree)
# em uma única operação. Use ESTA em vez de `ujust enroll-secure-boot-key`.
# Senha sugerida: "universalblue" (mesma convenção da uBlue) — mas pode ser
# qualquer outra; defina no prompt e use a mesma no MokManager no próximo boot.
enroll-secure-boot-key-all:
    @echo ">>> Enroll de chaves MOK: uBlue akmods + MT7902"
    @echo ">>> Senha sugerida: universalblue"
    @echo ">>> Você definirá UMA senha; será pedida no MokManager no próximo boot."
    sudo mokutil --import \
        /etc/pki/akmods/certs/akmods-ublue.der \
        /etc/pki/mt7902/mt7902-signing.der
    @echo ">>> Pronto. Reinicie, selecione 'Enroll MOK' no MokManager,"
    @echo ">>> confirme as 2 chaves e digite a senha que você acabou de definir."

# Fallback: enroll só da nossa chave (caso usuário já tenha rodado
# `enroll-secure-boot-key` da uBlue antes e não queira refazer).
enroll-mt7902-key:
    sudo mokutil --import /etc/pki/mt7902/mt7902-signing.der
