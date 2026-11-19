import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/maintenance_request_entity.dart';
import '../bloc/maintenance_bloc.dart';
import 'delete_maintenance_dialog.dart';

/// أزرار الإجراءات لطلبات الصيانة
class MaintenanceActionButtons extends StatelessWidget {
  const MaintenanceActionButtons({
    required this.maintenanceRequest,
    required this.maintenanceBloc,
    super.key,
    this.onEdit,
    this.onDeleted,
    this.showEditButton = true,
    this.showDeleteButton = true,
  });

  final MaintenanceRequestEntity maintenanceRequest;
  final MaintenanceBloc maintenanceBloc;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final bool showEditButton;
  final bool showDeleteButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showEditButton) ...[
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: Icon(Icons.edit, size: 16.sp),
            label: const Text('تعديل'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
          ),
          SizedBox(width: 8.w),
        ],
        if (showDeleteButton)
          OutlinedButton.icon(
            onPressed: () => _showDeleteDialog(context),
            icon: Icon(Icons.delete, size: 16.sp),
            label: const Text('حذف'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
          ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    DeleteMaintenanceDialog.show(
      context,
      maintenanceRequest,
      maintenanceBloc,
      onDeleted: onDeleted,
    );
  }
}
