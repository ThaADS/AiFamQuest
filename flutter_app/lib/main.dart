import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/supabase_login_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';
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
import 'features/study/study_planner_screen.dart';
import 'features/study/study_sessions_screen.dart';
import 'features/study/study_session_detail.dart';
import 'features/gamification/shop_screen.dart';
import 'features/gamification/badge_catalog_screen.dart';
import 'features/gamification/leaderboard_screen.dart';
import 'features/gamification/user_stats_screen.dart';
import 'features/vision/vision_screen.dart';
import 'features/ai/ai_task_planner_screen.dart';
import 'features/tasks/recurring_task_list_screen.dart';
import 'features/tasks/parent_approval_screen.dart';
import 'features/fairness/fairness_dashboard_screen.dart';
import 'features/helper/helper_home_screen.dart';
import 'features/helper/helper_invite_screen.dart';
import 'features/helper/helper_join_screen.dart';
import 'features/voice/voice_task.dart';
import 'features/family/family_members_screen.dart';
import 'features/family/family_invite_screen.dart';
import 'features/settings/profile_settings_screen.dart';
import 'features/settings/data_export_screen.dart';
import 'features/settings/account_deletion_screen.dart';
import 'features/notifications/notification_center_screen.dart';
import 'api/client.dart';
import 'services/local_storage.dart';
import 'core/supabase.dart';
import 'providers/theme_provider.dart';
import 'core/app_logger.dart';
import 'core/secrets_validator.dart';

void main() async {
  try {
    AppLogger.debug('[INIT] 🚀 Starting FamQuest initialization...');

    WidgetsFlutterBinding.ensureInitialized();
    AppLogger.debug('[INIT] ✅ Flutter binding initialized');

    // Load environment variables (ignore if missing in web build)
    AppLogger.debug('[INIT] 📂 Loading .env file...');
    await dotenv.load(fileName: '.env', isOptional: true);
    AppLogger.debug('[INIT] ✅ Environment loaded');

    // Validate all required secrets (bank-grade security)
    AppLogger.debug('[INIT] 🔒 Validating secrets...');
    await SecretsValidator.validate();
    AppLogger.debug('[INIT] ✅ Secrets validated');

    // Read Supabase config from environment or dart-define
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
        const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    AppLogger.debug('[INIT] 🔑 Supabase URL: ${supabaseUrl.isNotEmpty ? supabaseUrl.substring(0, 30) + "..." : "MISSING"}');
    AppLogger.debug('[INIT] 🔑 Supabase Key: ${supabaseAnonKey.isNotEmpty ? "Present (${supabaseAnonKey.length} chars)" : "MISSING"}');

    // Initialize Supabase only if credentials are present
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      AppLogger.debug('[INIT] 🔄 Initializing Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      AppLogger.debug('[INIT] ✅ Supabase initialized successfully');
    } else {
      AppLogger.debug('[INIT] ⚠️ Supabase credentials missing - skipping initialization');
    }

    // Initialize local storage
    AppLogger.debug('[INIT] 💾 Initializing local storage...');
    await FamQuestStorage.instance.init();
    AppLogger.debug('[INIT] ✅ Local storage initialized');

    // Initialize Supabase realtime service
    // Note: Will be fully activated after login with familyId
    // Connection state listener is set up here for monitoring
    AppLogger.debug('[INIT] 🎯 All initialization complete - launching app...');

    runApp(const ProviderScope(child: App()));
    AppLogger.debug('[INIT] 🎉 App launched successfully');
  } catch (e, stackTrace) {
    AppLogger.debug('[INIT] ❌ FATAL ERROR during initialization:');
    AppLogger.debug('[INIT] Error: $e');
    AppLogger.debug('[INIT] Stack trace: $stackTrace');

    // Try to show error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class App extends ConsumerWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    final router = GoRouter(
      routes: [
        // Auth routes
        GoRoute(path: '/', builder: (c, s) => const SupabaseLoginScreen()),

        // Password Reset routes
        GoRoute(
          path: '/auth/forgot-password',
          builder: (c, s) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/auth/reset-password',
          builder: (c, s) {
            final token = s.uri.queryParameters['token'];
            return ResetPasswordScreen(token: token);
          },
        ),

        GoRoute(
          path: '/2fa/setup',
          builder: (c, s) => const TwoFASetupScreen(),
        ),
        GoRoute(
          path: '/2fa/verify',
          builder: (c, s) {
            final data = s.extra as Map<String, dynamic>?;
            return TwoFAVerifyScreen(loginData: data ?? {});
          },
        ),
        GoRoute(
          path: '/2fa/backup-codes',
          builder: (c, s) {
            final codes = s.extra as List<String>?;
            return BackupCodesScreen(existingCodes: codes);
          },
        ),
        GoRoute(
          path: '/settings/security',
          builder: (c, s) => const TwoFASettingsScreen(),
        ),

        // App routes
        GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),

        // Notifications route
        GoRoute(
          path: '/notifications',
          builder: (c, s) => const NotificationCenterScreen(),
        ),

        // Calendar routes
        GoRoute(
          path: '/calendar',
          builder: (c, s) => const CalendarMonthView(),
        ),
        GoRoute(
          path: '/calendar/week',
          builder: (c, s) => const CalendarWeekView(),
        ),
        GoRoute(
          path: '/calendar/day',
          builder: (c, s) {
            final date = s.extra as DateTime?;
            return CalendarDayView(initialDate: date);
          },
        ),
        GoRoute(
          path: '/calendar/event/create',
          builder: (c, s) {
            final date = s.extra as DateTime?;
            return EventFormScreen(initialDate: date);
          },
        ),
        GoRoute(
          path: '/calendar/event/edit',
          builder: (c, s) {
            final event = s.extra as CalendarEvent;
            return EventFormScreen(event: event);
          },
        ),
        GoRoute(
          path: '/calendar/event/:id',
          builder: (c, s) {
            final id = s.pathParameters['id']!;
            return EventDetailScreen(eventId: id);
          },
        ),

        // Kiosk routes
        GoRoute(
          path: '/kiosk/today',
          builder: (c, s) => const KioskTodayScreen(),
        ),
        GoRoute(
          path: '/kiosk/week',
          builder: (c, s) => const KioskWeekScreen(),
        ),

        // Study routes
        GoRoute(
          path: '/study/planner',
          builder: (c, s) {
            final user = supabase.auth.currentUser;
            return StudyPlannerScreen(userId: user?.id ?? '');
          },
        ),
        GoRoute(
          path: '/study/sessions',
          builder: (c, s) {
            final studyItemId = s.extra as String;
            return StudySessionsScreen(studyItemId: studyItemId);
          },
        ),
        GoRoute(
          path: '/study/session-detail',
          builder: (c, s) {
            final sessionId = s.extra as String;
            return StudySessionDetail(sessionId: sessionId);
          },
        ),

        // Gamification routes
        GoRoute(
          path: '/gamification/shop',
          builder: (c, s) => const ShopScreen(),
        ),
        GoRoute(
          path: '/gamification/badges',
          builder: (c, s) {
            final user = supabase.auth.currentUser;
            return BadgeCatalogScreen(userId: user?.id ?? '');
          },
        ),
        GoRoute(
          path: '/gamification/leaderboard',
          builder: (c, s) {
            final user = supabase.auth.currentUser;
            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('Not authenticated')),
              );
            }

            return FutureBuilder(
              future: supabase
                  .from('users')
                  .select('family_id')
                  .eq('id', user.id)
                  .single(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final familyId = snapshot.data?['family_id'] as String? ?? '';
                return LeaderboardScreen(
                  familyId: familyId,
                  currentUserId: user.id,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/gamification/stats',
          builder: (c, s) {
            final user = supabase.auth.currentUser;
            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('Not authenticated')),
              );
            }

            return FutureBuilder(
              future: supabase
                  .from('users')
                  .select('family_id')
                  .eq('id', user.id)
                  .single(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final familyId = snapshot.data?['family_id'] as String? ?? '';
                return UserStatsScreen(
                  userId: user.id,
                  familyId: familyId,
                );
              },
            );
          },
        ),

        // AI/Vision routes
        GoRoute(
          path: '/ai/planner',
          builder: (c, s) => const AITaskPlannerScreen(),
        ),
        GoRoute(
          path: '/vision',
          builder: (c, s) => const VisionScreen(),
        ),
        GoRoute(
          path: '/voice/task',
          builder: (c, s) => const VoiceTaskScreen(),
        ),

        // Task management routes
        GoRoute(
          path: '/tasks/recurring',
          builder: (c, s) => const RecurringTaskListScreen(),
        ),
        GoRoute(
          path: '/tasks/approval',
          builder: (c, s) => const ParentApprovalScreen(),
        ),

        // Fairness routes
        GoRoute(
          path: '/fairness',
          builder: (c, s) => const FairnessDashboardScreen(),
        ),

        // Helper routes
        GoRoute(
          path: '/helper/home',
          builder: (c, s) => const HelperHomeScreen(),
        ),
        GoRoute(
          path: '/helper/invite',
          builder: (c, s) => const HelperInviteScreen(),
        ),
        GoRoute(
          path: '/helper/join',
          builder: (c, s) => const HelperJoinScreen(),
        ),

        // Family routes
        GoRoute(
          path: '/family/members',
          builder: (c, s) => const FamilyMembersScreen(),
        ),
        GoRoute(
          path: '/family/invite',
          builder: (c, s) => const FamilyInviteScreen(),
        ),

        // Settings routes
        GoRoute(
          path: '/settings/profile',
          builder: (c, s) => const ProfileSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/data-export',
          builder: (c, s) => const DataExportScreen(),
        ),
        GoRoute(
          path: '/settings/delete-account',
          builder: (c, s) => const AccountDeletionScreen(),
        ),
      ],
      redirect: (ctx, st) async {
        AppLogger.debug('[ROUTER] 🔀 Checking route: ${st.matchedLocation}');

        // Skip auth check for kiosk routes
        if (st.matchedLocation.startsWith('/kiosk/')) {
          final ok = await ApiClient.instance.hasToken();
          AppLogger.debug('[ROUTER] Kiosk route - has token: $ok');
          if (!ok) return '/';
          return null;
        }

        // Allow public auth routes
        if (st.matchedLocation == '/' ||
            st.matchedLocation.startsWith('/auth/forgot-password') ||
            st.matchedLocation.startsWith('/auth/reset-password')) {
          AppLogger.debug('[ROUTER] Public auth route - allowed');
          return null;
        }

        // For all other routes, check Supabase auth
        final session = supabase.auth.currentSession;
        final isAuthenticated = session != null;
        AppLogger.debug('[ROUTER] Protected route - authenticated: $isAuthenticated');

        if (!isAuthenticated) {
          AppLogger.debug('[ROUTER] ❌ Not authenticated - redirecting to /');
          return '/';
        }

        AppLogger.debug('[ROUTER] ✅ Authenticated - allowing access');
        return null;
      },
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: currentTheme.themeData,
      debugShowCheckedModeBanner: false,
    );
  }
}
