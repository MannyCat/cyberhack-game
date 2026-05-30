import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Tutorial Provider — отслеживание прогресса обучения ────────────────────

class TutorialProvider extends ChangeNotifier {
  static const String _keyCompleted = 'tutorial_completed';
  static const String _keyStep = 'tutorial_step';

  bool _isCompleted = false;
  int _currentStep = 0;
  bool _isTutorialVisible = false;

  bool get isCompleted => _isCompleted;
  int get currentStep => _currentStep;
  bool get isTutorialVisible => _isTutorialVisible;

  TutorialProvider() {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _isCompleted = prefs.getBool(_keyCompleted) ?? false;
    _currentStep = prefs.getInt(_keyStep) ?? 0;
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, _isCompleted);
    await prefs.setInt(_keyStep, _currentStep);
  }

  void showTutorial() {
    _isTutorialVisible = true;
    if (_isCompleted) {
      _currentStep = 0;
      _isCompleted = false;
    }
    notifyListeners();
  }

  void hideTutorial() {
    _isTutorialVisible = false;
    notifyListeners();
  }

  void goToStep(int step) {
    if (step >= 0 && step < _tutorialSteps.length) {
      _currentStep = step;
      notifyListeners();
    }
  }

  void nextStep() {
    if (_currentStep < _tutorialSteps.length - 1) {
      _currentStep++;
      notifyListeners();
    } else {
      completeTutorial();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void completeTutorial() {
    _isCompleted = true;
    _isTutorialVisible = false;
    _saveProgress();
    notifyListeners();
  }

  void resetTutorial() {
    _isCompleted = false;
    _currentStep = 0;
    _saveProgress();
    notifyListeners();
  }
}

// ─── Шаги обучения ──────────────────────────────────────────────────────────

class TutorialStep {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String? tip;

  const TutorialStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    this.tip,
  });
}

const List<TutorialStep> _tutorialSteps = [
  TutorialStep(
    id: 'welcome',
    title: 'ДОБРО ПОЖАЛОВАТЬ В CYBERHACK',
    subtitle: 'Многопользовательская онлайн-стратегия о хакерстве',
    description: 'Вы — начинающий хакер в мире кибервойн. Ваша цель — построить мощную сеть, атаковать чужие базы, зарабатывать кредиты и стать легендой. Пройдите обучение, чтобы понять основы игры и начать свой путь к вершине рейтинга.',
    icon: Icons.bolt,
    color: Color(0xFF00F0FF),
    tip: 'Обучение состоит из 7 шагов. Изучите каждый, чтобы быстро освоить игру.',
  ),
  TutorialStep(
    id: 'base',
    title: 'МОЯ БАЗА',
    subtitle: 'Сердце вашей хакерской сети',
    description: 'База — это ваши сетевые узлы. Каждый узел генерирует ресурсы: кредиты, ЦПУ и канал. Чем больше узлов — тем больше доход. Узлы бывают разных типов:\n\nСЕРВЕР — генерирует кредиты, ЦПУ и канал. Основной доход.\nБАЗА ДАННЫХ — генерирует кредиты, отличный доход.\nМАЙНЕР — спец. узел для добычи кредитов.\nРОУТЕР — увеличивает канал.\nПРОКСИ — значительно усиливает канал.\nФАЙРВОЛ — защита от атак.\nСКАНЕР — обнаружение целей.\nТЕРМИНАЛ — универсальный узел.',
    icon: Icons.dns,
    color: Color(0xFF00ff41),
    tip: 'Начните с 1 сервера, потом добавляйте майнеры для быстрого дохода.',
  ),
  TutorialStep(
    id: 'resources',
    title: 'РЕСУРСЫ',
    subtitle: 'Валюта кибер-мира',
    description: 'В игре 3 основных ресурса:\n\nКРЕДИТЫ — основная валюта. Нужны для постройки узлов, улучшений и покупок на рынке. Зарабатываются автоматически от узлов и через атаки.\n\nЦПУ (THz) — вычислительная мощность. Тратится на атаки. Каждый тип атаки требует разное количество ЦПУ.\n\nКАНАЛ (MB/s) — пропускная способность. Влияет на силу атаки и скорость сканирования целей.\n\nВсе ресурсы пополняются автоматически каждые 30 секунд от онлайн-узлов.',
    icon: Icons.monetization_on,
    color: Color(0xFFFFD700),
    tip: 'Не тратьте все кредиты сразу — держите запас для улучшений.',
  ),
  TutorialStep(
    id: 'map',
    title: 'КАРТА МИРА',
    subtitle: 'Глобальная сеть',
    description: 'Карта мира — это интерактивное отображение всех узлов и соединений. Здесь вы можете:\n\nНаходить цели для атак — чужие узлы отображаются красным цветом.\nНавигировать — зум + перемещение мышью.\nВыбирать узлы — двойной клик по узлу открывает панель действий.\nСКАНИРОВАТЬ — сканирование показывает все цели в радиусе.\n\nВаши узлы выделены зелёным, чужие — красным. Линии между узлами — сетевые соединения.',
    icon: Icons.public,
    color: Color(0xFF00e5ff),
    tip: 'Начните атаку с ближайших целей — меньше расход ресурсов.',
  ),
  TutorialStep(
    id: 'attack',
    title: 'АТАКА',
    subtitle: 'Взлом чужих баз',
    description: 'Атака — основной способ заработка кредитов и XP.\n\nКак атаковать:\n1. Откройте раздел «Атака» в меню.\n2. Выберите цель из списка доступных игроков.\n3. Выберите тип атаки (DDoS, SQL-инъекция, фишинг и т.д.).\n4. Оценьте затраты и возможную добычу.\n5. Запустите атаку.\n\nРезультат зависит от:\n- Вашего ЦПУ и канала\n- Защиты цели (файрвол, уровень)\n- Типа атаки\n\nПри успешной атаке вы крадёте кредиты у цели.',
    icon: Icons.gps_fixed,
    color: Color(0xFFFF0040),
    tip: 'Атакуйте игроков с низким уровнем — выше шанс успеха и меньше потерь.',
  ),
  TutorialStep(
    id: 'daily',
    title: 'НАГРАДЫ И МИССИИ',
    subtitle: 'Ежедневный бонус и задания',
    description: 'ЕЖЕДНЕВНАЯ НАГРАДА:\nЗаходите каждый день и забирайте награду. Чем больше дней подряд (стрик) — тем больше кредитов и XP.\n\nМИССИИ:\nЗадания с наградами за выполнение:\n- «Первый узел» — разверните узел\n- «Первый взлом» — проведите атаку\n- «Расширение сети» — 3 узла\n- «Кибервойн» — 5 атак\n\nВыполненные миссии можно забрать за кредиты и XP.',
    icon: Icons.card_giftcard,
    color: Color(0xFFFFD700),
    tip: 'Не забывайте заходить каждый день — стрик-бонус растёт!',
  ),
  TutorialStep(
    id: 'social',
    title: 'БАНДА, ЧАТ И РЫНОК',
    subtitle: 'Мультиплеер и экономика',
    description: 'БАНДА (клан):\nСоздайте или вступите в клан. Кланы дают бонусы и открывают клановые войны.\n\nЧАТ:\nОбщий и клановый чат для общения с игроками.\n\nЧЁРНЫЙ РЫНОК:\nПокупайте снаряжение: вирусы, эксплойты, усиления.\nПредметы дают бонусы к атаке, защите и доходу.\n\nРЕЙТИНГ:\nСоревнование с другими хакерами. Поднимайтесь в таблице лидеров!\n\nДОСТИЖЕНИЯ:\nОткрывайте достижения за прогресс в игре.',
    icon: Icons.groups,
    color: Color(0xFFa855f7),
    tip: 'Клан — это сила. Вместе легче защищаться и атаковать.',
  ),
  TutorialStep(
    id: 'start',
    title: 'НАЧНИТЕ ИГРУ!',
    subtitle: 'Вы готовы к взлому',
    description: 'Обучение завершено! Вот ваш план действий:\n\n1. МОЯ БАЗА — постройте первый сервер.\n2. Добавьте майнер для быстрого дохода.\n3. Защитите базу файрволом.\n4. Откройте КАРТУ МИРА и изучите цели.\n5. Проведите первую АТАКУ.\n6. Заберите ЕЖЕДНЕВНУЮ НАГРАДУ.\n7. Купите снаряжение на РЫНКЕ.\n8. Найдите БАНДУ или создайте свою.\n\nУдачи, хакер! Мир киберпространства ждёт вас.',
    icon: Icons.rocket_launch,
    color: Color(0xFF00ff41),
    tip: 'Если забыли что-то — обучение всегда доступно в главном меню.',
  ),
];
