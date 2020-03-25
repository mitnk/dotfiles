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
2. Setup & enable Trime on phone.
3. Run following command:
```
scp -r -P 8022 trime-configs/* x@192.168.0.104:/sdcard/rime/
```
4. Re-deploy Trime on your phone.
5. Select Danjing / 炫彩 from Config page.
