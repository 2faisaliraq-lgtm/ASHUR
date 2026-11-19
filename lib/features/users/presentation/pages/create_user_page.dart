import 'dart:async';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../domain/entities/permission_entity.dart';
import '../../domain/entities/role_entity.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/permission_group_card.dart';
import '../widgets/users_drawer.dart';

/// صفحة إضافة مستخدم جديد
class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage>
    with SaveOperationMixin<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _roleCodeController = TextEditingController(); // كلمة مرور الوصول

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  List<String> selectedRoleIds = [];
  List<String> selectedCustomPermissions = []; // الصلاحيات المخصصة
  bool _enableCustomPermissions = false; // تفعيل تخصيص الصلاحيات
  final Set<String> _expandedCategories = {}; // الفئات المفتوحة
  bool _obscureRoleCode = true; // لإخفاء كلمة مرور الوصول
  bool _isCheckingDuplicate = false; // للتحقق من التكرار
  String? _duplicateCheckMessage; // رسالة التحقق من التكرار
  List<String> _suggestedNames = []; // الأسماء المقترحة
  List<String> _suggestedEmails = []; // البريد الإلكتروني المقترح
  List<String> _suggestedPhones = []; // أرقام الهواتف المقترحة
  List<String> _suggestedRoleCodes = []; // رموز الوصول المقترحة
  bool _isSearchingNames = false; // للتحقق من حالة البحث
  bool _isSearchingEmails = false; // للتحقق من حالة البحث عن البريد الإلكتروني
  bool _isSearchingPhones = false; // للتحقق من حالة البحث عن أرقام الهواتف
  bool _isSearchingRoleCodes = false; // للتحقق من حالة البحث عن رموز الوصول
  final FocusNode _nameFocusNode =
      FocusNode(); // للتحكم في التركيز على حقل الاسم
  final FocusNode _emailFocusNode =
      FocusNode(); // للتحكم في التركيز على حقل البريد الإلكتروني
  final FocusNode _phoneFocusNode =
      FocusNode(); // للتحكم في التركيز على حقل رقم الهاتف
  final FocusNode _roleCodeFocusNode =
      FocusNode(); // للتحكم في التركيز على حقل رمز الوصول
  Timer? _debounceTimer; // مؤقت لتأخير البحث
  Timer? _emailDebounceTimer; // مؤقت لتأخير البحث عن البريد الإلكتروني
  Timer? _phoneDebounceTimer; // مؤقت لتأخير البحث عن رقم الهاتف
  Timer? _roleCodeDebounceTimer; // مؤقت لتأخير البحث عن رمز الوصول

  // Overlay للمقترحات - باستخدام SuggestionsOverlay
  final LayerLink _nameLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();

  final LayerLink _emailLayerLink = LayerLink();
  final GlobalKey _emailFieldKey = GlobalKey();

  final LayerLink _phoneLayerLink = LayerLink();
  final GlobalKey _phoneFieldKey = GlobalKey();

  final LayerLink _roleCodeLayerLink = LayerLink();
  final GlobalKey _roleCodeFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersBloc>().add(const LoadRolesEvent());
      // تحميل الصلاحيات (قد نحتاجها للعرض)
      context.read<UsersBloc>().add(const LoadPermissionsEvent());
    });

    _nameController.addListener(_onNameChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
    _roleCodeController.addListener(_onRoleCodeChanged);

    // إخفاء المقترحات عند فقدان التركيز
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) {
        SuggestionsOverlay.hide();
      }
    });

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && mounted) {
        SuggestionsOverlay.hide();
      }
    });

    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus && mounted) {
        SuggestionsOverlay.hide();
      }
    });

    _roleCodeFocusNode.addListener(() {
      if (!_roleCodeFocusNode.hasFocus && mounted) {
        SuggestionsOverlay.hide();
      }
    });
  }

  @override
  void dispose() {
    SuggestionsOverlay.hide();
    _debounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _phoneDebounceTimer?.cancel();
    _roleCodeDebounceTimer?.cancel();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _jobTitleController.dispose();
    _roleCodeController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _roleCodeFocusNode.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _searchUserNames();
      _checkForDuplicateUser();
    });
  }

  void _onRoleCodeChanged() {
    _roleCodeDebounceTimer?.cancel();
    _roleCodeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _searchRoleCodes();
      _checkForDuplicateUser();
    });
  }

  void _onEmailChanged() {
    _emailDebounceTimer?.cancel();
    _emailDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _searchUserEmails();
      _checkForDuplicateUser();
    });
  }

  void _onPhoneChanged() {
    _phoneDebounceTimer?.cancel();
    _phoneDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _searchUserPhones();
      _checkForDuplicateUser();
    });
  }

  void _showNameSuggestionsOverlay() {
    if (_suggestedNames.isEmpty || !_nameFocusNode.hasFocus) return;

    final suggestions = _suggestedNames.map((name) {
      final isExact = name == _nameController.text.trim();
      return SuggestionItem(
        value: name,
        isExactMatch: isExact,
        type: SuggestionType.person,
      );
    }).toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _nameLayerLink,
      anchorKey: _nameFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _nameController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 250.h,
      showResultsCount: true,
    );
  }

  void _showRoleCodeSuggestionsOverlay() {
    if (_suggestedRoleCodes.isEmpty || !_roleCodeFocusNode.hasFocus) return;

    final suggestions = _suggestedRoleCodes.map((roleCode) {
      final isExact = roleCode == _roleCodeController.text.trim();
      return SuggestionItem(
        value: roleCode,
        isExactMatch: isExact,
        type: SuggestionType.role,
      );
    }).toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _roleCodeLayerLink,
      anchorKey: _roleCodeFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _roleCodeController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 250.h,
      showResultsCount: true,
    );
  }

  void _showEmailSuggestionsOverlay() {
    if (_suggestedEmails.isEmpty || !_emailFocusNode.hasFocus) return;

    final suggestions = _suggestedEmails.map((email) {
      final isExact = email == _emailController.text.trim();
      return SuggestionItem(
        value: email,
        isExactMatch: isExact,
        type: SuggestionType.email,
      );
    }).toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _emailLayerLink,
      anchorKey: _emailFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _emailController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 250.h,
      showResultsCount: true,
    );
  }

  void _showPhoneSuggestionsOverlay() {
    if (_suggestedPhones.isEmpty || !_phoneFocusNode.hasFocus) return;

    final suggestions = _suggestedPhones.map((phone) {
      final isExact = phone == _phoneController.text.trim();
      return SuggestionItem(
        value: phone,
        isExactMatch: isExact,
        type: SuggestionType.phone,
      );
    }).toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _phoneLayerLink,
      anchorKey: _phoneFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _phoneController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 250.h,
      showResultsCount: true,
    );
  }

  Future<void> _searchUserNames() async {
    final query = _nameController.text.trim();

    if (query.isEmpty) {
      _suggestedNames = [];
      _isSearchingNames = false;
      SuggestionsOverlay.hide();
      return;
    }

    try {
      final bloc = context.read<UsersBloc>();
      final repository = bloc.repository;

      final result = await repository.searchUserNames(query: query);

      result.fold(
        (failure) {
          _suggestedNames = [];
          _isSearchingNames = false;
          SuggestionsOverlay.hide();
        },
        (names) {
          _suggestedNames = names;
          _isSearchingNames = false;
          if (names.isNotEmpty && _nameFocusNode.hasFocus) {
            _showNameSuggestionsOverlay();
          } else {
            SuggestionsOverlay.hide();
          }
        },
      );
    } on Exception catch (_) {
      _suggestedNames = [];
      _isSearchingNames = false;
      SuggestionsOverlay.hide();
    }
  }

  Future<void> _searchRoleCodes() async {
    final query = _roleCodeController.text.trim();

    if (query.isEmpty) {
      _suggestedRoleCodes = [];
      _isSearchingRoleCodes = false;
      SuggestionsOverlay.hide();
      return;
    }

    try {
      final bloc = context.read<UsersBloc>();
      final repository = bloc.repository;

      final result = await repository.searchRoleCodes(query: query);

      result.fold(
        (failure) {
          _suggestedRoleCodes = [];
          _isSearchingRoleCodes = false;
          SuggestionsOverlay.hide();
        },
        (roleCodes) {
          _suggestedRoleCodes = roleCodes;
          _isSearchingRoleCodes = false;
          if (roleCodes.isNotEmpty && _roleCodeFocusNode.hasFocus) {
            _showRoleCodeSuggestionsOverlay();
          } else {
            SuggestionsOverlay.hide();
          }
        },
      );
    } on Exception catch (_) {
      _suggestedRoleCodes = [];
      _isSearchingRoleCodes = false;
      SuggestionsOverlay.hide();
    }
  }

  Future<void> _searchUserEmails() async {
    final query = _emailController.text.trim();

    if (query.isEmpty || query.length < 3) {
      _suggestedEmails = [];
      _isSearchingEmails = false;
      SuggestionsOverlay.hide();
      return;
    }

    try {
      final bloc = context.read<UsersBloc>();
      final repository = bloc.repository;

      final result = await repository.searchUserEmails(query: query);

      result.fold(
        (failure) {
          _suggestedEmails = [];
          _isSearchingEmails = false;
          SuggestionsOverlay.hide();
        },
        (emails) {
          _suggestedEmails = emails;
          _isSearchingEmails = false;
          if (emails.isNotEmpty && _emailFocusNode.hasFocus) {
            _showEmailSuggestionsOverlay();
          } else {
            SuggestionsOverlay.hide();
          }
        },
      );
    } on Exception catch (_) {
      _suggestedEmails = [];
      _isSearchingEmails = false;
      SuggestionsOverlay.hide();
    }
  }

  Future<void> _searchUserPhones() async {
    final query = _phoneController.text.trim();

    if (query.isEmpty || query.length < 3) {
      _suggestedPhones = [];
      _isSearchingPhones = false;
      SuggestionsOverlay.hide();
      return;
    }

    try {
      final bloc = context.read<UsersBloc>();
      final repository = bloc.repository;

      final result = await repository.searchUserPhones(query: query);

      result.fold(
        (failure) {
          _suggestedPhones = [];
          _isSearchingPhones = false;
          SuggestionsOverlay.hide();
        },
        (phones) {
          _suggestedPhones = phones;
          _isSearchingPhones = false;
          if (phones.isNotEmpty && _phoneFocusNode.hasFocus) {
            _showPhoneSuggestionsOverlay();
          } else {
            SuggestionsOverlay.hide();
          }
        },
      );
    } on Exception catch (_) {
      _suggestedPhones = [];
      _isSearchingPhones = false;
      SuggestionsOverlay.hide();
    }
  }

  Future<void> _checkForDuplicateUser() async {
    final name = _nameController.text.trim();
    final roleCode = _roleCodeController.text.trim();

    if (name.isEmpty || roleCode.isEmpty) {
      _duplicateCheckMessage = null;
      return;
    }

    _isCheckingDuplicate = true;
    _duplicateCheckMessage = null;

    try {
      final bloc = context.read<UsersBloc>();
      final repository = bloc.repository;

      final result = await repository.checkUserExists(
        name: name,
        roleCode: roleCode,
      );

      result.fold(
        (failure) {
          _isCheckingDuplicate = false;
          _duplicateCheckMessage = null;
        },
        (exists) {
          _isCheckingDuplicate = false;
          _duplicateCheckMessage = exists
              ? '⚠️ يوجد مستخدم بنفس الاسم ورمز الوصول'
              : '✓ الاسم ورمز الوصول متاحان';
        },
      );
    } on Exception catch (_) {
      _isCheckingDuplicate = false;
      _duplicateCheckMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _buildResponsiveAppBar(context),
      drawer: const UsersDrawer(currentRoute: AppRoutes.createUser),
      body: BlocListener<UsersBloc, UsersState>(
        listenWhen: (previous, current) {
          return current is UserCreated || current is UsersError;
        },
        listener: (context, state) {
          if (state is UserCreated && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: 'تم إنشاء المستخدم بنجاح',
              navigateBackOnSuccess: true,
            );
          } else if (state is UsersError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [_buildWelcomeCard(context), _buildFormCard(context)],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(BuildContext context) {
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
                  'إضافة مستخدم جديد',
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
                  'نظام إدارة المستخدمين الآشوري',
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
      title: 'إضافة مستخدم جديد',
      subtitle: 'إنشاء مستخدم جديد وإضافته إلى قاعدة البيانات',
      icon: Icons.person_add,
      iconBackgroundColor: AssyrianTheme.primaryGold,
      iconForegroundColor: AssyrianTheme.deepBlue,
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoCard(
            title: 'المعلومات الشخصية',
            icon: Icons.person,
            children: [
              _buildNameFieldWithSuggestions(),
              _buildEmailFieldWithSuggestions(),
              _buildPhoneFieldWithSuggestions(),
              _buildTextField(
                controller: _departmentController,
                label: 'القسم (اختياري)',
                icon: Icons.business,
              ),
              _buildTextField(
                controller: _jobTitleController,
                label: 'المسمى الوظيفي (اختياري)',
                icon: Icons.work,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'المصادقة والصلاحيات',
            icon: Icons.security,
            children: [
              _buildRoleCodeField(),
              if (_duplicateCheckMessage != null)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Row(
                    children: [
                      if (_isCheckingDuplicate)
                        SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: LoadingWidget(),
                        )
                      else
                        Icon(
                          _duplicateCheckMessage!.startsWith('⚠️')
                              ? Icons.warning
                              : Icons.check_circle,
                          color: _duplicateCheckMessage!.startsWith('⚠️')
                              ? Colors.red
                              : Colors.green,
                          size: 16.sp,
                        ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _duplicateCheckMessage!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: _duplicateCheckMessage!.startsWith('⚠️')
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16.h),
              _buildRolesSection(),
              SizedBox(height: 16.h),
              _buildCustomPermissionsSection(),
            ],
          ),
          SizedBox(height: 24.h),
          BlocBuilder<UsersBloc, UsersState>(
            builder: (context, state) {
              final isLoading = state is UsersLoading;
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'إنشاء المستخدم',
                      onPressed: isSaving ? null : _createUser,
                      isLoading: isSaving,
                      icon: Icons.person_add,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
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
    );
  }

  Widget _buildEmailFieldWithSuggestions() {
    final hasExactMatch =
        _emailController.text.isNotEmpty &&
        _suggestedEmails.any((email) => email == _emailController.text.trim());

    final hasSuggestions =
        !_isSearchingEmails &&
        _emailController.text.isNotEmpty &&
        _suggestedEmails.isNotEmpty &&
        _emailFocusNode.hasFocus;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'البريد الإلكتروني',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          CompositedTransformTarget(
            link: _emailLayerLink,
            child: Container(
              key: _emailFieldKey,
              child: TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'مثال: name@example.com',
                  prefixIcon: Icon(
                    Icons.email,
                    size: 20.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  suffixIcon: _emailController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20.sp),
                          onPressed: () {
                            _emailController.clear();
                            SuggestionsOverlay.hide();
                            setState(() {
                              _suggestedEmails = [];
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold,
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'البريد الإلكتروني غير صحيح';
                    }
                  }
                  return null;
                },
              ),
            ),
          ),

          if (_isSearchingEmails && _emailController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                  SizedBox(width: 8.w),
                  Text(
                    'جاري البحث...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          if (hasExactMatch)
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.orange.shade800,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'تحذير: يوجد مستخدم بنفس البريد الإلكتروني!',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'مستخدم موجود بالبريد الإلكتروني:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.orange.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 14.sp,
                          color: Colors.orange.shade800,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            _emailController.text.trim(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneFieldWithSuggestions() {
    final hasExactMatch =
        _phoneController.text.isNotEmpty &&
        _suggestedPhones.any((phone) => phone == _phoneController.text.trim());

    final hasSuggestions =
        !_isSearchingPhones &&
        _phoneController.text.isNotEmpty &&
        _suggestedPhones.isNotEmpty &&
        _phoneFocusNode.hasFocus;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رقم الهاتف',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          CompositedTransformTarget(
            link: _phoneLayerLink,
            child: Container(
              key: _phoneFieldKey,
              child: TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+964 xxx xxx xxxx',
                  prefixIcon: Icon(
                    Icons.phone,
                    size: 20.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  suffixIcon: _phoneController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20.sp),
                          onPressed: () {
                            _phoneController.clear();
                            SuggestionsOverlay.hide();
                            setState(() {
                              _suggestedPhones = [];
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold,
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
              ),
            ),
          ),

          if (_isSearchingPhones && _phoneController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                  SizedBox(width: 8.w),
                  Text(
                    'جاري البحث...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          if (hasExactMatch)
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.orange.shade800,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'تحذير: يوجد مستخدم بنفس رقم الهاتف!',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'مستخدم موجود برقم الهاتف:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.orange.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_disabled_outlined,
                          size: 14.sp,
                          color: Colors.orange.shade800,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          _phoneController.text.trim(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'أدخل $label',
          prefixIcon: Icon(icon, size: 20.sp, color: AssyrianTheme.primaryGold),
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
      ),
    );
  }

  Widget _buildNameFieldWithSuggestions() {
    final hasExactMatch =
        _nameController.text.isNotEmpty &&
        _suggestedNames.any((name) => name == _nameController.text.trim());

    final hasSuggestions =
        !_isSearchingNames &&
        _nameController.text.isNotEmpty &&
        _suggestedNames.isNotEmpty &&
        _nameFocusNode.hasFocus;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الاسم الكامل',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          CompositedTransformTarget(
            link: _nameLayerLink,
            child: Container(
              key: _nameFieldKey,
              child: TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                decoration: InputDecoration(
                  hintText: 'أدخل الاسم الكامل',
                  prefixIcon: Icon(
                    Icons.person,
                    size: 20.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  suffixIcon: _nameController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20.sp),
                          onPressed: () {
                            _nameController.clear();
                            SuggestionsOverlay.hide();
                            setState(() {
                              _suggestedNames = [];
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold,
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الاسم مطلوب';
                  }
                  return null;
                },
              ),
            ),
          ),

          if (_isSearchingNames && _nameController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                  SizedBox(width: 8.w),
                  Text(
                    'جاري البحث...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          if (hasExactMatch)
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.orange.shade800,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'تحذير: لا يمكن استخدام هذا الاسم!',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'يوجد مستخدم بنفس الاسم:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.orange.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 14.sp,
                          color: Colors.orange.shade800,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          _nameController.text.trim(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleCodeField() {
    final hasExactMatch =
        _roleCodeController.text.isNotEmpty &&
        _suggestedRoleCodes.any(
          (code) => code == _roleCodeController.text.trim(),
        );

    final hasSuggestions =
        !_isSearchingRoleCodes &&
        _roleCodeController.text.isNotEmpty &&
        _suggestedRoleCodes.isNotEmpty &&
        _roleCodeFocusNode.hasFocus;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'كلمة مرور الوصول',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AssyrianTheme.deepBlue,
            ),
          ),
          SizedBox(height: 8.h),
          CompositedTransformTarget(
            link: _roleCodeLayerLink,
            child: Container(
              key: _roleCodeFieldKey,
              child: TextFormField(
                controller: _roleCodeController,
                focusNode: _roleCodeFocusNode,
                obscureText: _obscureRoleCode,
                decoration: InputDecoration(
                  hintText: 'أدخل كلمة مرور الوصول',
                  prefixIcon: Icon(
                    Icons.key,
                    size: 20.sp,
                    color: AssyrianTheme.primaryGold,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureRoleCode
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20.sp,
                      color: AssyrianTheme.primaryGold,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureRoleCode = !_obscureRoleCode;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: hasSuggestions
                        ? BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          )
                        : BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: hasExactMatch
                          ? Colors.orange.shade400
                          : AssyrianTheme.primaryGold,
                      width: hasExactMatch ? 1.5 : 1,
                    ),
                  ),
                  labelStyle: const TextStyle(color: AssyrianTheme.deepBlue),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'كلمة مرور الوصول مطلوبة';
                  }
                  return null;
                },
              ),
            ),
            ),

          if (_isSearchingRoleCodes && _roleCodeController.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w, height: 16.h, child: LoadingWidget()),
                  SizedBox(width: 8.w),
                  Text(
                    'جاري البحث...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          if (hasExactMatch)
            Container(
              margin: EdgeInsets.only(top: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.orange.shade800,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'تحذير: لا يمكن استخدام هذا الرمز!',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'يوجد مستخدم بنفس رمز الوصول:',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.orange.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.key_off,
                          size: 14.sp,
                          color: Colors.orange.shade800,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          _roleCodeController.text.trim(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأدوار',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        SizedBox(height: 8.h),
        BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            var roles = <RoleEntity>[];

            if (state is UsersLoaded) {
              roles = state.roles;
            }

            if (roles.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey[600],
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'لا توجد أدوار متاحة',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  children: roles.map((role) {
                    final isSelected = selectedRoleIds.contains(role.id);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AssyrianTheme.primaryGold.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          role.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AssyrianTheme.deepBlue,
                          ),
                        ),
                        subtitle: role.description != null
                            ? Text(
                                role.description!,
                                style: TextStyle(color: Colors.grey[600]),
                              )
                            : null,
                        value: isSelected,
            activeColor: AssyrianTheme.primaryGold,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value ?? false) {
                              selectedRoleIds.add(role.id);
                            } else {
                              selectedRoleIds.remove(role.id);
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            }
          },
        ),
        if (selectedRoleIds.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  'يجب اختيار دور واحد على الأقل',
                  style: TextStyle(fontSize: 12.sp, color: Colors.red),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCustomPermissionsSection() {
    return BlocBuilder<UsersBloc, UsersState>(
      builder: (context, state) {
        var permissions = <PermissionEntity>[];
        var roles = <RoleEntity>[];

        if (state is UsersLoaded) {
          permissions = state.permissions;
          roles = state.roles;
        }

        var rolePermissions = <String>{};
        for (final roleId in selectedRoleIds) {
          final role = roles.where((r) => r.id == roleId).firstOrNull;
          if (role != null) {
            rolePermissions.addAll(role.permissions);
          }
        }

        final permissionsByCategory = <String, List<PermissionEntity>>{};
        for (final permission in permissions) {
          final category = permission.category;
          if (!permissionsByCategory.containsKey(category)) {
            permissionsByCategory[category] = [];
          }
          permissionsByCategory[category]!.add(permission);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _enableCustomPermissions
                    ? AssyrianTheme.primaryGold.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: _enableCustomPermissions
                      ? AssyrianTheme.primaryGold.withValues(alpha: 0.3)
                      : Colors.grey[300]!,
                ),
              ),
              child: CheckboxListTile(
                title: Text(
                  'تخصيص صلاحيات',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.deepBlue,
                  ),
                ),
                subtitle: Text(
                  'عند التفعيل، يمكنك تخصيص الصلاحيات يدوياً. عند الإلغاء، سيعود المستخدم لصلاحيات الدور الافتراضية',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
                value: _enableCustomPermissions,
            activeColor: AssyrianTheme.primaryGold,
                onChanged: (bool? value) {
                  setState(() {
                    _enableCustomPermissions = value ?? false;
                    if (_enableCustomPermissions) {
                      // تفعيل التخصيص - نبدأ من الصفر
                      selectedCustomPermissions.clear();
                    } else {
                      // إلغاء التخصيص - مسح الصلاحيات المخصصة والعودة لصلاحيات الدور
                      selectedCustomPermissions.clear();
                    }
                  });
                },
                secondary: Icon(
                  _enableCustomPermissions
                      ? Icons.edit_attributes
                      : Icons.auto_awesome,
                  color: _enableCustomPermissions
                      ? AssyrianTheme.primaryGold
                      : Colors.grey[600],
                ),
              ),
            ),

            if (_enableCustomPermissions) ...[
              SizedBox(height: 16.h),

              // رسالة توضيحية
              Container(
                padding: EdgeInsets.all(12.w),
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20.sp,
                      color: Colors.orange.shade700,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'تم تفعيل تخصيص الصلاحيات. الصلاحيات المحددة هنا ستُستخدم بدلاً من صلاحيات الدور. عند إلغاء التخصيص، سيعود المستخدم لصلاحيات الدور الافتراضية.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (permissions.isEmpty)
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20.sp,
                        height: 20.sp,
                        child: LoadingWidget(),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'جاري تحميل الصلاحيات...',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildGroupedPermissionsForUser(permissions),

              if (selectedCustomPermissions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16.sp,
                          color: Colors.green.shade700,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'الصلاحيات المحددة: ${selectedCustomPermissions.length}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _createUser() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    if (selectedRoleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار دور واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_duplicateCheckMessage != null &&
        _duplicateCheckMessage!.startsWith('⚠️')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إضافة مستخدم بنفس الاسم ورمز الوصول'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final roleCode = _roleCodeController.text.trim();

    // الحصول على معرف المستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = FirebaseAuth.instance.currentUser?.uid ?? '';
      }
    } on Exception catch (_) {
      createdBy = FirebaseAuth.instance.currentUser?.uid ?? '';
    }

    if (!mounted) return;

    // الحصول على مرجع لـ UsersBloc قبل العملية غير المتزامنة
    final usersBloc = context.read<UsersBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        usersBloc.add(
          CreateUserEvent(
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            name: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            department: _departmentController.text.trim().isEmpty
                ? null
                : _departmentController.text.trim(),
            jobTitle: _jobTitleController.text.trim().isEmpty
                ? null
                : _jobTitleController.text.trim(),
            roleIds: selectedRoleIds,
            roleCode: roleCode, // استخدام رمز الوصول كرمز وكلمة مرور
            customPermissions: selectedCustomPermissions.isNotEmpty
                ? selectedCustomPermissions
                : null, // الصلاحيات المخصصة
            createdBy: createdBy, // إضافة معرف المنشئ
          ),
        );
      },
      successMessage: 'تم إنشاء المستخدم بنجاح',
      loadingMessage: 'جاري إنشاء المستخدم...',
    );
  }

  /// بناء بطاقة الصلاحيات الإضافية باستخدام PermissionGroupCard
  Widget _buildGroupedPermissionsForUser(List<PermissionEntity> permissions) {
    // تجميع الصلاحيات حسب القسم
    final groupedPermissions = <String, List<MapEntry<String, String>>>{};

    for (final permission in permissions) {
      final category = permission.category;
      if (!groupedPermissions.containsKey(category)) {
        groupedPermissions[category] = [];
      }
      groupedPermissions[category]!.add(
        MapEntry(permission.name, permission.displayName),
      );
    }

    return Column(
      children: groupedPermissions.entries.map((entry) {
        final categoryName = entry.key;
        return PermissionGroupCard(
          groupName: _getSectionName(categoryName),
          groupIcon: _getSectionIcon(categoryName),
          permissions: entry.value,
          selectedPermissions: selectedCustomPermissions,
          onPermissionsChanged: (selected) {
            setState(() {
              selectedCustomPermissions = selected;
            });
          },
          initiallyExpanded: _expandedCategories.contains(categoryName),
        );
      }).toList(),
    );
  }

  /// الحصول على اسم القسم بالعربية
  String _getSectionName(String category) {
    final sectionNames = <String, String>{
      'invoices': 'الفواتير',
      'customers': 'العملاء',
      'inventory': 'المخزون',
      'subscriptions': 'الاشتراكات',
      'rentals': 'الإيجارات',
      'expenses': 'المصروفات',
      'reports': 'التقارير',
      'users': 'المستخدمين',
      'settings': 'الإعدادات',
      'dashboard': 'لوحة التحكم',
      'maintenance': 'الصيانة',
    };
    return sectionNames[category] ?? category;
  }

  /// الحصول على أيقونة القسم
  IconData _getSectionIcon(String category) {
    final sectionIcons = <String, IconData>{
      'invoices': Icons.receipt_long,
      'customers': Icons.people,
      'inventory': Icons.inventory_2,
      'subscriptions': Icons.card_membership,
      'rentals': Icons.home_work,
      'expenses': Icons.money_off,
      'reports': Icons.analytics,
      'users': Icons.admin_panel_settings,
      'settings': Icons.settings,
      'dashboard': Icons.dashboard,
      'maintenance': Icons.build,
    };
    return sectionIcons[category] ?? Icons.folder;
  }
}
