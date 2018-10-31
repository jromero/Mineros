# Blaze

[Ember](https://github.com/EmberCrypto/Ember)'s Official Miner.

### Compilation

```
git clone https://github.com/EmberCrypto/Blaze
cd Blaze
nimble install https://github.com/EmberCrypto/BN nimcrypto https://github.com/EmberCrypto/Argon2 https://github.com/EmberCrypto/ec_bls
```

After installing `ec_bls`, you do need to set it up. Instructions on how to can be found [here](https://github.com/EmberCrypto/ec_bls).

```
nim c src/main.nim
```
