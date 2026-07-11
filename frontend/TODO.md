# Fix Plan - Make it PRO

## 1. Backend Fixes (Python/Flask)

### A. Fix `/api/admin/school-metrics` endpoint
- Return real counts from database instead of hardcoded values
- Add: students count, teachers count, classes count, parents count, attendance rate

### B. Add `/api/admin/reports/{type}` endpoint
- Generate CSV/Excel reports for: students, attendance, academic, financial, teachers, classes
- Return downloadable file

### C. Add missing endpoints
- Subjects CRUD (already partially exists?)
- Exams CRUD
- Notifications list
- Audit logs list

## 2. Frontend Fixes

### A. Fix Dashboard
- Load real data from `/api/admin/school-metrics`
- Update chart data if API provides it

### B. Fix Reports page
- Stats load from real API
- Report generation works with backend

### C. Sidebar component
- Use shared components/sidebar.html

## 3. Polish
- Loading states
- Error handling
- Empty states