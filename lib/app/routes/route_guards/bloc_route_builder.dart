import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// دالة مساعدة لبناء مسار مع BlocProvider واحد
Widget buildBlocRoute<T extends Bloc>({
  required T bloc,
  required Widget child,
}) {
  return BlocProvider<T>(
    create: (context) => bloc,
    child: child,
  );
}

/// دالة مساعدة لبناء مسار مع MultiBlocProvider
Widget buildMultiBlocRoute({
  required List<BlocProvider> blocProviders,
  required Widget child,
}) {
  return MultiBlocProvider(
    providers: blocProviders,
    child: child,
  );
}

/// دالة مساعدة لبناء مسار مع BlocProvider و event يتم إرساله تلقائيًا
Widget buildBlocRouteWithEvent<T extends Bloc, E extends Object>({
  required T bloc,
  required E event,
  required Widget child,
}) {
  return BlocProvider<T>(
    create: (context) => bloc..add(event),
    child: child,
  );
}
