# Save Operation Mixin

## نظام إدارة عمليات الحفظ الموحد

هذا النظام يحل المشاكل التالية في شاشات الإضافة:

### المشاكل التي تم حلها:

1. **عدم ظهور رسائل النجاح**: الآن تظهر رسائل النجاح قبل الانتقال للشاشة السابقة
2. **الحفظ المتعدد**: منع الضغط على زر الحفظ أكثر من مرة
3. **عدم الرجوع للشاشة السابقة**: الرجوع التلقائي بعد نجاح العملية
4. **عدم حفظ البيانات أحياناً**: انتظار اكتمال العملية قبل التنقل
5. **عدم وجود شاشة تحميل**: حوار تحميل أثناء عملية الحفظ

### الاستخدام:

#### 1. إضافة Mixin للصفحة:

```dart
import '../../../../core/mixins/save_operation_mixin.dart';

class _CreateYourEntityPageState extends State<CreateYourEntityPage>
    with SaveOperationMixin {
  // باقي الكود...
}
```

#### 2. تحديث BLoC Listener:

```dart
listener: (context, state) {
  if (state is YourBlocLoaded) {
    // للبيانات المرتبطة
    setState(() {
      _categories = state.categories;
    });

    // للحفظ الناجح
    if (isSaving) {
      completeSaveOperation(
        successMessage: 'تم إنشاء العنصر بنجاح',
      );
    }
  } else if (state is YourBlocError) {
    if (isSaving) {
      failSaveOperation(errorMessage: state.message);
    } else {
      // عرض خطأ عادي للعمليات الأخرى
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
      );
    }
  }
},
```

#### 3. تحديث زر الحفظ:

```dart
LoadingButton(
  text: 'إنشاء العنصر',
  onPressed: isSaving ? null : _createEntity,
  isLoading: isSaving,
  // باقي الخصائص...
)
```

#### 4. تحديث دالة الحفظ:

```dart
Future<void> _createEntity() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  // إنشاء الكيان...
  final entity = YourEntity(/* البيانات */);

  // استخدام النظام الجديد
  await performBlocSaveOperation(
    triggerSave: () {
      context.read<YourBloc>().add(AddYourEntityEvent(entity));
    },
    successMessage: 'تم إنشاء العنصر بنجاح',
    loadingMessage: 'جاري الإنشاء...',
  );
}
```

### الدوال المتاحة:

#### `performBlocSaveOperation`

للاستخدام مع BLoC patterns:

- `triggerSave`: دالة تنفيذ عملية الحفظ
- `successMessage`: رسالة النجاح
- `loadingMessage`: رسالة التحميل
- `navigateBackOnSuccess`: الرجوع التلقائي (افتراضي: true)

#### `performSaveOperation`

للاستخدام مع العمليات المباشرة:

- `saveFunction`: دالة الحفظ التي ترجع `Future<bool>`
- باقي المعاملات نفسها

#### `completeSaveOperation`

لإنهاء العملية بنجاح (للاستخدام في BLoC listener):

- `successMessage`: رسالة النجاح
- `onSuccess`: دالة callback اختيارية
- `navigateBackOnSuccess`: الرجوع التلقائي

#### `failSaveOperation`

لإنهاء العملية بخطأ (للاستخدام في BLoC listener):

- `errorMessage`: رسالة الخطأ
- `onError`: دالة callback اختيارية

### الخصائص المتاحة:

#### `isSaving`

متغير boolean يشير إلى حالة الحفظ الحالية. استخدمه في:

- تعطيل زر الحفظ
- التحقق في BLoC listener
- إظهار حالة التحميل

### أمثلة كاملة:

انظر إلى الملفات التالية كأمثلة للتطبيق الصحيح:

- `lib/features/expenses/presentation/pages/create_expense_page.dart`
- `lib/features/customers/presentation/pages/create_customer_page.dart`

### ملاحظات مهمة:

1. **لا تستدعي `performBlocSaveOperation` إذا كان `isSaving = true`**
2. **تأكد من استدعاء `completeSaveOperation` أو `failSaveOperation` في BLoC listener**
3. **استخدم `isSaving` في `onPressed` للزر لمنع الضغط المتعدد**
4. **النظام يدير حوار التحميل تلقائياً**
5. **الرسائل تظهر قبل التنقل للشاشة السابقة**

### استكشاف الأخطاء:

#### المشكلة: رسائل النجاح لا تظهر

**الحل**: تأكد من استدعاء `completeSaveOperation` في BLoC listener مع التحقق من `isSaving`

#### المشكلة: الحفظ يحدث أكثر من مرة

**الحل**: استخدم `isSaving ? null : _createEntity` في `onPressed`

#### المشكلة: لا يتم الرجوع للشاشة السابقة

**الحل**: `completeSaveOperation` تتولى التنقل تلقائياً، لا تستدعي `Navigator.pop` يدوياً

#### المشكلة: حوار التحميل لا يختفي

**الحل**: تأكد من استدعاء `completeSaveOperation` أو `failSaveOperation` في جميع الحالات
