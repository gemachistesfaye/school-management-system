/**
 * Supabase Client - Frontend Integration
 * 
 * This client connects directly to Supabase for:
 * - Authentication (Supabase Auth)
 * - Database queries (with RLS)
 * - File Storage
 * - Realtime subscriptions
 */
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://udpcbvcmynibfulmfjwe.supabase.co';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVkcGNidmNteW5pYmZ1bG1mandlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg3MDk3NjEsImV4cCI6MjA2NDI4NTc2MX0.qXwPxVjxHUEBuE6n6BXWxvLnTveBMsS1G5u4wq9QKgc';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  },
  realtime: {
    params: {
      eventsPerSecond: 10
    }
  }
});

// ============================================================
// AUTHENTICATION
// ============================================================

/**
 * Sign in with email and password
 */
export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

/**
 * Sign out current user
 */
export async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

/**
 * Get current session
 */
export async function getSession() {
  const { data: { session }, error } = await supabase.auth.getSession();
  if (error) throw error;
  return session;
}

/**
 * Get current user
 */
export async function getCurrentUser() {
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) throw error;
  return user;
}

/**
 * Create a new user (admin creates teacher/student/parent)
 * This uses the admin API endpoint since regular users can't sign up others
 */
export async function adminCreateUser(email, password, userData) {
  // Use Flask backend proxy for admin user creation (requires admin privileges)
  const token = (await getSession())?.access_token;
  const res = await fetch('/api/admin/create-user', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({ email, password, ...userData })
  });
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.error || 'Failed to create user');
  }
  return res.json();
}

/**
 * Reset password
 */
export async function resetPassword(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/login.html`
  });
  if (error) throw error;
}

/**
 * Update user password
 */
export async function updatePassword(newPassword) {
  const { error } = await supabase.auth.updateUser({ password: newPassword });
  if (error) throw error;
}

// ============================================================
// PROFILE HELPERS
// ============================================================

/**
 * Get the current user's profile
 */
export async function getProfile() {
  const user = await getCurrentUser();
  if (!user) return null;
  
  const { data, error } = await supabase
    .from('profiles')
    .select('*, schools(name, code)')
    .eq('id', user.id)
    .single();
    
  if (error) throw error;
  return data;
}

/**
 * Get current user's school ID
 */
export async function getSchoolId() {
  const profile = await getProfile();
  return profile?.school_id;
}

/**
 * Get current user's role
 */
export async function getUserRole() {
  const profile = await getProfile();
  return profile?.role;
}

// ============================================================
// DATABASE HELPERS WITH PAGINATION
// ============================================================

const PAGE_SIZE = 20;

/**
 * Fetch paginated results
 */
export async function fetchPaginated(table, options = {}) {
  const {
    page = 1,
    pageSize = PAGE_SIZE,
    filters = {},
    orderBy = { column: 'created_at', ascending: false },
    select = '*'
  } = options;

  let query = supabase
    .from(table)
    .select(select, { count: 'exact' });

  // Apply filters
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      query = query.eq(key, value);
    }
  });

  // Apply ordering
  query = query.order(orderBy.column, { ascending: orderBy.ascending });

  // Apply pagination
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;
  query = query.range(from, to);

  const { data, error, count } = await query;
  if (error) throw error;

  return {
    data: data || [],
    total: count || 0,
    page,
    pageSize,
    totalPages: Math.ceil((count || 0) / pageSize)
  };
}

// ============================================================
// STORAGE HELPERS
// ============================================================

/**
 * Upload a file to Supabase Storage
 */
export async function uploadFile(bucket, path, file) {
  const { data, error } = await supabase.storage
    .from(bucket)
    .upload(path, file, {
      cacheControl: '3600',
      upsert: true
    });
  if (error) throw error;
  return data;
}

/**
 * Get public URL for a file
 */
export function getFileUrl(bucket, path) {
  const { data } = supabase.storage
    .from(bucket)
    .getPublicUrl(path);
  return data.publicUrl;
}

/**
 * Delete a file from storage
 */
export async function deleteFile(bucket, path) {
  const { error } = await supabase.storage
    .from(bucket)
    .remove([path]);
  if (error) throw error;
}

// ============================================================
// REALTIME SUBSCRIPTIONS
// ============================================================

/**
 * Subscribe to realtime changes on a table
 */
export function subscribeToTable(table, filter, callback) {
  const channel = supabase
    .channel(`public:${table}`)
    .on('postgres_changes',
      { event: '*', schema: 'public', table, filter },
      payload => callback(payload)
    )
    .subscribe();

  return () => supabase.removeChannel(channel);
}

/**
 * Subscribe to notifications for the current user
 */
export function subscribeToNotifications(userId, callback) {
  return subscribeToTable(
    'notifications',
    { filter: `user_id=eq.${userId}` },
    callback
  );
}

// ============================================================
// AUDIT LOGGING
// ============================================================

/**
 * Create an audit log entry
 */
export async function createAuditLog(action, entityType, entityId, details = {}) {
  try {
    const user = await getCurrentUser();
    const profile = await getProfile();
    
    await supabase.from('audit_logs').insert({
      school_id: profile.school_id,
      actor_id: user.id,
      actor_role: profile.role,
      action,
      entity_type: entityType,
      entity_id: entityId,
      details,
      ip_address: ''  // Will be populated by backend
    });
  } catch (err) {
    console.error('Audit log error:', err);
  }
}

// ============================================================
// NOTIFICATION HELPERS
// ============================================================

/**
 * Create a notification for a user
 */
export async function createNotification(userId, title, message, type = 'info', iconEmoji = null, linkUrl = null) {
  try {
    const profile = await getProfile();
    await supabase.from('notifications').insert({
      school_id: profile.school_id,
      user_id: userId,
      title,
      message,
      type,
      icon_emoji: iconEmoji,
      link_url: linkUrl
    });
  } catch (err) {
    console.error('Notification error:', err);
  }
}

// ============================================================
// DASHBOARD METRICS
// ============================================================

/**
 * Get dashboard metrics for a school
 */
export async function getDashboardMetrics(schoolId) {
  const [
    { count: students },
    { count: teachers },
    { count: parents },
    { count: classes },
    { count: subjects },
  ] = await Promise.all([
    supabase.from('students').select('*', { count: 'exact', head: true }).eq('school_id', schoolId).eq('archived', false),
    supabase.from('teachers').select('*', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('parents').select('*', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('classes').select('*', { count: 'exact', head: true }).eq('school_id', schoolId),
    supabase.from('subjects').select('*', { count: 'exact', head: true }).eq('school_id', schoolId).eq('is_active', true),
  ]);

  return {
    total_students: students || 0,
    total_teachers: teachers || 0,
    total_parents: parents || 0,
    total_classes: classes || 0,
    total_subjects: subjects || 0
  };
}

export default supabase;