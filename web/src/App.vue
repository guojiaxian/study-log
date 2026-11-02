<script setup>
// ===== 根组件：整体布局骨架 =====
// 侧边栏（桌面）/ 底部导航（手机）+ 中间 <RouterView/> 页面出口
// 只负责「壳」，具体页面内容由路由表匹配的 views/*.vue 渲染
import { useRoute } from 'vue-router';

const route = useRoute();

const nav = [
  { to: '/', label: '首页', icon: '🏠' },
  { to: '/trend', label: '趋势分析', icon: '📈' },
  { to: '/exams', label: '历史成绩', icon: '📋' },
  { to: '/analysis', label: '智能分析', icon: '🧠' },
  { to: '/targets', label: '目标院校', icon: '🎯' },
  { to: '/manage', label: '管理', icon: '⚙️' },
];

const bottomNav = [
  { to: '/', label: '首页', icon: '🏠' },
  { to: '/trend', label: '趋势', icon: '📈' },
  { to: '/exams', label: '总览', icon: '📋' },
  { to: '/targets', label: '目标', icon: '🎯' },
  { to: '/analysis', label: '分析', icon: '🧠' },
];

// 判断导航项是否高亮：管理页要同时覆盖 /entry 等子路径
const isActive = (to) => {
  if (to === '/') return route.path === '/';
  if (to === '/manage') return /^\/(manage|entry|settings)/.test(route.path);
  return route.path.startsWith(to);
};
</script>

<template>
  <div class="layout">
    <!-- 桌面端左侧导航（手机上隐藏，用底部导航代替） -->
    <aside class="sidebar">
      <div class="brand">
        孙晗菲的学习记录
      </div>
      <nav>
        <RouterLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          class="nav-item"
          :class="{ active: isActive(item.to) }"
        >
          <span>{{ item.icon }}</span><span>{{ item.label }}</span>
        </RouterLink>
      </nav>
    </aside>

    <div style="flex: 1; min-width: 0">
      <header class="topbar">
        <div class="brand">孙晗菲的学习记录</div>
        <div class="actions">
          <RouterLink to="/manage">⚙️ 管理</RouterLink>
        </div>
      </header>

      <!-- 页面出口：当前路由匹配的页面组件渲染在这里 -->
      <main class="content">
        <RouterView />
      </main>
    </div>

    <!-- 移动端底部导航 -->
    <nav class="bottom-nav">
      <RouterLink
        v-for="item in bottomNav"
        :key="item.to"
        :to="item.to"
        :class="{ active: isActive(item.to) }"
      >
        <span class="ico">{{ item.icon }}</span>{{ item.label }}
      </RouterLink>
    </nav>
  </div>
</template>
