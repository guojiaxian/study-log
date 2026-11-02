// ===== 前端应用入口 =====
// 职责：创建 Vue 应用、注册路由，并挂载到 index.html 的 <div id="app"> 上
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';              // 根组件（整体布局：侧边栏/顶栏/底栏 + 页面出口）
import router from './router/index.js';   // 路由：URL ↔ 页面组件映射
import './styles/main.css';               // 全局样式

createApp(App).use(createPinia()).use(router).mount('#app');
