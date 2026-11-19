import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../domain/entities/subscription_type_entity.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../widgets/subscription_drawer.dart';

/// صفحة شحن تفعيلات لنوع اشتراك
class RechargeActivationsPage extends StatefulWidget {
  const RechargeActivationsPage({required this.subscriptionType, super.key});

  final SubscriptionTypeEntity subscriptionType;

  @override
  State<RechargeActivationsPage> createState() =>
      _RechargeActivationsPageState();
}

class _RechargeActivationsPageState extends State<RechargeActivationsPage>
    with SaveOperationMixin<RechargeActivationsPage> {
  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  final FormattingService _formattingService =
      GetIt.instance<FormattingService>();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  double _totalPrice = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // اقتراح سعر افتراضي بناءً على سعر نوع الاشتراك
    _priceController.text = _formattingService.formatNumber(
      widget.subscriptionType.price / 30, // سعر تقريبي للتفعيلة
    );
    _calculateTotal();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price =
        double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;
    setState(() {
      _totalPrice = quantity * price;
    });
  }

  void _rechargeActivations() async {
    if (_formKey.currentState!.validate() && !_operationCompleted) {
      final quantity = int.parse(_quantityController.text);
      final pricePerActivation = double.parse(
        _priceController.text.replaceAll(',', ''),
      );

      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      final bloc = context.read<SubscriptionBloc>();

      bloc.add(
        RechargeActivationsEvent(
          subscriptionTypeId: widget.subscriptionType.id,
          subscriptionTypeName: widget.subscriptionType.name,
          quantity: quantity,
          pricePerActivation: pricePerActivation,
          organizationEmail: user?.email ?? '',
          createdBy: user?.displayName ?? 'المدير',
        ),
      );

      // انتظار النتيجة مع مهلة زمنية لمنع التعليق إلى ما لا نهاية
      try {
        await bloc.stream
            .firstWhere(
              (state) =>
                  state is ActivationRechargeSuccess || state is SubscriptionError,
            )
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () => SubscriptionError('انتهت مهلة العملية'),
            );
      } on TimeoutException {
        // معالجة انتهاء المهلة
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // إعادة تحميل بيانات أنواع الاشتراكات
      if (mounted) {
        final subscriptionBloc = GetIt.instance<SubscriptionBloc>();
        subscriptionBloc.add(const LoadSubscriptionTypesEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const SubscriptionDrawer(currentRoute: 'recharge_activations'),
      body: BlocListener<SubscriptionBloc, SubscriptionState>(
        listenWhen: (previous, current) {
          return current is ActivationRechargeSuccess ||
              current is SubscriptionError;
        },
        listener: (context, state) {
          if (state is ActivationRechargeSuccess && !_operationCompleted) {
            _operationCompleted = true;
            // ✅ شاشة كاملة: بعد نجاح الشحن
            // تعود للشاشة السابقة
            completeSaveOperation(
              successMessage: state.message,
              navigateBackOnSuccess: true,
            );
          } else if (state is SubscriptionError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildWelcomeCard(context),
              _buildCurrentBalanceCard(context),
              _buildFormCard(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AssyrianTheme.backgroundGradient,
          boxShadow: [
            BoxShadow(
              color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          AssyrianTheme.getLamassuForBackground(
            isDarkBackground: true,
            hasCircularBackground: false,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'شحن تفعيلات',
                  style: AssyrianTheme.titleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    color: AssyrianTheme.primaryGold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  widget.subscriptionType.name,
                  style: AssyrianTheme.subtitleStyle.copyWith(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(
                      context,
                      mobile: 10,
                    ),
                    color: AssyrianTheme.ivoryWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close,
            color: AssyrianTheme.primaryGold,
            size: 24.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return const DetailScreenHeader(
      title: 'شحن تفعيلات جديدة',
      subtitle: 'إضافة تفعيلات جديدة لنوع الاشتراك',
      icon: Icons.add_shopping_cart,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildCurrentBalanceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AssyrianTheme.primaryGold.withValues(alpha: 0.2),
            AssyrianTheme.deepBlue.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: AssyrianTheme.primaryGold,
                  size: 32.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التفعيلات المتبقية',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          '${widget.subscriptionType.activationQuantity}',
                          style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'تفعيلة',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.subscriptionType.activationQuantity == 0) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'تنبيه: لا يوجد تفعيلات متاحة! يجب شحن التفعيلات لتمكين إنشاء الاشتراكات.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.red[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الشحن',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AssyrianTheme.deepBlue,
              ),
            ),
            SizedBox(height: 16.h),
            _buildQuantityField(),
            SizedBox(height: 16.h),
            _buildPriceField(),
            SizedBox(height: 16.h),
            _buildTotalPriceCard(),
            SizedBox(height: 24.h),
            BlocBuilder<SubscriptionBloc, SubscriptionState>(
              builder: (context, state) {
                final isLoading = state is SubscriptionLoading;
                return Row(
                  children: [
                    Expanded(
                      child: LoadingButton(
                        text: 'تأكيد الشحن',
                        onPressed: isLoading ? null : _rechargeActivations,
                        isLoading: isLoading || _isLoading,
                        icon: Icons.shopping_cart,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AssyrianTheme.deepBlue,
                          side: const BorderSide(color: AssyrianTheme.deepBlue),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      onChanged: (value) => _calculateTotal(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'عدد التفعيلات *',
        prefixIcon: Icon(
          Icons.numbers,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'عدد التفعيلات مطلوب';
        }
        final quantity = int.tryParse(value);
        if (quantity == null || quantity <= 0) {
          return 'أدخل رقم صحيح أكبر من صفر';
        }
        return null;
      },
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      onChanged: (value) => _calculateTotal(),
      keyboardType: TextInputType.number,
      inputFormatters: [_formattingService.getPriceInputFormatter()],
      decoration: InputDecoration(
        labelText: 'سعر التفعيلة *',
        prefixIcon: Icon(
          Icons.attach_money,
          size: 20.sp,
          color: AssyrianTheme.primaryGold,
        ),
        suffixText: 'د.ع',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AssyrianTheme.primaryGold),
        ),
        labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'سعر التفعيلة مطلوب';
        }
        final price = double.tryParse(value.replaceAll(',', ''));
        if (price == null || price <= 0) {
          return 'أدخل سعر صحيح أكبر من صفر';
        }
        return null;
      },
    );
  }

  Widget _buildTotalPriceCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.1),
            Colors.teal.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green[700], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'السعر الإجمالي',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _formattingService.formatCurrency(_totalPrice),
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'سيتم خصم هذا المبلغ من الصندوق',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
