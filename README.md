# README

https://human-vs-pest-t7ero6olsa-uc.a.run.app/


## 開発者向け

内部データ構造

* turn
    * game
        * players (human / pest)
            * 木材 < player
            * お金 < player
        * world
            * hexes
            * 建設物 < player
                * 木 (これだけplayerに属さない)
                * 拠点
                * 畑
            * ユニット < player
                * human / pestのみ

