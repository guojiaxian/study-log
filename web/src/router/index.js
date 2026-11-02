// ===== 路由表：URL ↔ 页面组件的映射 =====
// component 用 () => import(...) 懒加载：访问该页面时才下载对应 JS
import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  { path: '/', name: 'dashboard', component: () => import('../views/Dashboard.vue'), meta: { title: '首页' } },
  { path: '/manage', name: 'manage', component: () => import('../views/Manage.vue'), meta: { title: '管理' } },
  // 旧入口已并入管理页，重定向保持老链接可用
  { path: '/entry', redirect: '/manage' },
  { path: '/settings', redirect: '/manage' },
  { path: '/entry/manual', name: 'entry-manual', component: () => import('../views/EntryManual.vue'), meta: { title: '手动录入' } },
  { path: '/entry/ai', name: 'entry-ai', component: () => import('../views/EntryAi.vue'), meta: { title: '智能批量录入' } },
  { path: '/trend', name: 'trend', component: () => import('../views/Trend.vue'), meta: { title: '趋势分析' } },
  { path: '/exams', name: 'exams', component: () => import('../views/ExamList.vue'), meta: { title: '历史成绩' } },
  // 动态参数路由：/exams/42 中 42 可通过 route.params.id 取到
  { path: '/exams/:id', name: 'exam-detail', component: () => import('../views/ExamDetail.vue'), meta: { title: '考试详情' } },
  { path: '/analysis', name: 'analysis', component: () => import('../views/Analysis.vue'), meta: { title: '智能分析' } },
  { path: '/targets', name: 'targets', component: () => import('../views/Targets.vue'), meta: { title: '目标院校' } },
  // 兜底：未匹配的路径一律回首页
  { path: '/:pathMatch(.*)*', redirect: '/' },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),   // 每次切换页面回到顶部
});

// 每次路由切换后，用 meta.title 更新浏览器标签页标题
router.afterEach((to) => {
  const name = to.meta?.title ?? '';
  document.title = name ? `${name} · 孙晗菲的学习记录` : '孙晗菲的学习记录';
});

export default router;
