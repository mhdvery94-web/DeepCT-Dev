import 'package:flutter/material.dart';

import '../models/training.dart';
import '../theme/app_theme.dart';

/// Finished training runs waiting to become model versions.
///
/// This panel is the only way out of the training pipeline — registering
/// weights *is* creating a model version — which is why it lives on Model
/// Management rather than anywhere else.
///
/// It used to be an unbounded [Column] sitting beside the model grid's
/// [Expanded], so every finished run took about eighty pixels away from the
/// grid, permanently, with no way to give them back. Eight runs left a laptop
/// window showing one row of models and a phone showing none. The only control
/// offered for clearing the panel is DELETE, and DELETE destroys the weights —
/// so the layout quietly pushed people toward the one irreversible button on
/// the screen.
///
/// So the panel now costs the grid a fixed amount no matter how many runs are
/// waiting: at most [_maxListHeight] of rows, scrolled inside its own bounds,
/// under a heading that carries the count. A list that scrolls hides its own
/// length, and the number is the part that decides whether you go looking.
class TrainingHandoffPanel extends StatelessWidget {
  const TrainingHandoffPanel({
    super.key,
    required this.jobs,
    required this.onRegister,
    required this.onDelete,
  });

  final List<TrainingJob> jobs;
  final void Function(TrainingJob job) onRegister;
  final void Function(TrainingJob job) onDelete;

  /// Roughly two rows.
  ///
  /// Enough that the panel is unmistakably present and its first entry can be
  /// acted on without scrolling; little enough that the grid above it is still
  /// a grid on a laptop window.
  static const double _maxListHeight = 188;

  /// Below this the row's two buttons and its title cannot share a line.
  ///
  /// Measured, not guessed: at 360px the horizontal [Row] overflowed by 46
  /// pixels, because `REGISTER AS MODEL` and `DELETE` have a floor width that
  /// [Expanded] on the title cannot shrink past.
  static const double _narrow = 460;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Text(
          'Training runs ready to register (${jobs.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _maxListHeight),
          child: ListView.builder(
            // Sizes to its content until it reaches the cap, so one waiting
            // run does not hold space open for runs that are not there.
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: jobs.length,
            itemBuilder: (context, index) => _row(context, jobs[index]),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, TrainingJob job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = _title(context, job);
          final actions = _actions(job);

          if (constraints.maxWidth >= _narrow) {
            return Row(children: [Expanded(child: title), ...actions]);
          }

          // On a phone the buttons drop below the title rather than being
          // squeezed off the edge. A [Wrap] rather than a [Row], because the
          // two of them together still want 374px and a 360px phone offers
          // 328 — the pair has to be allowed to break as well.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.end, children: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _title(BuildContext context, TrainingJob job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          job.name,
          style: Theme.of(context).textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${job.currentEpoch} epochs trained',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  List<Widget> _actions(TrainingJob job) {
    return [
      TextButton(
        onPressed: () => onRegister(job),
        child: const Text('REGISTER AS MODEL'),
      ),
      TextButton(
        onPressed: () => onDelete(job),
        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
        child: const Text('DELETE'),
      ),
    ];
  }
}
