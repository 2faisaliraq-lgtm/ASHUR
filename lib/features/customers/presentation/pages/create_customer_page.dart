import 'dart:async';

import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/contacts_service.dart';
import '../../../../core/services/formatting_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';

/// صفحة إضافة عميل جديد
class CreateCustomerPage extends StatefulWidget {
  const CreateCustomerPage({super.key});

  @override
  State<CreateCustomerPage> createState() => _CreateCustomerPageState();
}

class _CreateCustomerPageState extends State<CreateCustomerPage>
    with SaveOperationMixin<CreateCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService = FormattingService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _notesController = TextEditingController();

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

  String? _selectedGroupId;
  String? _selectedGroupName;
  List<CustomerGroupEntity> _customerGroups = [];

  // متغيرات البحث والاقتراحات
  List<CustomerEntity> _suggestedCustomers = [];
  List<CustomerEntity> _allCustomers = [];
  List<String> _suggestedEmails = [];
  List<String> _suggestedPhones = [];
  List<String> _allSuggestedEmails = [];
  List<String> _allSuggestedPhones = [];
  bool _isSearchingNames = false;
  bool _isSearchingEmails = false;
  bool _isSearchingPhones = false;
  Timer? _nameDebounceTimer;
  Timer? _emailDebounceTimer;
  Timer? _phoneDebounceTimer;
  bool _isCheckingDuplicate = false;
  String? _duplicateCheckMessage;
  bool _hasSearchedNames = false;
  bool _hasSearchedEmails = false;
  bool _hasSearchedPhones = false;

  // Focus nodes للتحكم في التركيز
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  // LayerLink و GlobalKey لعرض Overlay مقترحات
  final LayerLink _nameLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();

  final LayerLink _emailLayerLink = LayerLink();
  final GlobalKey _emailFieldKey = GlobalKey();

  final LayerLink _phoneLayerLink = LayerLink();
  final GlobalKey _phoneFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _formattingService.initialize();
    _loadCustomerGroups();

    // إضافة listeners للبحث
    _nameController.addListener(_onNameChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);

    // إخفاء الاقتراحات عند فقدان التركيز
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) {
        _hideNameSuggestionsOverlay();
      }
    });

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && mounted) {
        _hideEmailSuggestionsOverlay();
      }
    });

    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus && mounted) {
        _hidePhoneSuggestionsOverlay();
      }
    });
  }

  void _loadCustomerGroups() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      context.read<CustomerBloc>().add(
        LoadCustomerGroupsEvent(currentUser.email!),
      );
    }
  }

  @override
  void dispose() {
    _hideNameSuggestionsOverlay();
    _hideEmailSuggestionsOverlay();
    _hidePhoneSuggestionsOverlay();
    _nameDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _phoneDebounceTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  // دوال البحث والاقتراحات
  void _onNameChanged() {
    _nameDebounceTimer?.cancel();
    _nameDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchCustomerNames();
      _checkForDuplicateCustomer();
    });
  }

  void _onPhoneChanged() {
    _phoneDebounceTimer?.cancel();
    _phoneDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchCustomerPhones();
      _checkForDuplicateCustomer();
    });
  }

  void _onEmailChanged() {
    _emailDebounceTimer?.cancel();
    _emailDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchCustomerEmails();
      _checkForDuplicateCustomer();
    });
  }

  Future<void> _searchCustomerNames() async {
    final query = _nameController.text.trim();

    // البحث بعد كتابة 4 أحرف على الأقل
    if (query.isEmpty || query.length < 4) {
      if (mounted) {
        setState(() {
          _suggestedCustomers = [];
          _isSearchingNames = false;
        });
      }
      _hideNameSuggestionsOverlay();
      return;
    }

    // إذا لم يتم البحث من قبل، نحصل على جميع العملاء
    if (!_hasSearchedNames) {
      if (mounted) {
        setState(() {
          _isSearchingNames = true;
        });
      }

      try {
        final bloc = context.read<CustomerBloc>();
        final repository = bloc.repository;

        final result = await repository.getCustomers(
          FirebaseAuth.instance.currentUser?.email ?? '',
        );

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _allCustomers = [];
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
            }
          },
          (customers) {
            if (mounted) {
              setState(() {
                _allCustomers = customers;
                _hasSearchedNames = true;
                _isSearchingNames = false;
              });
              // تصفية النتائج بناءً على النص المكتوب
              _filterCustomers(query);
            }
          },
        );
      } on Exception catch (_) {
        if (mounted) {
          setState(() {
            _allCustomers = [];
            _hasSearchedNames = true;
            _isSearchingNames = false;
          });
        }
      }
    } else {
      // تصفية النتائج محلياً
      _filterCustomers(query);
    }
  }

  void _filterCustomers(String query) {
    final filtered = _allCustomers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(query.toLowerCase()) ||
              customer.phone.contains(query),
        )
        .toList();

    if (mounted) {
      setState(() {
        _suggestedCustomers = filtered;
        _isSearchingNames = false;
      });
      if (filtered.isNotEmpty && _nameFocusNode.hasFocus) {
        _showNameSuggestionsOverlay();
      } else {
        _hideNameSuggestionsOverlay();
      }
    }
  }

  Future<void> _searchCustomerPhones() async {
    final query = _phoneController.text.trim();

    // البحث بعد كتابة 8 أرقام على الأقل
    if (query.isEmpty || query.length < 8) {
      if (mounted) {
        setState(() {
          _suggestedPhones = [];
          _isSearchingPhones = false;
        });
      }
      _hidePhoneSuggestionsOverlay();
      return;
    }

    // إذا لم يتم البحث من قبل، نحصل على جميع الأرقام
    if (!_hasSearchedPhones) {
      if (mounted) {
        setState(() {
          _isSearchingPhones = true;
        });
      }

      try {
        final bloc = context.read<CustomerBloc>();
        final repository = bloc.repository;

        final result = await repository.searchCustomerPhones(query: '');

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _allSuggestedPhones = [];
                _hasSearchedPhones = true;
                _isSearchingPhones = false;
              });
            }
          },
          (phones) {
            if (mounted) {
              setState(() {
                _allSuggestedPhones = phones;
                _hasSearchedPhones = true;
                _isSearchingPhones = false;
              });
              // تصفية النتائج بناءً على النص المكتوب
              _filterPhones(query);
            }
          },
        );
      } on Exception catch (_) {
        if (mounted) {
          setState(() {
            _allSuggestedPhones = [];
            _hasSearchedPhones = true;
            _isSearchingPhones = false;
          });
        }
      }
    } else {
      // تصفية النتائج محلياً
      _filterPhones(query);
    }
  }

  void _filterPhones(String query) {
    // تطبيع النص المكتوب (إزالة المفتاح الدولي إذا وجد)
    final normalizedQuery = _normalizePhoneNumber(query);

    final filtered = _allSuggestedPhones.where((phone) {
      // تطبيع الرقم من القائمة
      final normalizedPhone = _normalizePhoneNumber(phone);
      // البحث في الرقم المطبعي والنص الأصلي
      return normalizedPhone.contains(normalizedQuery) || phone.contains(query);
    }).toList();

    if (mounted) {
      setState(() {
        _suggestedPhones = filtered;
        _isSearchingPhones = false;
      });
      if (filtered.isNotEmpty && _phoneFocusNode.hasFocus) {
        _showPhoneSuggestionsOverlay();
      } else {
        _hidePhoneSuggestionsOverlay();
      }
    }
  }

  /// تطبيع رقم الهاتف بإزالة المفتاح الدولي
  /// +9647710757599 أو 009647710757599 أو 9647710757599 ← 7710757599
  /// 07710757599 ← 7710757599
  String _normalizePhoneNumber(String phone) {
    // إزالة جميع الأحرف غير الرقمية
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // إزالة الصفر في البداية إذا وجد
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // إزالة مفتاح العراق الدولي (964) إذا وجد
    if (cleaned.startsWith('964')) {
      cleaned = cleaned.substring(3);
    }

    // إزالة مفاتيح دولية شائعة أخرى
    const commonCountryCodes = [
      '964', // العراق
      '971', // الإمارات
      '966', // السعودية
      '965', // الكويت
      '973', // البحرين
      '968', // عمان
      '967', // اليمن
      '963', // سوريا
      '961', // لبنان
      '962', // الأردن
      '20', // مصر
      '90', // تركيا
      '1', // أمريكا
      '44', // بريطانيا
    ];

    for (final code in commonCountryCodes) {
      if (cleaned.startsWith(code)) {
        cleaned = cleaned.substring(code.length);
        break;
      }
    }

    return cleaned;
  }

  Future<void> _searchCustomerEmails() async {
    final query = _emailController.text.trim();

    // البحث بعد كتابة 4 أحرف على الأقل
    if (query.isEmpty || query.length < 4) {
      if (mounted) {
        setState(() {
          _suggestedEmails = [];
          _isSearchingEmails = false;
        });
      }
      _hideEmailSuggestionsOverlay();
      return;
    }

    // إذا لم يتم البحث من قبل، نحصل على جميع الإيميلات
    if (!_hasSearchedEmails) {
      if (mounted) {
        setState(() {
          _isSearchingEmails = true;
        });
      }

      try {
        final bloc = context.read<CustomerBloc>();
        final repository = bloc.repository;

        final result = await repository.searchCustomerEmails(query: '');

        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _allSuggestedEmails = [];
                _hasSearchedEmails = true;
                _isSearchingEmails = false;
              });
            }
          },
          (emails) {
            if (mounted) {
              setState(() {
                _allSuggestedEmails = emails;
                _hasSearchedEmails = true;
                _isSearchingEmails = false;
              });
              // تصفية النتائج بناءً على النص المكتوب
              _filterEmails(query);
            }
          },
        );
      } on Exception catch (_) {
        if (mounted) {
          setState(() {
            _allSuggestedEmails = [];
            _hasSearchedEmails = true;
            _isSearchingEmails = false;
          });
        }
      }
    } else {
      // تصفية النتائج محلياً
      _filterEmails(query);
    }
  }

  void _filterEmails(String query) {
    final filtered = _allSuggestedEmails
        .where((email) => email.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (mounted) {
      setState(() {
        _suggestedEmails = filtered;
        _isSearchingEmails = false;
      });
      if (filtered.isNotEmpty && _emailFocusNode.hasFocus) {
        _showEmailSuggestionsOverlay();
      } else {
        _hideEmailSuggestionsOverlay();
      }
    }
  }

  Future<bool> _checkForDuplicateCustomer() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // يجب أن يكون الاسم موجود على الأقل للتحقق من التكرار
    if (name.isEmpty) {
      setState(() {
        _duplicateCheckMessage = null;
      });
      return true;
    }

    // لا نتحقق من التكرار إذا كانت جميع الحقول فارغة عدا الاسم
    if (email.isEmpty && phone.isEmpty) {
      setState(() {
        _duplicateCheckMessage =
            '⚠️ يُنصح بإدخال البريد الإلكتروني أو رقم الهاتف للتحقق من التكرار';
        _isCheckingDuplicate = false;
      });
      return true;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateCheckMessage = null;
    });

    try {
      final bloc = context.read<CustomerBloc>();
      final repository = bloc.repository;

      final result = await repository.checkCustomerExistsDetailed(
        name: name,
        email: email,
        phone: phone,
      );

      bool isDuplicate = true;
      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _isCheckingDuplicate = false;
              _duplicateCheckMessage = 'خطأ في التحقق من التكرار';
            });
          }
          isDuplicate =
              true; // عند الفشل نفترض وجود تكرار لمنع الإنشاء غير الآمن
        },
        (data) {
          if (mounted) {
            setState(() {
              _isCheckingDuplicate = false;
              final exists = data['exists'] as bool;
              final message = data['message'] as String;

              if (exists) {
                _duplicateCheckMessage =
                    '⚠️ $message - تأكد من رغبتك في إنشاء عميل مكرر';
              } else {
                _duplicateCheckMessage = '✓ $message';
              }
            });
          }
          isDuplicate = !(data['exists'] as bool);
        },
      );
      return isDuplicate;
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingDuplicate = false;
          _duplicateCheckMessage = null;
        });
      }
      // ⚠️ عند حدوث خطأ في التحقق من التكرار، نفترض وجود تكرار
      // لمنع إنشاء عميل مكرر بشكل غير آمن.
      return true;
    }
  }

  // دوال عرض وإخفاء الاقتراحات باستخدام SuggestionsOverlay الموحد
  void _showNameSuggestionsOverlay() {
    if (_suggestedCustomers.isEmpty || !_nameFocusNode.hasFocus) return;

    SuggestionsOverlay.hide();

    final suggestions = _suggestedCustomers
        .take(5)
        .map(
          (customer) => customer.toSuggestionItem(
            formatCurrency: _formattingService.formatCurrency,
          ),
        )
        .toList();

    SuggestionsOverlay.show(
      context: context,
      layerLink: _nameLayerLink,
      anchorKey: _nameFieldKey,
      suggestions: suggestions,
      onSuggestionSelected: (value) {
        _nameController.text = value;
        SuggestionsOverlay.hide();
      },
      maxHeight: 100.h,
    );
  }

  void _hideNameSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  void _showPhoneSuggestionsOverlay() {
    if (_suggestedPhones.isEmpty || !_phoneFocusNode.hasFocus) return;

    SuggestionsOverlay.hide();

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
      },
      maxHeight: 100.h,
    );
  }

  void _hidePhoneSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  void _showEmailSuggestionsOverlay() {
    if (_suggestedEmails.isEmpty || !_emailFocusNode.hasFocus) return;

    SuggestionsOverlay.hide();

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
      },
      maxHeight: 100.h,
    );
  }

  void _hideEmailSuggestionsOverlay() {
    SuggestionsOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: AppRoutes.createCustomer),
      body: BlocListener<CustomerBloc, CustomerState>(
        listenWhen: (previous, current) {
          return current is CustomerCreated ||
              current is CustomerError ||
              current is CustomerGroupsLoaded;
        },
        listener: (context, state) {
          if (state is CustomerCreated && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(
              successMessage: 'تم إضافة العميل بنجاح',
              navigateBackOnSuccess: true,
            );
          } else if (state is CustomerError && !_operationCompleted) {
            _operationCompleted = true;
            failSaveOperation(errorMessage: state.message);
          } else if (state is CustomerGroupsLoaded) {
            _customerGroups = state.groups;
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
                  'إضافة عميل جديد',
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
                  'نظام إدارة العملاء الآشوري',
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
      title: 'إضافة عميل جديد',
      subtitle: 'إنشاء عميل جديد وإضافته إلى قاعدة البيانات',
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
          // زر استيراد جهات الاتصال
          if (ContactsImportService.isContactsServiceAvailable())
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 16.h),
              child: OutlinedButton.icon(
                onPressed: _showContactsImportDialog,
                icon: Icon(
                  Icons.contacts,
                  size: 20.sp,
                  color: AssyrianTheme.primaryGold,
                ),
                label: Text(
                  'استيراد من جهات الاتصال',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AssyrianTheme.primaryGold.withValues(alpha: 0.5),
                  ),
                  backgroundColor: AssyrianTheme.primaryGold.withValues(
                    alpha: 0.05,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
          InfoCard(
            title: 'المعلومات الأساسية',
            icon: Icons.person,
            children: [
              _buildNameFieldWithSuggestions(),
              _buildEmailFieldWithSuggestions(),
              _buildPhoneFieldWithSuggestions(),
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
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'المعلومات المالية',
            icon: Icons.account_balance,
            children: [
              _buildTextField(
                controller: _creditLimitController,
                label: 'حد الدين (اختياري)',
                icon: Icons.credit_card,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
              ),
              _buildOpeningBalanceField(),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'المعلومات الإضافية',
            icon: Icons.info_outline,
            children: [
              _buildTextField(
                controller: _addressController,
                label: 'العنوان',
                icon: Icons.location_on,
              ),
              _buildCustomerGroupSection(),
              _buildTextField(
                controller: _notesController,
                label: 'ملاحظات',
                icon: Icons.note,
                maxLines: 3,
              ),
            ],
          ),
          SizedBox(height: 24.h),
          BlocBuilder<CustomerBloc, CustomerState>(
            builder: (context, state) {
              final isLoading = state is CustomerLoading;
              return Row(
                children: [
                  Expanded(
                    child: LoadingButton(
                      text: 'إنشاء العميل',
                      onPressed: isSaving ? null : _createCustomer,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
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
    );
  }

  Widget _buildCustomerGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مجموعة العميل (اختياري)',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AssyrianTheme.deepBlue,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _selectedGroupId,
          decoration: InputDecoration(
            hintText: 'اختر مجموعة العميل',
            prefixIcon: Icon(
              Icons.group,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
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
          ),
          items: [
            const DropdownMenuItem<String>(child: Text('بدون مجموعة')),
            ..._customerGroups.map((group) {
              return DropdownMenuItem<String>(
                value: group.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(int.parse('0xFF${group.color}')),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(group.name)),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedGroupId = value;
              if (value != null) {
                final group = _customerGroups.firstWhere((g) => g.id == value);
                _selectedGroupName = group.name;
              } else {
                _selectedGroupName = null;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildOpeningBalanceField() {
    return GestureDetector(
      onTap: _showOpeningBalanceDialog,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 20.sp,
              color: AssyrianTheme.primaryGold,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الحساب الافتتاحي (اختياري)',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AssyrianTheme.deepBlue,
                    ),
                  ),
                  if (_openingBalanceController.text.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      _formatBalanceDisplay(_openingBalanceController.text),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: _getBalanceColor(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.edit, size: 16.sp, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Color _getBalanceColor() {
    final text = _openingBalanceController.text.trim();
    if (text.isEmpty) return Colors.black;

    // تحويل الأرقام العربية إلى إنجليزية
    var cleanText = text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    // إزالة فواصل الآلاف والرموز الإضافية، والاحتفاظ بالأرقام والنقطة العشرية والإشارة السالبة فقط
    cleanText = cleanText.replaceAll(',', ''); // إزالة فواصل الآلاف
    cleanText = cleanText.replaceAll(
      RegExp(r'[^\d.-]'),
      '',
    ); // إزالة أي رموز أخرى

    final value = double.tryParse(cleanText);

    if (value == null) return Colors.black;
    // المنطق الجديد: الموجب = عليه (أحمر)، السالب = له (أخضر)
    return value > 0 ? Colors.red : (value < 0 ? Colors.green : Colors.black);
  }

  /// تنسيق عرض الحساب بدون إشارة سالبة مع نص توضيحي
  String _formatBalanceDisplay(String text) {
    if (text.isEmpty) return '';

    final value = double.tryParse(text);
    if (value == null) return text;

    final absValue = value.abs();
    final formattedAmount = _formattingService.formatCurrency(absValue);

    if (value > 0) {
      return 'عليه: $formattedAmount'; // العميل يدين لنا
    } else if (value < 0) {
      return 'له: $formattedAmount'; // نحن ندين للعميل
    } else {
      return 'لا يوجد حساب';
    }
  }

  /// تحليل الحساب الافتتاحي مع تنظيف النص
  double? _parseOpeningBalance(String text) {
    if (text.isEmpty) return null;

    // تحويل الأرقام العربية إلى إنجليزية
    var cleanText = text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    // إزالة فواصل الآلاف والرموز الإضافية، والاحتفاظ بالأرقام والنقطة العشرية والإشارة السالبة فقط
    cleanText = cleanText.replaceAll(',', ''); // إزالة فواصل الآلاف
    cleanText = cleanText.replaceAll(
      RegExp(r'[^\d.-]'),
      '',
    ); // إزالة أي رموز أخرى

    return double.tryParse(cleanText);
  }

  /// تحليل حد الدين مع تنظيف النص
  double? _parseCreditLimit(String text) {
    if (text.isEmpty) return null;

    // تحويل الأرقام العربية إلى إنجليزية
    var cleanText = text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    // إزالة فواصل الآلاف والرموز الإضافية، والاحتفاظ بالأرقام والنقطة العشرية فقط
    cleanText = cleanText.replaceAll(',', ''); // إزالة فواصل الآلاف
    cleanText = cleanText.replaceAll(
      RegExp(r'[^\d.]'),
      '',
    ); // إزالة أي رموز أخرى (لا نحتاج الإشارة السالبة لحد الدين)

    final result = double.tryParse(cleanText);
    // التأكد من أن حد الدين لا يمكن أن يكون سالباً
    return (result != null && result >= 0) ? result : null;
  }

  void _showOpeningBalanceDialog() {
    // إزالة الإشارة السالبة من النص المعروض في الحوار
    var currentText = _openingBalanceController.text;
    if (currentText.startsWith('-')) {
      currentText = currentText.substring(1);
    }

    var dialogController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: AssyrianTheme.primaryGold,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'إدخال الحساب الافتتاحي',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AssyrianTheme.primaryGold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'حدد نوع الحساب والمبلغ المطلوب',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'أدخل المبلغ:',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 8.h),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: dialogController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A202C),
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: AssyrianTheme.primaryGold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'اختر نوع الحساب:',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                // Debit button (عليه) - العميل يدين لنا
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = dialogController.text.trim();
                      if (amount.isNotEmpty) {
                        _openingBalanceController.text = amount;
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_down, size: 16.sp),
                        SizedBox(width: 6.w),
                        Text(
                          'عليه',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Credit button (له) - نحن ندين للعميل
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = dialogController.text.trim();
                      if (amount.isNotEmpty) {
                        _openingBalanceController.text = '-$amount';
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_up, size: 16.sp),
                        SizedBox(width: 6.w),
                        Text(
                          'له',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            ),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameFieldWithSuggestions() {
    final hasExactMatch =
        _nameController.text.isNotEmpty &&
        _suggestedCustomers.any(
          (customer) => customer.name == _nameController.text.trim(),
        );

    final hasSuggestions =
        !_isSearchingNames &&
        _nameController.text.isNotEmpty &&
        _suggestedCustomers.isNotEmpty &&
        _nameFocusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _nameLayerLink,
          child: Container(
            key: _nameFieldKey,
            child: TextFormField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: 'اسم العميل *',
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
                          _hideNameSuggestionsOverlay();
                          setState(() {
                            _suggestedCustomers = [];
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
                  return 'اسم العميل مطلوب';
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
                        'تحذير: يوجد عميل بنفس الاسم!',
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
                  'عميل موجود بالاسم:',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _phoneLayerLink,
          child: Container(
            key: _phoneFieldKey,
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
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
                          _hidePhoneSuggestionsOverlay();
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
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // التحقق من تنسيق رقم الهاتف (يقبل الأرقام العراقية المحلية والدولية)
                  final cleanedValue = value.replaceAll(
                    RegExp(r'[\s\-\(\)]'),
                    '',
                  );
                  // يقبل: 07xxxxxxxxx (11 خانة) أو 9647xxxxxxxx (12 خانة) أو +9647xxxxxxxx
                  final phoneRegex = RegExp(
                    r'^(0[1-9][0-9]{9}|964[1-9][0-9]{9}|\+964[1-9][0-9]{9}|[1-9][0-9]{9,14})$',
                  );
                  if (!phoneRegex.hasMatch(cleanedValue)) {
                    return 'يرجى إدخال رقم هاتف صحيح';
                  }
                }
                return null;
              },
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
                        'تحذير: يوجد عميل بنفس رقم الهاتف!',
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
                  'عميل موجود برقم الهاتف:',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _emailLayerLink,
          child: Container(
            key: _emailFieldKey,
            child: TextFormField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني (اختياري)',
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
                          _hideEmailSuggestionsOverlay();
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
                    return 'يرجى إدخال بريد إلكتروني صحيح';
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
                        'تحذير: يوجد عميل بنفس البريد الإلكتروني!',
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
                  'عميل موجود بالبريد الإلكتروني:',
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
    );
  }

  Future<void> _createCustomer() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    // التحقق من التكرار قبل الإنشاء
    if (_duplicateCheckMessage != null &&
        _duplicateCheckMessage!.contains('⚠️')) {
      if (mounted) {
        // عرض حوار تأكيد للمستخدم
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'تحذير: عميل مكرر',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'يوجد عميل بنفس البيانات مسبقاً',
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
                SizedBox(height: 16.h),
                Text(
                  'هل تريد المتابعة وإنشاء عميل جديد؟',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16.sp,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'تفاصيل التكرار:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _duplicateCheckMessage?.replaceAll('⚠️ ', '') ??
                            'بيانات مكررة',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'سيتم إنشاء عميل جديد بنفس البيانات الموجودة.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.orange[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'متابعة',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          return;
        }
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب تسجيل الدخول أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // الحصول على UID الخاص بالمستخدم
    String createdBy;
    try {
      final switchedUser = await SessionService.getSwitchedUser();
      if (switchedUser != null && switchedUser['id'] != null) {
        createdBy = switchedUser['id'] as String;
      } else {
        createdBy = currentUser.uid;
      }
    } on Exception catch (_) {
      createdBy = currentUser.uid;
    }

    if (!mounted) return;

    // الحصول على مرجع لـ CustomerBloc قبل العملية غير المتزامنة
    final customerBloc = context.read<CustomerBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    await performBlocSaveOperation(
      triggerSave: () {
        customerBloc.add(
          CreateCustomerEvent(
            organizationEmail: currentUser.email!,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            customerGroupId: _selectedGroupId,
            customerGroupName: _selectedGroupName,
            creditLimit: _creditLimitController.text.trim().isEmpty
                ? null
                : _parseCreditLimit(_creditLimitController.text.trim()),
            openingBalance: _openingBalanceController.text.trim().isEmpty
                ? null
                : _parseOpeningBalance(_openingBalanceController.text.trim()),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            createdBy: createdBy,
          ),
        );
      },
      successMessage: 'تم إنشاء العميل بنجاح',
      loadingMessage: 'جاري إنشاء العميل...',
    );
  }

  /// عرض حوار استيراد جهات الاتصال
  Future<void> _showContactsImportDialog() async {
    try {
      // التحقق من توفر الخدمة على المنصة
      if (!ContactsImportService.isContactsServiceAvailable()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ميزة جهات الاتصال غير متاحة على هذا الجهاز'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // عرض حوار التحميل
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingWidget(),
                SizedBox(height: 16.h),
                Text(
                  'جاري اختبار الوصول لجهات الاتصال...',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      );

      // اختبار الوصول لجهات الاتصال أولاً
      final testResult = await ContactsImportService.testContactsAccess();

      if (!mounted) return;

      // إغلاق حوار التحميل
      Navigator.of(context).pop();

      if (!testResult['success']) {
        // عرض تفاصيل الخطأ
        _showContactsErrorDialog(testResult);
        return;
      }

      // إذا نجح الاختبار، جلب جهات الاتصال
      await _loadAndShowContacts();
    } on Exception catch (_) {
      if (mounted) {
        Navigator.of(context).pop(); // إغلاق حوار التحميل إذا كان مفتوحاً

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'خطأ غير متوقع',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('تفاصيل الخطأ: حدث خطأ غير متوقع'),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: _showContactsImportDialog,
            ),
          ),
        );
      }
    }
  }

  /// عرض حوار تفاصيل خطأ جهات الاتصال
  void _showContactsErrorDialog(Map<String, dynamic> testResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24.sp),
            SizedBox(width: 12.w),
            Text(
              'خطأ في الوصول لجهات الاتصال',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخطأ: ${testResult['error'] ?? 'غير محدد'}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 12.h),
              if (testResult['permissionStatus'] != null) ...[
                Text(
                  'حالة الإذن: ${testResult['permissionStatus']}',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 8.h),
              ],
              Text(
                'تفاصيل التشخيص:',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final detail in testResult['details'] ?? [])
                      Padding(
                        padding: EdgeInsets.only(bottom: 2.h),
                        child: Text(
                          '• $detail',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إغلاق',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(openAppSettings());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AssyrianTheme.primaryGold,
              foregroundColor: Colors.white,
            ),
            child: Text('فتح الإعدادات', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showContactsImportDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('إعادة المحاولة', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  /// تحميل وعرض جهات الاتصال
  Future<void> _loadAndShowContacts() async {
    try {
      if (!mounted) return;

      // عرض حوار التحميل
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingWidget(),
                SizedBox(height: 16.h),
                Text(
                  'جاري تحميل جهات الاتصال...',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      );

      // جلب جهات الاتصال
      final contacts = await ContactsImportService.getAllContacts();

      if (!mounted) return;

      // إغلاق حوار التحميل
      Navigator.of(context).pop();

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                const Expanded(
                  child: Text(
                    'لا توجد جهات اتصال متاحة أو لا تحتوي على أرقام هواتف أو بريد إلكتروني',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // عرض حوار اختيار جهة الاتصال
      _showContactSelectionDialog(contacts);
    } on Exception catch (_) {
      if (mounted) {
        Navigator.of(context).pop(); // إغلاق حوار التحميل إذا كان مفتوحاً

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'خطأ في تحميل جهات الاتصال',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('تفاصيل الخطأ: حدث خطأ غير متوقع'),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () => unawaited(_loadAndShowContacts()),
            ),
          ),
        );
      }
    }
  }

  /// عرض حوار اختيار جهة الاتصال
  void _showContactSelectionDialog(List<ContactInfo> contacts) {
    var searchController = TextEditingController();
    var filteredContacts = List.from(contacts);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AssyrianTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.contacts,
                  color: AssyrianTheme.primaryGold,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'اختر جهة اتصال',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AssyrianTheme.primaryGold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500.h,
            child: Column(
              children: [
                // شريط البحث
                TextField(
                  controller: searchController,
                  onChanged: (query) {
                    setState(() {
                      if (query.trim().isEmpty) {
                        filteredContacts = List.from(contacts);
                      } else {
                        filteredContacts = contacts.where((contact) {
                          final searchQuery = query.toLowerCase();
                          return contact.name.toLowerCase().contains(
                                searchQuery,
                              ) ||
                              (contact.phone?.toLowerCase().contains(
                                    searchQuery,
                                  ) ??
                                  false) ||
                              (contact.email?.toLowerCase().contains(
                                    searchQuery,
                                  ) ??
                                  false);
                        }).toList();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'البحث في جهات الاتصال...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: AssyrianTheme.primaryGold,
                      size: 20.sp,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20.sp),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                filteredContacts = List.from(contacts);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(
                        color: AssyrianTheme.primaryGold.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(
                        color: AssyrianTheme.primaryGold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                // عداد النتائج
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    'عدد جهات الاتصال: ${filteredContacts.length}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // قائمة جهات الاتصال
                Expanded(
                  child: filteredContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48.sp,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'لا توجد نتائج',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredContacts.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: Colors.grey[300]),
                          itemBuilder: (context, index) {
                            final contact = filteredContacts[index];
                            return ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: AssyrianTheme.primaryGold
                                    .withValues(alpha: 0.1),
                                radius: 20.r,
                                child: Text(
                                  contact.name.isNotEmpty
                                      ? contact.name[0].toUpperCase()
                                      : 'C',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AssyrianTheme.primaryGold,
                                  ),
                                ),
                              ),
                              title: Text(
                                contact.name,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AssyrianTheme.deepBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (contact.phone != null &&
                                      contact.phone!.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4.w),
                                        Expanded(
                                          child: Text(
                                            contact.phone!,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (contact.email != null &&
                                      contact.email!.isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.email,
                                          size: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4.w),
                                        Expanded(
                                          child: Text(
                                            contact.email!,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 16.sp,
                                color: AssyrianTheme.primaryGold,
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                _importContactData(contact);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// استيراد بيانات جهة الاتصال
  Future<void> _importContactData(ContactInfo contact) async {
    setState(() {
      // ملء الحقول بالبيانات المستوردة
      _nameController.text = contact.name;

      if (contact.phone != null && contact.phone!.isNotEmpty) {
        _phoneController.text = contact.phone!;
      }

      if (contact.email != null && contact.email!.isNotEmpty) {
        _emailController.text = contact.email!;
      }

      // إخفاء الاقتراحات
      _hideNameSuggestionsOverlay();
      _hideEmailSuggestionsOverlay();
      _hidePhoneSuggestionsOverlay();

      // مسح الاقتراحات
      _suggestedCustomers = [];
      _suggestedEmails = [];
      _suggestedPhones = [];
    });

    // التحقق من التكرار بعد الاستيراد
    final isDuplicate = await _checkForDuplicateCustomer();

    // عرض رسالة نجاح فقط إذا لم يكن هناك تكرار
    if (isDuplicate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'تم استيراد بيانات ${contact.name} بنجاح',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }
}
