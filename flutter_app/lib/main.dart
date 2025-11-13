import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/two_fa_setup_screen.dart';
import 'features/auth/two_fa_verify_screen.dart';
import 'features/auth/backup_codes_screen.dart';
import 'features/settings/two_fa_settings_screen.dart';
import 'features/home/home_screen.dart';
import 'features/calendar/calendar_month_view.dart';
import 'features/calendar/calendar_week_view.dart';
import 'features/calendar/calendar_day_view.dart';
import 'features/calendar/event_detail_screen.dart';
import 'features/calendar/event_form_screen.dart';
import 'features/calendar/calendar_provider.dart';
import 'features/kiosk/kiosk_today_screen.dart';
import 'features/kiosk/kiosk_week_screen.dart';
import 'api/client.dart';
import 'services/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage
  await LocalStorage.instance.init();

  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        // Auth routes
        GoRoute(path:'/', builder:(c,s)=>const LoginScreen()),

        GoRoute(
          path:'/2fa/setup',
          builder:(c,s)=>const TwoFASetupScreen(),
        ),
        GoRoute(
          path:'/2fa/verify',
          builder:(c,s){
            final data = s.extra as Map<String, dynamic>?;
            return TwoFAVerifyScreen(loginData: data ?? {});
          },
        ),
        GoRoute(
          path:'/2fa/backup-codes',
          builder:(c,s){
            final codes = s.extra as List<String>?;
            return BackupCodesScreen(existingCodes: codes);
          },
        ),
        GoRoute(
          path:'/settings/security',
          builder:(c,s)=>const TwoFASettingsScreen(),
        ),

        // App routes
        GoRoute(path:'/home', builder:(c,s)=>const HomeScreen()),

        // Calendar routes
        GoRoute(
          path:'/calendar',
          builder:(c,s)=>const CalendarMonthView(),
        ),
        GoRoute(
          path:'/calendar/week',
          builder:(c,s)=>const CalendarWeekView(),
        ),
        GoRoute(
          path:'/calendar/day',
          builder:(c,s){
            final date = s.extra as DateTime?;
            return CalendarDayView(initialDate: date);
          },
        ),
        GoRoute(
          path:'/calendar/event/create',
          builder:(c,s){
            final date = s.extra as DateTime?;
            return EventFormScreen(initialDate: date);
          },
        ),
        GoRoute(
          path:'/calendar/event/edit',
          builder:(c,s){
            final event = s.extra as CalendarEvent;
            return EventFormScreen(event: event);
          },
        ),
        GoRoute(
          path:'/calendar/event/:id',
          builder:(c,s){
            final id = s.pathParameters['id']!;
            return EventDetailScreen(eventId: id);
          },
        ),

        // Kiosk routes
        GoRoute(
          path:'/kiosk/today',
          builder:(c,s)=>const KioskTodayScreen(),
        ),
        GoRoute(
          path:'/kiosk/week',
          builder:(c,s)=>const KioskWeekScreen(),
        ),
      ],
      redirect: (ctx, st) async {
        // Skip auth check for kiosk routes
        if (st.matchedLocation.startsWith('/kiosk/')) {
          final ok = await ApiClient.instance.hasToken();
          if (!ok) return '/';
          return null;
        }
        if (st.matchedLocation == '/') return null;
        final ok = await ApiClient.instance.hasToken();
        if (!ok) return '/';
        return null;
      },
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
    );
  }
}
