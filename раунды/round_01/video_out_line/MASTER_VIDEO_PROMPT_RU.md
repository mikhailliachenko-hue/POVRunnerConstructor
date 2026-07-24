# Мастер-промпт фонового видео для POV Runner

Этот шаблон создаёт зацикленное окружение для раннера. Настоящая 3D-дорожка, её текстура, препятствия и компаньон добавляются в Godot поверх видео.

## Единственная переменная

Замените только значение в строке ниже:

```text
SETTING = Minecraft
```

Примеры: `Roblox`, `Minecraft`, `LEGO fantasy world`, `candy kingdom`, `cyberpunk city`, `prehistoric jungle`.

## Основной промпт

```text
Create a seamless cinematic background video for a first-person endless runner game.

SETTING: [SETTING]

The viewer is moving continuously straight forward through a highly detailed, coherent [SETTING] world. The camera is centered exactly on a straight running route and travels forward at a constant speed. Eye-level first-person POV, symmetrical forward composition, fixed camera height, fixed focal length, stable horizon, smooth linear motion.

A broad straight road runs from the bottom center of the frame toward one central vanishing point on the horizon. Keep the road perfectly centered and keep its direction unchanged for the entire shot. The lower and middle central road area will be covered by a real-time 3D road inside the game. The visible road in this video acts as a natural continuation of that 3D road into the far distance. Its perspective must remain geometrically stable, with no changes in width, direction, height, or vanishing point.

Build the complete [SETTING] environment around both sides of the road: terrain, vegetation, architecture, distant landmarks, atmospheric depth, sky, clouds, environmental particles and subtle ambient life appropriate to [SETTING]. Side scenery moves naturally past the viewer with convincing forward-motion parallax. Nearby scenery passes faster, distant scenery moves slowly, and the horizon remains stable.

Keep a wide, clean gameplay corridor over the entire road. No characters, creatures, vehicles, gates, walls, branches, decorations, signs, particles, shadows or foreground objects may enter or cross the road corridor. All important scenery stays clearly on the left and right sides or far in the distance. Interactive obstacles, companions and effects will be rendered separately in 3D over this video.

The motion must feel like a polished mobile endless runner: energetic but comfortable, readable and suitable for exercise gameplay. Constant forward velocity. No acceleration or deceleration. No camera shake, head bob, handheld motion, strafing, drifting, tilting, rolling, zooming, turning, jumping, ducking or collision. No cuts and no scene transitions.

Preserve strict temporal consistency. Architecture and terrain must not melt, morph, pop, duplicate, flicker or teleport. Straight lines remain straight. Objects appear in the distance, approach naturally and pass outside the left or right edges. Lighting, weather, time of day, color palette and visual style remain identical throughout the clip.

Full-screen landscape video, 16:9, 1920x1080, 30 fps, high detail, sharp stable image, clean edges, game-ready composition. No player body, no hands, no HUD, no interface, no text, no captions, no logos, no watermark, no borders, no black bars.

The opening and ending camera state must be visually compatible: identical road alignment, camera height, horizon, forward speed, lighting and overall scene density. Design the motion so this clip can be joined to another clip made from the same prompt without a visible jump.
```

## Negative prompt

```text
camera shake, handheld camera, head bob, camera turn, curved road, road intersection, fork in the road, sideways movement, orbiting camera, changing camera height, unstable horizon, changing focal length, zoom, speed ramp, acceleration, braking, jump, fall, collision, cut, transition, fade, foreground obstruction, object crossing the road, character on the road, creature on the road, vehicle on the road, gameplay obstacle, gate, wall across the road, UI, HUD, text, logo, watermark, player body, hands, flicker, jitter, stutter, warping, morphing, melting geometry, duplicated objects, popping objects, inconsistent lighting, inconsistent style, blur, low detail, black bars
```

## Как получить `background_1`, `background_2`, `background_3`

1. Подставьте сеттинг и сгенерируйте первый клип. Сохраните его как `background_1`.
2. Создавайте `background_2` через функцию **Extend / Continue video**, используя конец `background_1`. Не генерируйте второй клип с нуля.
3. Аналогично продолжите `background_2` и сохраните результат как `background_3`.
4. Для замыкания цикла дайте генератору последний кадр `background_3` как начальный референс, а первый кадр `background_1` — как конечный референс. Используйте тот же основной и негативный промпт.
5. Обрежьте служебные дублирующиеся кадры на стыках. Все три файла должны иметь одинаковые разрешение, FPS, кодек и цветовой профиль.

Если генератор не умеет задавать конечный кадр, сделайте `background_3` продолжением второго клипа, а переход `background_3 → background_1` скройте коротким плавным смешиванием в игре.

## Правило кадра

Центральная дорога в видео допустима и желательна: настоящая 3D-дорожка закроет её в ближней и средней части кадра. Нарисованная дорога останется видна вдали и визуально продолжит игровой маршрут до горизонта.
