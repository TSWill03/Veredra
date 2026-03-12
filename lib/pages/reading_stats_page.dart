// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../models/book_reading_stats.dart';
import '../models/library_entry.dart';
import '../models/reading_progress.dart';
import '../services/progress_service.dart';
import '../services/reading_stats_service.dart';

class ReadingStatsPage extends StatefulWidget {
  const ReadingStatsPage({
    super.key,
    required this.entries,
    required this.readingStatsService,
    required this.progressService,
  });

  final List<LibraryEntry> entries;
  final ReadingStatsService readingStatsService;
  final ProgressService progressService;

  @override
  State<ReadingStatsPage> createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends State<ReadingStatsPage> {
  bool _isLoading = true;
  Map<String, BookReadingStats> _stats = const <String, BookReadingStats>{};
  Map<String, ReadingProgress> _progresses = const <String, ReadingProgress>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Map<String, BookReadingStats> stats =
        await widget.readingStatsService.loadAllStats();
    final Map<String, ReadingProgress> progresses =
        await widget.progressService.loadAllProgresses();
    if (!mounted) {
      return;
    }

    setState(() {
      _stats = stats;
      _progresses = progresses;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_BookStatsView> rankedBooks = widget.entries
        .where((LibraryEntry entry) => _stats.containsKey(entry.id))
        .map(
          (LibraryEntry entry) => _BookStatsView(
            entry: entry,
            stats: _stats[entry.id]!,
            progress: _progresses[entry.id],
          ),
        )
        .where(
            (view) => view.stats.totalSeconds > 0 || view.stats.openedCount > 0)
        .toList(growable: false)
      ..sort((a, b) => b.stats.totalSeconds.compareTo(a.stats.totalSeconds));

    final int totalSeconds = _stats.values.fold<int>(
      0,
      (int sum, BookReadingStats value) => sum + value.totalSeconds,
    );
    final int totalSessions = _stats.values.fold<int>(
      0,
      (int sum, BookReadingStats value) => sum + value.sessionCount,
    );
    final int openedBooks =
        _stats.values.where((value) => value.openedCount > 0).length;
    final int favorites =
        widget.entries.where((entry) => entry.isFavorite).length;
    final Map<String, int> aggregatedDaily = _aggregateDailySeconds();
    final DateTime now = DateTime.now();
    final int todaySeconds =
        aggregatedDaily[BookReadingStats.dateKey(now)] ?? 0;
    final int weekSeconds = _aggregateLastDays(aggregatedDaily, 7, now);
    final int streakDays = _aggregateStreak(aggregatedDaily, now);
    final List<_DailyReadingView> lastWeek =
        _lastWeekViews(aggregatedDaily, now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatisticas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatCard(
                      title: 'Tempo total',
                      value: _formatDuration(totalSeconds),
                      subtitle: 'Tempo somado das leituras registradas.',
                    ),
                    _StatCard(
                      title: 'Hoje',
                      value: _formatDuration(todaySeconds),
                      subtitle: 'Leitura acumulada de hoje.',
                    ),
                    _StatCard(
                      title: 'Ultimos 7 dias',
                      value: _formatDuration(weekSeconds),
                      subtitle: 'Quanto voce leu nesta semana.',
                    ),
                    _StatCard(
                      title: 'Sequencia',
                      value: '$streakDays dia(s)',
                      subtitle: 'Dias seguidos com leitura.',
                    ),
                    _StatCard(
                      title: 'Sessoes',
                      value: '$totalSessions',
                      subtitle: 'Quantas vezes voce realmente leu.',
                    ),
                    _StatCard(
                      title: 'Livros abertos',
                      value: '$openedBooks',
                      subtitle: 'Titulos com alguma atividade de leitura.',
                    ),
                    _StatCard(
                      title: 'Favoritos',
                      value: '$favorites',
                      subtitle: 'Livros marcados como favoritos hoje.',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Panorama', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        rankedBooks.isEmpty
                            ? 'As estatisticas comecam a aparecer depois que voce abre e passa um tempo lendo no Veredra.'
                            : 'Estes numeros ajudam a acompanhar ritmo, livros mais lidos e progresso recente.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Ultimos 7 dias', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (final _DailyReadingView day in lastWeek) ...<Widget>[
                        Row(
                          children: <Widget>[
                            SizedBox(
                              width: 62,
                              child: Text(
                                day.label,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  value: day.ratio,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 72,
                              child: Text(
                                _formatDuration(day.seconds),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        if (day != lastWeek.last) const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Livros mais lidos', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (rankedBooks.isEmpty)
                  const _StatsEmptyState()
                else
                  for (final _BookStatsView view in rankedBooks)
                    _BookStatsCard(view: view),
              ],
            ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0 min';
    }

    final Duration duration = Duration(seconds: totalSeconds);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '$minutes min';
    }
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}min';
  }

  Map<String, int> _aggregateDailySeconds() {
    final Map<String, int> result = <String, int>{};
    for (final BookReadingStats stats in _stats.values) {
      for (final MapEntry<String, int> entry in stats.dailySeconds.entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    return result;
  }

  int _aggregateLastDays(Map<String, int> daily, int days, DateTime now) {
    int total = 0;
    for (int offset = 0; offset < days; offset++) {
      final DateTime date = now.subtract(Duration(days: offset));
      total += daily[BookReadingStats.dateKey(date)] ?? 0;
    }
    return total;
  }

  int _aggregateStreak(Map<String, int> daily, DateTime now) {
    int streak = 0;
    for (int offset = 0;; offset++) {
      final DateTime date = now.subtract(Duration(days: offset));
      if ((daily[BookReadingStats.dateKey(date)] ?? 0) <= 0) {
        break;
      }
      streak++;
    }
    return streak;
  }

  List<_DailyReadingView> _lastWeekViews(Map<String, int> daily, DateTime now) {
    final List<_DailyReadingView> items = <_DailyReadingView>[];
    int maxSeconds = 0;
    for (int offset = 6; offset >= 0; offset--) {
      final DateTime date = now.subtract(Duration(days: offset));
      final int seconds = daily[BookReadingStats.dateKey(date)] ?? 0;
      if (seconds > maxSeconds) {
        maxSeconds = seconds;
      }
      items.add(
        _DailyReadingView(
          label: _weekdayLabel(date.weekday),
          seconds: seconds,
          ratio: 0,
        ),
      );
    }

    final int effectiveMax = maxSeconds <= 0 ? 1 : maxSeconds;
    return items
        .map(
          (item) => _DailyReadingView(
            label: item.label,
            seconds: item.seconds,
            ratio: item.seconds / effectiveMax,
          ),
        )
        .toList(growable: false);
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sab';
      case DateTime.sunday:
        return 'Dom';
    }
    return '--';
  }
}

class _DailyReadingView {
  const _DailyReadingView({
    required this.label,
    required this.seconds,
    required this.ratio,
  });

  final String label;
  final int seconds;
  final double ratio;
}

class _BookStatsView {
  const _BookStatsView({
    required this.entry,
    required this.stats,
    required this.progress,
  });

  final LibraryEntry entry;
  final BookReadingStats stats;
  final ReadingProgress? progress;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _BookStatsCard extends StatelessWidget {
  const _BookStatsCard({
    required this.view,
  });

  final _BookStatsView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = view.progress?.chapterProgress ?? 0;
    final DateTime? lastReadAt = view.stats.lastReadAt;
    final String totalTime = _formatDuration(view.stats.totalSeconds);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(view.entry.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      view.entry.reference.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(totalTime),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress.clamp(0, 1)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              Chip(
                label: Text('${view.stats.sessionCount} sessao(oes)'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('${view.stats.openedCount} abertura(s)'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  'Capitulo ${view.stats.lastChapterIndex + 1}/${view.entry.chapterCount}',
                ),
                visualDensity: VisualDensity.compact,
              ),
              if (lastReadAt != null)
                Chip(
                  label: Text('Ultima leitura ${_formatDate(lastReadAt)}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final Duration duration = Duration(seconds: totalSeconds);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '${duration.inMinutes} min';
    }
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}min';
  }

  String _formatDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

class _StatsEmptyState extends StatelessWidget {
  const _StatsEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.query_stats_rounded, size: 38),
          const SizedBox(height: 14),
          Text('Ainda nao ha estatisticas suficientes',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Abra um livro e passe algum tempo lendo para o Veredra montar seu panorama de leitura.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
