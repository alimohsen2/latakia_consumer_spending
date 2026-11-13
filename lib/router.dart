import 'package:go_router/go_router.dart';
import 'data/store.dart';
import 'widgets/shell.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/taxpayers_screen.dart';
import 'screens/taxpayer_file_screen.dart';
import 'screens/reports_screens.dart';
import 'screens/registers_screens.dart';
import 'screens/sales_screens.dart';
import 'screens/admin_screens.dart';
import 'screens/archive_screens.dart';
import '../field_monitoring/screens/field_monitor_screen.dart';
import 'screens/misc_screens.dart';
import 'screens/profile_screen.dart';

const _guards = [
  ['/reports-center', 'reports.center'],
  ['/taxpayers/new', 'taxpayers.edit'],
  ['/taxpayers', 'taxpayers.view'],
  ['/reports/new', 'reports.create'],
  ['/reports', 'reports.view'],
  ['/approvals', 'reports.approve|reports.endorse'],
  ['/violations', 'registers.view'],
  ['/followup', 'registers.view'],
  ['/statements', 'statements.edit'],
  ['/analytics', 'analytics.view'],
  ['/declines', 'analytics.view'],
  ['/alerts', 'alerts.view'],
  ['/archive', 'archive.view'],
  ['/field/monitor', 'field.view'],
  ['/users', 'users.manage'],
  ['/users/new', 'users.manage'],
  ['/users/:id/activity', 'users.manage'],
  ['/users/:id/profile', 'users.manage'],
  ['/active-users', 'users.manage'],
  ['/permissions', 'permissions.manage'],
  ['/routing', 'alerts.route'],
  ['/serials', 'serials.manage'],
  ['/audit', 'audit.view'],
  ['/integrity', 'integrity.view'],
  ['/settings', 'settings.manage'],
];

GoRouter buildRouter(AppStore store) => GoRouter(
      refreshListenable: store,
      initialLocation: '/',
      redirect: (context, state) {
        final p = state.matchedLocation;
        if (p == '/verify') return null;
        if (!store.loggedIn) return p == '/login' ? null : '/login';
        if (store.me!.passwordChangeRequired && p != '/change-password') {
          return '/change-password';
        }
        if (p == '/login') return '/';
        for (final g in _guards) {
          if (p == g[0] || p.startsWith('${g[0]}/')) {
            return store.can(g[1]) ? null : '/';
          }
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
        GoRoute(
            path: '/change-password',
            builder: (c, s) => const ChangePasswordScreen()),
        GoRoute(path: '/verify', builder: (c, s) => const VerifyScreen()),
        ShellRoute(
          builder: (c, s, child) =>
              AppShell(location: s.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
            GoRoute(
                path: '/taxpayers',
                builder: (c, s) => TaxpayersScreen(
                    initialQuery: s.uri.queryParameters['q'] ?? '')),
            GoRoute(
                path: '/taxpayers/new',
                builder: (c, s) => const TaxpayerFormScreen()),
            GoRoute(
                path: '/taxpayers/:id',
                builder: (c, s) =>
                    TaxpayerProfileScreen(id: s.pathParameters['id']!)),
            GoRoute(
                path: '/taxpayers/:id/edit',
                builder: (c, s) =>
                    TaxpayerFormScreen(id: s.pathParameters['id'])),
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
            GoRoute(
                path: '/taxpayers/:id/file',
                builder: (c, s) =>
                    TaxpayerFileScreen(id: s.pathParameters['id']!)),
            GoRoute(path: '/reports', builder: (c, s) => const ReportsScreen()),
            GoRoute(
                path: '/reports/new',
                builder: (c, s) =>
                    ReportFormScreen(taxpayerId: s.uri.queryParameters['tp'])),
            GoRoute(
                path: '/reports/:id',
                builder: (c, s) =>
                    ReportViewScreen(id: s.pathParameters['id']!)),
            GoRoute(
                path: '/reports/:id/edit',
                builder: (c, s) =>
                    ReportFormScreen(id: s.pathParameters['id'])),
            GoRoute(
                path: '/approvals', builder: (c, s) => const ApprovalsScreen()),
            GoRoute(
                path: '/violations',
                builder: (c, s) => const ViolationsScreen()),
            GoRoute(
                path: '/followup', builder: (c, s) => const FollowupScreen()),
            GoRoute(
                path: '/statements',
                builder: (c, s) => const StatementsScreen()),
            GoRoute(
                path: '/analytics',
                builder: (c, s) => const SalesOverviewScreen()),
            GoRoute(
                path: '/analytics/:id',
                builder: (c, s) =>
                    TaxpayerSalesScreen(id: s.pathParameters['id']!)),
            GoRoute(
                path: '/declines', builder: (c, s) => const DeclinesScreen()),
            GoRoute(path: '/alerts', builder: (c, s) => const AlertsScreen()),
            GoRoute(
                path: '/reports-center',
                builder: (c, s) => const ReportsCenterScreen()),
            GoRoute(path: '/archive', builder: (c, s) => const ArchiveScreen()),
            GoRoute(
                path: '/archive/:id',
                builder: (c, s) =>
                    ArchiveDetailScreen(id: s.pathParameters['id']!)),
            GoRoute(
                path: '/field/monitor',
                builder: (c, s) => const FieldMonitorScreen(
                      apiBaseUrl: '',
                      token: '',
                      inspectorId: '',
                    )),
            GoRoute(
                path: '/users/:id/profile',
                builder: (c, s) =>
                    ProfileScreen(userId: s.pathParameters['id']!)),
            GoRoute(
                path: '/users/:id/activity',
                builder: (c, s) =>
                    AuditScreen(userId: s.pathParameters['id']!)),
            GoRoute(path: '/users/new',
                builder: (c, s) => const CreateAccountScreen()),
            GoRoute(path: '/users', builder: (c, s) => const UsersScreen()),
            GoRoute(
                path: '/active-users',
                builder: (c, s) => const ActiveUsersScreen()),
            GoRoute(
                path: '/permissions',
                builder: (c, s) => const PermissionsScreen()),
            GoRoute(path: '/routing', builder: (c, s) => const RoutingScreen()),
            GoRoute(path: '/serials', builder: (c, s) => const SerialsScreen()),
            GoRoute(path: '/audit', builder: (c, s) => const AuditScreen()),
            GoRoute(
                path: '/integrity', builder: (c, s) => const IntegrityScreen()),
            GoRoute(
                path: '/settings', builder: (c, s) => const SettingsScreen()),
          ],
        ),
      ],
    );
