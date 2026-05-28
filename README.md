# CyberHack — Многопользовательская Онлайн Стратегия о Хакерстве

> **2077 год. Корпорации контролируют сеть. Стань хакером, построй свою сеть, атакуй противников и доминируй в цифровом мире.**

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?logo=windows)

---

## Возможности

- **Авторизация** — регистрация/вход через Supabase Auth
- **Сетевая карта** — интерактивная визуализация сети с перетаскиванием узлов
- **6 типов узлов** — серверы, файрволы, роутеры, базы данных, майнинг-риг, прокси
- **6 типов атак** — DDoS, Малварь, Фишинг, Брутфорс, SQL-инъекция, Zero-Day
- **Кланы** — создавай команды, объединяйся с другими хакерами
- **Чёрный рынок** — покупай оборудование, софт и эксплойты
- **Realtime мультиплеер** — обновления в реальном времени через Supabase Realtime
- **Рейтинговая таблица** — соревнуйся за первое место
- **Cyberpunk UI** — тёмная тема с неоновыми акцентами

---

## Стек технологий

| Компонент | Технология |
|-----------|-----------|
| Frontend | Flutter 3.44 (Windows) |
| Бэкенд | Supabase (PostgreSQL, Auth, Realtime) |
| Роутинг | GoRouter |
| Управление состоянием | Provider |
| Хостинг кода | GitHub |

---

## Установка и запуск

### Предварительные требования

- [Flutter SDK 3.44+](https://docs.flutter.dev/get-started/install/windows) (с поддержкой Windows Desktop)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) (с компонентом "Desktop development with C++")
- Git

### Шаг 1. Клонирование

```bash
git clone https://github.com/MannyCat/cyberhack-game.git
cd cyberhack-game
```

### Шаг 2. Установка зависимостей

```bash
flutter pub get
```

### Шаг 3. Настройка Supabase

1. Открой [Supabase Dashboard](https://supabase.com/dashboard)
2. Перейди в **SQL Editor**
3. Скопируй и выполни содержимое файла `lib/supabase/schema.sql`
4. Затем выполни `lib/supabase/seed_data.sql` для начальных данных рынка
5. Убедись что **Email Auth** включён в **Authentication > Providers**
6. Отключи **Email Confirmation** в **Authentication > Settings** (для удобства тестирования)

### Шаг 4. Запуск

```bash
flutter run -d windows
```

---

## Структура проекта

```
lib/
├── main.dart                          # Точка входа
├── app.dart                           # GoRouter + тема + провайдеры
├── config/
│   ├── supabase_config.dart           # Конфигурация Supabase
│   └── game_config.dart               # Баланс игры (стоимости, урон, XP)
├── providers/
│   ├── auth_provider.dart             # Авторизация и профиль
│   └── game_provider.dart             # Игровое состояние + Supabase API
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart          # Экран входа (Matrix rain)
│   │   └── register_screen.dart       # Экран регистрации
│   ├── game/
│   │   ├── game_shell.dart            # Навигация (BottomNavigationBar)
│   │   ├── map_screen.dart            # Сетевая карта (CustomPainter)
│   │   ├── network_screen.dart        # Управление узлами
│   │   ├── attack_screen.dart         # Атака противников
│   │   ├── market_screen.dart         # Чёрный рынок
│   │   ├── chat_screen.dart           # Чат (терминал)
│   │   ├── clan_screen.dart           # Кланы
│   │   └── leaderboard_screen.dart    # Рейтинг
│   ├── main_menu_screen.dart          # Главное меню
│   ├── settings_screen.dart           # Настройки
│   └── profile_screen.dart            # Профиль игрока
├── supabase/
│   ├── schema.sql                     # SQL схема базы данных
│   └── seed_data.sql                  # Начальные данные
└── widgets/
    ├── cyber_button.dart              # Неоновая кнопка
    └── resource_bar.dart             # Отображение ресурсов
```

---

## База данных

### Таблицы

| Таблица | Описание |
|---------|----------|
| `profiles` | Профили игроков (ресурсы, уровень, XP) |
| `clans` | Кланы/команды |
| `clan_members` | Участники кланов |
| `network_nodes` | Сетевые узлы игроков |
| `attacks` | Журнал атак |
| `chat_messages` | Сообщения чата |
| `market_items` | Товары чёрного рынка |
| `player_inventory` | Инвентарь игроков |
| `player_stats` | Статистика для рейтинга |

Все таблицы защищены **Row Level Security (RLS)** политиками.

---

## Игровая механика

### Ресурсы
- **Кредиты** (CR) — валюта для покупок
- **CPU** — мощность для атак
- **Пропускная способность** — для сканирования и defence

### Система уровней
- Каждый 1000 XP = +1 уровень
- XP начисляется за атаки (50 за победу, 10 за поражение)
- Профили создаются автоматически при регистрации

### Кланы
- До 20 участников
- Роли: Leader, Officer, Member
- Совместные атаки (в планах)

---

## Лицензия

MIT License — свободно используй и модифицируй.
