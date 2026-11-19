import 'dart:async';


import '../../../../core/widgets/loading_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/mixins/save_operation_mixin.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../../core/responsive/responsive_scaffold.dart' as scaffold;
import '../../../../core/services/formatting_service.dart';
import '../../../../core/theme/assyrian_theme.dart';
import '../../../../core/widgets/detail_screen_widgets.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../../core/widgets/suggestions/suggestions_overlay.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_group_entity.dart';
import '../bloc/customer_bloc.dart';
import '../widgets/customer_drawer.dart';

/// صفحة تعديل العميل
class EditCustomerPage extends StatefulWidget {
  const EditCustomerPage({required this.customer, super.key});
  final CustomerEntity customer;

  @override
  State<EditCustomerPage> createState() => _EditCustomerPageState();
}

class _EditCustomerPageState extends State<EditCustomerPage>
    with SaveOperationMixin<EditCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final FormattingService _formattingService = FormattingService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _notesController;

  String? _selectedGroupId;
  String? _selectedGroupName;
  List<CustomerGroupEntity> _customerGroups = [];

  // حماية من التنفيذ المتكرر
  bool _operationCompleted = false;

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
    _initializeControllers();
    _loadCustomerGroups();

    // إضافة listeners للبحث
    _nameController.addListener(_onNameChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);

    // إخفاء الاقتراحات عند فقدان التركيز
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
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.customer.name);
    _emailController = TextEditingController(text: widget.customer.email);
    _phoneController = TextEditingController(text: widget.customer.phone);
    _addressController = TextEditingController(
      text: widget.customer.address ?? '',
    );
    _creditLimitController = TextEditingController(
      text: widget.customer.creditLimit != null
          ? _formattingService.formatNumber(widget.customer.creditLimit!)
          : '',
    );
    _notesController = TextEditingController(text: widget.customer.notes ?? '');

    _selectedGroupId = widget.customer.customerGroupId;
    _selectedGroupName = widget.customer.customerGroupName;
  }

  void _loadCustomerGroups() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      context.read<CustomerBloc>().add(
        LoadCustomerGroupsEvent(currentUser.email!),
      );
    }
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
      SuggestionsOverlay.hide();
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
        SuggestionsOverlay.hide();
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
      SuggestionsOverlay.hide();
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

        result.fold((failure) {
          if (mounted) {
            setState(() {
              _allSuggestedPhones = [];
              _hasSearchedPhones = true;
              _isSearchingPhones = false;
            });
          }
        }, (phones) => _processPhonesResult(phones));
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

  void _processPhonesResult(List<String> phones) {
    if (mounted) {
      setState(() {
        _allSuggestedPhones = phones;
        _hasSearchedPhones = true;
        _isSearchingPhones = false;
      });
      _filterPhones(_phoneController.text.trim());
    }
  }

  void _filterPhones(String query) {
    // تطبيع النص المكتوب (إزالة المفتاح الدولي إذا وجد)
    final normalizedQuery = _normalizePhoneNumber(query);

    final filtered = _allSuggestedPhones.where((phone) {
      // تطبيع الرقم من القائمة
      final normalizedPhone = _normalizePhoneNumber(phone);
      // البحث في الرقم المطبعي والنص الأصلي واستثناء رقم العميل الحالي
      return (normalizedPhone.contains(normalizedQuery) ||
              phone.contains(query)) &&
          phone != widget.customer.phone;
    }).toList();

    if (mounted) {
      setState(() {
        _suggestedPhones = filtered;
        _isSearchingPhones = false;
      });
      if (filtered.isNotEmpty && _phoneFocusNode.hasFocus) {
        _showPhoneSuggestionsOverlay();
      } else {
        SuggestionsOverlay.hide();
      }
    }
  }

  /// تطبيع رقم الهاتف بإزالة المفتاح الدولي
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
      SuggestionsOverlay.hide();
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
        .where(
          (email) =>
              email.toLowerCase().contains(query.toLowerCase()) &&
              email != widget.customer.email,
        )
        .toList();

    if (mounted) {
      setState(() {
        _suggestedEmails = filtered;
        _isSearchingEmails = false;
      });
      if (filtered.isNotEmpty && _emailFocusNode.hasFocus) {
        _showEmailSuggestionsOverlay();
      } else {
        SuggestionsOverlay.hide();
      }
    }
  }

  Future<void> _checkForDuplicateCustomer() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // يجب أن يكون الاسم موجود على الأقل للتحقق من التكرار
    if (name.isEmpty) {
      setState(() {
        _duplicateCheckMessage = null;
      });
      return;
    }

    // إذا كانت البيانات نفس البيانات الأصلية للعميل، فلا توجد مشكلة
    if (name == widget.customer.name &&
        email == widget.customer.email &&
        phone == widget.customer.phone) {
      setState(() {
        _duplicateCheckMessage = '✓ البيانات متاحة';
        _isCheckingDuplicate = false;
      });
      return;
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

      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _isCheckingDuplicate = false;
              _duplicateCheckMessage = 'خطأ في التحقق من التكرار';
            });
          }
        },
        (data) {
          if (mounted) {
            setState(() {
              _isCheckingDuplicate = false;
              final exists = data['exists'] as bool;
              final message = data['message'] as String;

              if (exists) {
                _duplicateCheckMessage =
                    '⚠️ $message - سيتم طلب تأكيد عند الحفظ';
              } else {
                _duplicateCheckMessage = '✓ $message';
              }
            });
          }
        },
      );
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingDuplicate = false;
          _duplicateCheckMessage = null;
        });
      }
    }
  }

  // دوال عرض وإخفاء الاقتراحات باستخدام SuggestionsOverlay
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
      },
      maxHeight: 100.h,
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
      },
      maxHeight: 100.h,
    );
  }

  @override
  void dispose() {
    SuggestionsOverlay.hide();
    _nameDebounceTimer?.cancel();
    _emailDebounceTimer?.cancel();
    _phoneDebounceTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return scaffold.ResponsiveScaffold(
      appBar: _buildAppBar(context),
      drawer: const CustomerDrawer(currentRoute: 'edit_customer'),
      body: BlocListener<CustomerBloc, CustomerState>(
        listenWhen: (previous, current) {
          return current is CustomerOperationSuccess ||
              current is CustomerError ||
              current is CustomerGroupsLoaded;
        },
        listener: (context, state) {
          if (state is CustomerOperationSuccess && !_operationCompleted) {
            _operationCompleted = true;
            completeSaveOperation(successMessage: 'تم التعديل بنجاح');
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
                  'تعديل العميل',
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
                  'تعديل بيانات العميل',
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
      title: 'تعديل العميل',
      subtitle: 'تعديل بيانات ومعلومات العميل',
      icon: Icons.edit,
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
              _buildTextField(
                controller: _addressController,
                label: 'العنوان',
                icon: Icons.location_on,
              ),
              _buildCustomerGroupSection(),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'المعلومات المالية',
            icon: Icons.account_balance,
            children: [
              _buildTextField(
                controller: _creditLimitController,
                label: 'حد الدين',
                icon: Icons.credit_card,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_formattingService.getPriceInputFormatter()],
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = _parseCreditLimit(value);
                    if (parsed == null || parsed < 0) {
                      return 'يرجى إدخال رقم صحيح أكبر من أو يساوي الصفر';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),
          InfoCard(
            title: 'ملاحظات',
            icon: Icons.note,
            children: [
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
                      text: 'حفظ التعديلات',
                      onPressed: _updateCustomer,
                      isLoading: isLoading,
                      icon: Icons.save,
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
          'مجموعة العميل',
          style: TextStyle(
            fontSize: 18.sp,
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
                labelText: 'الاسم الكامل *',
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
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: LoadingWidget(),
                ),
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
              validator: (value) {
                // رقم الهاتف اختياري الآن
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
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: LoadingWidget(),
                ),
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
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: LoadingWidget(),
                ),
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

  Future<void> _updateCustomer() async {
    // حماية من التنفيذ المتكرر
    if (isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // إعادة تعيين الـ flag لعملية جديدة
    _operationCompleted = false;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // التحقق من وجود تغييرات
    final hasChanges =
        name != widget.customer.name ||
        email != widget.customer.email ||
        phone != widget.customer.phone ||
        _addressController.text.trim() != (widget.customer.address ?? '') ||
        _selectedGroupId != widget.customer.customerGroupId ||
        _notesController.text.trim() != (widget.customer.notes ?? '') ||
        (_parseCreditLimit(_creditLimitController.text.trim()) ??
                widget.customer.creditLimit) !=
            widget.customer.creditLimit;

    if (!hasChanges) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم إجراء أي تغييرات'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // التحقق من صحة البيانات
    if (name.isEmpty) {
      return;
    }

    // التحقق من التكرار إذا تم تغيير البيانات
    if (name != widget.customer.name ||
        email != widget.customer.email ||
        phone != widget.customer.phone) {
      if (_duplicateCheckMessage != null &&
          _duplicateCheckMessage!.contains('⚠️')) {
        if (mounted) {
          // عرض تأكيد للمستخدم
          final shouldContinue = await showDialog<bool>(
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
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20.sp,
                        ),
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
                    'هل تريد المتابعة وحفظ التعديلات؟',
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
                          _duplicateCheckMessage
                                  ?.replaceAll('⚠️ ', '')
                                  .replaceAll(
                                    ' - سيتم طلب تأكيد عند الحفظ',
                                    '',
                                  ) ??
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
                    'سيتم تحديث بيانات العميل رغم وجود تكرار.',
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
                      Icon(Icons.save, size: 16.sp),
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
    }

    // إنشاء كائن العميل المحدث
    final updatedCustomer = CustomerEntity(
      id: widget.customer.id,
      organizationEmail: widget.customer.organizationEmail,
      name: name,
      email: email,
      phone: phone,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      customerGroupId: _selectedGroupId,
      customerGroupName: _selectedGroupName,
      creditLimit: _creditLimitController.text.trim().isEmpty
          ? null
          : _parseCreditLimit(_creditLimitController.text.trim()),
      openingBalance: widget.customer.openingBalance,
      totalPurchases: widget.customer.totalPurchases,
      totalDebt: widget.customer.totalDebt,
      status: widget.customer.status,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdBy: widget.customer.createdBy,
      createdAt: widget.customer.createdAt,
      updatedAt: DateTime.now(),
      invoiceIds: widget.customer.invoiceIds,
      logIds: widget.customer.logIds,
    );

    // ✅ التحقق من إمكانية الانتقال إلى الحالة الجديدة (إجراء دفاعي)
    // حتى لو لم يتم تغيير الحالة في هذه الصفحة، يضمن هذا الفحص
    // عدم كسر قواعد انتقال الحالات إذا تمت إضافة حقل الحالة لاحقًا.
    if (!widget.customer.canTransitionToStatus(updatedCustomer.status)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن الانتقال إلى الحالة المحددة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // الحصول على مرجع لـ CustomerBloc قبل العملية غير المتزامنة
    final customerBloc = context.read<CustomerBloc>();

    // استخدام النظام الجديد لإدارة عملية الحفظ
    performBlocSaveOperation(
      triggerSave: () {
        customerBloc.add(UpdateCustomerEvent(updatedCustomer));
      },
      successMessage: 'تم تحديث العميل بنجاح',
      loadingMessage: 'جاري تحديث العميل...',
    );
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
}




