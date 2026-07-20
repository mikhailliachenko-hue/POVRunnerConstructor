# Round 02 — визуальная библия окружения

## Главная цель

Игрок должен бежать внутри блочного Overworld-пейзажа, а не по отдельной яркой
дороге над уменьшенным макетом. В кадре постоянно нужны земля и архитектура
рядом с камерой, средний план из деревьев/домов и дальний рельеф.

## Официальные визуальные источники

1. https://www.minecraft.net/en-us/about-minecraft — масштаб ландшафта,
   постройки, встроенные в склоны, читаемый горизонт.
2. https://www.minecraft.net/en-us/article/exploring-minecraft — маршрут через
   рельеф, опасные перепады, здания как ориентиры путешествия.
3. https://help.minecraft.net/hc/en-us/articles/360046470431-Minecraft-Types-of-Biomes
   — характерные поверхности, растительность и силуэты биомов.
4. https://www.minecraft.net/en-us/article/forest — плотность деревьев и
   перекрывающиеся планы леса.
5. https://www.minecraft.net/en-us/article/around-block--cherry-grove —
   сочетание открытого пути, склонов и растительности рядом с игроком.
6. https://www.minecraft.net/en-us/article/around-block--plains — ровная
   проходимая поверхность с редкими деревьями и дальними ориентирами.
7. https://www.minecraft.net/en-us/article/desert — перепады блочного рельефа,
   колодцы и деревни как ориентиры.
8. https://www.minecraft.net/en-us/article/the-trails---tales-update — путь и
   последовательное открытие новых объектов как основа композиции.
9. https://www.minecraft.net/en-us/article/minecraft-java-edition-1-18-1 —
   видимость дальнего рельефа и управляемый туман.
10. https://www.minecraft.net/en-us/article/minecraft-snapshot-21w41a — долина,
    обрамлённая крупным рельефом, вместо объектов только на горизонте.
11. https://www.minecraft.net/en-us/article/caves---cliffs-update-part-ii-coming
    — крупный рельеф и вертикальная слоистость пространства.
12. https://www.minecraft.net/en-us/article/village---pillage-out-today-java
    — деревни и архитектура, формирующие проходы на уровне игрока.

## Художественные выводы

- Размер блока должен ощущаться соразмерным игроку; масштаб нельзя оценивать
  только по полной длине AABB.
- Поверхность маршрута должна быть земляной/каменной и принадлежать миру.
- Ближний план обязан давать параллакс по обе стороны камеры.
- Крупные ориентиры должны последовательно приближаться и уходить назад.
- Небо остаётся фоном, но не должно занимать кадр вместе с одной огромной
  однотонной дорогой.
- Трасса читается тонкими границами и препятствиями, а не насыщенным цветным
  полотном, перекрывающим локацию.

## Лицензия исходного GLB

- Title: Minecraft world
- Author: guus — https://sketchfab.com/guusvanhouten1
- Source: https://sketchfab.com/3d-models/minecraft-world-8ee90583b45749c387a9c45e95031cd1
- License: CC BY 4.0
