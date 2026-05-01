import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/error_reporter.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'providers/delivery_auth_provider.dart';
import 'screens/delivery_login_screen.dart';
import 'screens/delivery_home_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/return_verification_screen.dart';
import 'screens/delivery_profile_screen.dart';

int? _parseRouteInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

Route<dynamic> _invalidRoute(String routeName) {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Invalid navigation')),
      body: Center(child: Text('Could not open route: $routeName')),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.message('uncaught Flutter error: ${details.exceptionAsString()}');
    if (details.stack != null) {
      ErrorReporter.report(details.exception, details.stack!, context: 'flutter');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(error, stack, context: 'platform');
    return false;
  };

  try {
    await DeliveryApiService().init();
  } catch (error, stackTrace) {
    ErrorReporter.report(error, stackTrace, context: 'api-init');
    if (!kReleaseMode) {
      rethrow;
    }
  }
  runApp(const FeriwalaDeliveryApp());
}

class FeriwalaDeliveryApp extends StatelessWidget {
  const FeriwalaDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeliveryAuthProvider()..init()),
      ],
      child: MaterialApp(
        title: 'Feriwala Delivery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF16213E),
            primary: const Color(0xFF16213E),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF16213E),
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const DeliveryLoginScreen(),
          '/home': (context) => const DeliveryHomeScreen(),
          '/profile': (context) => const DeliveryProfileScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/task-detail') {
            final taskId = _parseRouteInt(settings.arguments);
            if (taskId == null) return _invalidRoute('/task-detail');
            return MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId));
          }
          if (settings.name == '/return-verification') {
            final taskId = _parseRouteInt(settings.arguments);
            if (taskId == null) return _invalidRoute('/return-verification');
            return MaterialPageRoute(builder: (_) => ReturnVerificationScreen(taskId: taskId));
          }
          return null;
        },
        onUnknownRoute: (settings) => _invalidRoute(settings.name ?? 'unknown'),
      ),
    );
  }
}
