# Rime on Mac OS X

## Install Rime

via [https://rime.im/](https://rime.im/)

## Install dicts

```
git clone https://github.com/rime/rime-wubi
cp rime-wubi/*.yaml ~/Library/Rime/
git clone https://github.com/rime/rime-pinyin-simp
cp rime-pinyin-simp/*.yaml ~/Library/Rime/
```

## Install configs from this dir:

```
cp default.custom.yaml  squirrel.custom.yaml ~/Library/Rime/
```

## Config for TRime (Rime for Android)

1. Install [Trime](https://play.google.com/store/apps/details?id=com.osfans.trime)
from Google Play Store

2. Run following command:

```
scp -P 8022 trime-configs/*.yaml x@192.168.0.104:/sdcard/rime/
```

3. Re-deploy Trime on your phone.
