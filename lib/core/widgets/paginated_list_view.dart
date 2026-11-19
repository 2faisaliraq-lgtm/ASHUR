import 'package:material_ui/material_ui.dart';

/// ListView builder that requests the next page near the end and keeps the
/// viewport filled when the current page is shorter than the screen.
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.itemBuilder,
    this.controller,
    this.padding,
    super.key,
  });

  final List<T> items;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  bool _requestInFlight = false;
  bool _requestFailed = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_handleScroll);
    _scheduleFillCheck();
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleScroll);
      widget.controller?.addListener(_handleScroll);
    }
    final itemCountChanged = widget.items.length != oldWidget.items.length;
    if (itemCountChanged) {
      _requestInFlight = false;
      _requestFailed = false;
    } else if (oldWidget.isLoadingMore && !widget.isLoadingMore) {
      _requestInFlight = false;
      _requestFailed = widget.hasMore;
    }
    if (oldWidget.hasMore != widget.hasMore ||
        oldWidget.isLoadingMore != widget.isLoadingMore ||
        itemCountChanged) {
      _scheduleFillCheck();
    }
  }

  void _scheduleFillCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestIfNearEnd();
    });
  }

  void _handleScroll() => _requestIfNearEnd();

  void _retryLoadMore() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    setState(() {
      _requestFailed = false;
      _requestInFlight = true;
    });
    widget.onLoadMore();
  }

  bool get _isNearEnd {
    final controller = widget.controller;
    if (controller == null || !controller.hasClients) return false;
    final position = controller.position;
    final threshold = (position.viewportDimension * 0.25).clamp(160.0, 360.0);
    return position.extentAfter <= threshold;
  }

  void _requestIfNearEnd() {
    if (!widget.hasMore || widget.isLoadingMore || _requestInFlight) return;
    if (!_isNearEnd) return;
    _requestInFlight = true;
    widget.onLoadMore();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFooter = widget.hasMore || widget.isLoadingMore;
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      itemCount: widget.items.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < widget.items.length) {
          return widget.itemBuilder(context, index);
        }
        if (_requestFailed && widget.hasMore && !widget.isLoadingMore) {
          return Center(
            child: TextButton.icon(
              onPressed: _retryLoadMore,
              icon: const Icon(Icons.refresh),
              label: const Text('تعذر تحميل المزيد — أعد المحاولة'),
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      },
    );
  }
}
