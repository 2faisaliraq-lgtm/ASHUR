import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/empty_state_widget.dart';
import '../../domain/entities/report_entity.dart';
import 'report_card.dart';
/// شبكة التقارير
class ReportsGrid extends StatelessWidget {

  const ReportsGrid({
    required this.reports, required this.onReportTap, super.key,
    this.isGridView = false,
  });
  final List<ReportEntity> reports;
  final Function(ReportEntity) onReportTap;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.analytics_outlined,
          title: 'لا توجد تقارير',
          message: 'لا توجد تقارير متاحة حالياً',
        ),
      );
    }

    if (isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildGridView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final report = reports[index];
          return ReportCard(
            report: report,
            onTap: () => onReportTap(report),
            isListView: false,
          );
        }, childCount: reports.length),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final report = reports[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ReportCard(
              report: report,
              onTap: () => onReportTap(report),
            ),
          );
        }, childCount: reports.length),
      ),
    );
  }
}
