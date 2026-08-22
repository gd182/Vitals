<h1 align="center">Vitals</h1>

<p align="center">
  Легкий монитор CPU, GPU и RAM для строки меню macOS, созданный на C++ и SwiftUI
</p>

###

<div align="center">
  <img src="https://skillicons.dev/icons?i=swift" height="40" alt="Swift logo" />
  <img width="12" />
  <img src="https://skillicons.dev/icons?i=cpp" height="40" alt="C++ logo" />
</div>

###

<p align="center">
  <a href="README.md">English</a> · <b>Русский</b>
</p>

## О проекте

Vitals — приложение для строки меню macOS, которое показывает статистику CPU, GPU и RAM в реальном времени. Сбор данных — опрос железа, список процессов и чтение сенсоров — реализован на C++20 без сторонних зависимостей. Интерфейс написан на SwiftUI: индикаторы в строке меню, popover-dashboard с настраиваемыми блоками, градиентные графики истории и окно настроек.

Проект создан как учебное исследование границы между Swift/SwiftUI-интерфейсом и нативным C++-ядром, соединенным через Objective-C++ bridge.

## Что отслеживает

| Раздел | Метрики |
|---|---|
| CPU | Загрузка, температура, разбивка system / user / idle, топ процессов по CPU |
| GPU | Утилизация, render load, tiler load, нагрузка Neural Engine (ANE), занятая / общая VRAM |
| RAM | Memory pressure, занятая / свободная / общая память, топ процессов по RAM |

## Как работает

Каждый цикл обновления проходит в два этапа:

1. **C++ core** — `CPUStats`, `GPUStats`, `MemoryStats` и `ProcessStats` напрямую обращаются к IOKit, SMC и `/bin/ps`. Результаты собираются в простые структуры и передаются в bridge.

2. **SwiftUI frontend** — `SystemViewModel` хранит опубликованное состояние и управляет таймером. Views наблюдают за view model через `@EnvironmentObject` и обновляют только ту часть интерфейса, данные которой изменились. Dashboard построен как `ForEach` по стабильному массиву `[DashboardBlock]`; блоки описаны value types (`BlockContent` enum), поэтому SwiftUI корректно diff-ит их и popover остается привязанным к нужному элементу.

## Архитектура

Vitals разделен на три слоя:

- `Core/` — C++20 collectors для CPU, GPU, памяти, сенсоров и процессов.
- `Bridge/` — Objective-C++ wrapper, который открывает нативные метрики для Swift.
- `ViewModels/` и `Views/` — состояние SwiftUI, интерфейс строки меню, dashboard, графики и настройки.

## Требования

- macOS 13 Ventura или новее
- Xcode 15+
- Apple Silicon или Intel Mac

## Сборка

```bash
git clone https://github.com/gd182/Vitals.git
cd Vitals
open Vitals.xcodeproj
```

Пакетный менеджер и внешние зависимости не нужны. Выбери схему `Vitals` и нажми `Cmd+R`.

## Инструменты для разработки

`test/load.py` — Python-скрипт для стресс-теста CPU. Запускает по одному busy-loop worker на каждое ядро и плавно поднимает нагрузку до заданного процента:

```bash
python3 test/load.py 80     # 80% CPU load
python3 test/load.py 50 5   # ramp to 50% over 5 seconds
```

Полезно для проверки, что графики, thresholds и индикаторы в строке меню правильно реагируют на реальную нагрузку.

## Лицензия

MIT — см. [LICENSE](LICENSE).
