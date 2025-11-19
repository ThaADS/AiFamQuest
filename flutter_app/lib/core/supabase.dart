import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client instance
final supabase = Supabase.instance.client;

/// Quick access to auth
final supabaseAuth = supabase.auth;

/// Quick access to current user
User? get currentUser => supabase.auth.currentUser;

/// Check if user is authenticated
bool get isAuthenticated => currentUser != null;
