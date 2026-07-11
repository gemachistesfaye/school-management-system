const fs = require('fs');
const path = require('path');

const dir = 'e:/GitHub Repo/school-management-system/frontend/pages/admin';

const innerSidebarHTML = `
    <div style="display: flex; align-items: center; gap: 12px; padding: 20px; border-bottom: 1px solid rgba(255,255,255,0.05);">
      <div style="width: 36px; height: 36px; background: linear-gradient(135deg,#f2d480,#c39a48); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 18px; color: #0F172A; flex-shrink: 0;">🎓</div>
      <div>
        <div style="color: #fff; font-weight: 700; font-size: 16px; font-family: 'Inter', sans-serif; line-height: 1.2;">EduFlow</div>
        <div style="color: #C39A48; font-weight: 700; font-size: 10px; text-transform: uppercase; letter-spacing: 0.1em; margin-top: 2px;">School Navigator</div>
      </div>
    </div>
    <nav class="sidebar-nav" style="flex: 1; overflow-y: auto; padding: 12px 0;">
      <div class="sidebar-section-label">Main</div>
      <a href="dashboard.html" class="nav-item"><i class="fa-solid fa-house"></i> Dashboard</a>
      <a href="students.html" class="nav-item"><i class="fa-solid fa-users"></i> Students</a>
      <a href="teachers.html" class="nav-item"><i class="fa-solid fa-chalkboard-user"></i> Teachers</a>
      <a href="parents.html" class="nav-item"><i class="fa-solid fa-people-roof"></i> Parents</a>
      <a href="classes.html" class="nav-item"><i class="fa-solid fa-school"></i> Classes</a>
      <a href="subjects.html" class="nav-item"><i class="fa-solid fa-book"></i> Subjects</a>
      <div class="sidebar-section-label">Academics</div>
      <a href="attendance.html" class="nav-item"><i class="fa-solid fa-calendar-check"></i> Attendance</a>
      <a href="grades.html" class="nav-item"><i class="fa-solid fa-chart-line"></i> Grades</a>
      <a href="exams.html" class="nav-item"><i class="fa-solid fa-file-signature"></i> Exams</a>
      <a href="timetable.html" class="nav-item"><i class="fa-solid fa-clock"></i> Timetable</a>
      <a href="academic-year.html" class="nav-item"><i class="fa-solid fa-calendar-days"></i> Academic Year</a>
      <div class="sidebar-section-label">System</div>
      <a href="announcements.html" class="nav-item"><i class="fa-solid fa-bullhorn"></i> Announcements</a>
      <a href="reports.html" class="nav-item"><i class="fa-solid fa-chart-pie"></i> Reports</a>
      <a href="notifications.html" class="nav-item"><i class="fa-regular fa-bell"></i> Notifications</a>
      <a href="audit-logs.html" class="nav-item"><i class="fa-solid fa-shield-halved"></i> Audit Logs</a>
      <a href="settings.html" class="nav-item"><i class="fa-solid fa-gear"></i> Settings</a>
    </nav>
    <div style="padding: 16px; border-top: 1px solid rgba(255,255,255,0.05); background: rgba(0,0,0,0.15);">
      <button id="logout-btn" style="display: flex; align-items: center; justify-content: center; gap: 8px; width: 100%; padding: 10px; border-radius: 8px; background: transparent !important; border: none !important; color: #94A3B8 !important; font-size: 13.5px; font-weight: 600; cursor: pointer; transition: 0.2s;" onmouseover="this.style.color='#fff'; this.style.background='rgba(255,255,255,0.05)'" onmouseout="this.style.color='#94A3B8'; this.style.background='transparent'"><i class="fa-solid fa-arrow-right-from-bracket"></i> Logout</button>
    </div>`;

const premiumCSS = `
<style class="premium-sidebar-css">
  aside { background: #0F172A !important; border-right: none !important; }
  .nav-item { display:flex !important; align-items:center !important; gap:12px !important; padding:10px 16px !important; border-radius:10px !important; color:#94A3B8 !important; font-size:13.5px !important; font-weight:500 !important; text-decoration:none !important; transition:all 0.2s ease !important; margin: 2px 8px !important; font-family: 'Inter', sans-serif !important; box-sizing: border-box !important; background: transparent !important; border-left: 3px solid transparent !important; box-shadow: none !important; }
  .nav-item:hover { background:rgba(255,255,255,0.06) !important; color:#F8FAFC !important; }
  .nav-item.active { background:rgba(255,255,255,0.1) !important; color:#F8FAFC !important; font-weight:600 !important; border-left: 3px solid #C39A48 !important; border-radius: 4px 10px 10px 4px !important; box-shadow: none !important; }
  .nav-item i { width: 16px !important; text-align: center !important; font-size: 14px !important; opacity: 0.8 !important; transition:0.2s !important; color: inherit !important; }
  .nav-item:hover i { opacity: 1 !important; color: #fff !important; }
  .nav-item.active i { opacity: 1 !important; color: #E8CE8A !important; }
  .sidebar-nav::-webkit-scrollbar { width: 4px; }
  .sidebar-nav::-webkit-scrollbar-track { background: transparent; }
  .sidebar-nav::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 10px; }
  .sidebar-section-label { font-size:10px !important; font-weight:700 !important; text-transform:uppercase !important; letter-spacing:0.15em !important; color:#64748B !important; padding:20px 24px 8px !important; font-family: 'Inter', sans-serif !important; }
</style>`;

const fontAwesomeCDN = `<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"/>`;

const files = fs.readdirSync(dir).filter(f => f.endsWith('.html'));

files.forEach(file => {
  if (file === 'layout.html' || file === 'admin.html' || file === '_admin-head.html') return;
  const filePath = path.join(dir, file);
  let content = fs.readFileSync(filePath, 'utf8');
  
  // 1. Replace the inner content of <aside> ... </aside>
  content = content.replace(/(<aside[^>]*>)[\s\S]*?(<\/aside>)/i, `$1\n${innerSidebarHTML}\n$2`);
  
  // 2. Remove old premium-sidebar-css if it exists
  content = content.replace(/<style class="premium-sidebar-css">[\s\S]*?<\/style>/i, '');
  
  // 3. Inject premium CSS right before </head>
  content = content.replace(/<\/head>/i, `${premiumCSS}\n</head>`);
  
  // 4. Inject FontAwesome if not exists
  if (!content.includes('font-awesome/6.4.0')) {
    content = content.replace(/<\/head>/i, `  ${fontAwesomeCDN}\n</head>`);
  }
  
  // 5. Ensure active script exists
  if (!content.includes("location.pathname.split('/').pop()")) {
    const activeScript = `
<script>
  document.addEventListener('DOMContentLoaded', () => {
    const page = location.pathname.split('/').pop().replace('.html', '');
    document.querySelectorAll('.nav-item').forEach(link => {
      if (link.getAttribute('href') === page + '.html' || link.getAttribute('href') === page) {
        link.classList.add('active');
      } else {
        link.classList.remove('active');
      }
    });
  });
</script>
</body>`;
    content = content.replace('</body>', activeScript);
  }
  
  fs.writeFileSync(filePath, content);
  console.log("Updated unified sidebar in: " + file);
});
