import 'package:shared_preferences/shared_preferences.dart';

/// Сервис вспомогательного хранилища (аналог iOS UserDefaults на базе SharedPreferences).
/// Сохраняет:
/// 1. Параметры сортировки списка ('title', 'year', 'rating')
/// 2. Выбранный режим отображения сетки (сетка / список)
/// 3. Установленный лимит прочитанных книг на текущий год (аналитическая цель)
class UserPreferencesService {
  UserPreferencesService._();
  static final UserPreferencesService instance = UserPreferencesService._();

  static const String _keySortBy = 'ui_sort_by';
  static const String _keyIsGridView = 'ui_is_grid_view';
  static const String _keyYearlyGoal = 'analytics_yearly_goal';

  // Дефолтные значения
  static const String defaultSortBy = 'title';
  static const bool defaultIsGridView = true;
  static const int defaultYearlyGoal = 10;

  /// Получение сохраненного параметра сортировки списка
  Future<String> getSortBy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySortBy) ?? defaultSortBy;
  }

  /// Сохранение параметра сортировки списка
  Future<void> setSortBy(String sortBy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySortBy, sortBy);
  }

  /// Получение выбранного режима отображения (true = сетка/полка, false = список)
  Future<bool> getIsGridView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsGridView) ?? defaultIsGridView;
  }

  /// Сохранение выбранного режима отображения
  Future<void> setIsGridView(bool isGridView) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGridView, isGridView);
  }

  /// Получение целевого лимита прочитанных книг на текущий год
  Future<int> getYearlyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyYearlyGoal) ?? defaultYearlyGoal;
  }

  /// Сохранение целевого лимита прочитанных книг на текущий год
  Future<void> setYearlyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyYearlyGoal, goal);
  }

  /// Загрузка всех сохраненных настроек разом при старте приложения
  Future<UserPreferencesData> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final sortBy = prefs.getString(_keySortBy) ?? defaultSortBy;
    final isGridView = prefs.getBool(_keyIsGridView) ?? defaultIsGridView;
    final yearlyGoal = prefs.getInt(_keyYearlyGoal) ?? defaultYearlyGoal;

    return UserPreferencesData(
      sortBy: sortBy,
      isGridView: isGridView,
      yearlyGoal: yearlyGoal,
    );
  }
}

/// Модель данных пользовательских настроек интерфейса и аналитики
class UserPreferencesData {
  final String sortBy;
  final bool isGridView;
  final int yearlyGoal;

  const UserPreferencesData({
    required this.sortBy,
    required this.isGridView,
    required this.yearlyGoal,
  });
}
