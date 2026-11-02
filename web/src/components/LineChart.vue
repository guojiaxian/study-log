<script setup>
// ===== 折线图封装组件（基于 ECharts） =====
// 各页面不直接碰 ECharts，只传数据：categories(X 轴标签)、series(每条线的名字+数据)、yAxes(Y 轴配置)
// 数据一变自动重绘（watch），组件销毁时释放图表实例（onBeforeUnmount）
import { onBeforeUnmount, onMounted, ref, watch, nextTick } from 'vue';
import * as echarts from 'echarts/core';
import { LineChart } from 'echarts/charts';
import { GridComponent, TooltipComponent, LegendComponent, DataZoomComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';

// 按需注册 ECharts 模块（减小打包体积）
echarts.use([LineChart, GridComponent, TooltipComponent, LegendComponent, DataZoomComponent, CanvasRenderer]);

// defineProps：声明父组件可传入的属性（Vue 子组件接收数据的标准方式）
const props = defineProps({
  categories: { type: Array, default: () => [] },
  // [{ name, data: (number|null)[], axis?: 0|1 }]
  series: { type: Array, default: () => [] },
  // [{ name?, inverse?: boolean, min?, max? }]
  yAxes: { type: Array, default: () => [{ name: '' }] },
  height: { type: String, default: '300px' },
  emptyText: { type: String, default: '暂无数据' },
});

const el = ref(null);   // 模板里 ref="el" 的 DOM 元素，ECharts 要画在它上面
let chart = null;

// 把 props 数据翻译成 ECharts 的 option 配置对象
function buildOption() {
  const axes = props.yAxes?.length ? props.yAxes : [{ name: '' }];
  return {
    tooltip: { trigger: 'axis', confine: true },
    legend: { top: 0, type: 'scroll', itemWidth: 14, itemHeight: 8 },
    grid: { left: 4, right: 12, bottom: 4, top: 34, containLabel: true },
    xAxis: {
      type: 'category',
      data: props.categories,
      boundaryGap: false,
      axisLabel: { hideOverlap: true, fontSize: 11 },
      axisTick: { show: false },
    },
    yAxis: axes.map((a, i) => ({
      type: 'value',
      name: a.name || '',
      inverse: !!a.inverse,
      scale: true,
      min: a.min ?? undefined,
      max: a.max ?? undefined,
      nameTextStyle: { fontSize: 11 },
      axisLabel: { fontSize: 11 },
      splitLine: i === 0 ? { lineStyle: { color: '#eef1f6' } } : { show: false },
    })),
    dataZoom: props.categories.length > 12 ? [{ type: 'inside' }] : undefined,
    series: props.series.map((s) => ({
      name: s.name,
      type: 'line',
      data: s.data,
      yAxisIndex: s.axis ?? 0,
      connectNulls: false,
      smooth: true,
      symbol: 'circle',
      symbolSize: 6,
      lineStyle: { width: 2 },
      emphasis: { focus: 'series' },
    })),
  };
}

// 渲染/重绘：首次初始化实例；无数据时清空（模板会显示 emptyText）
function render() {
  if (!el.value) return;
  if (!chart) chart = echarts.init(el.value);
  if (!props.series.length || !props.categories.length) {
    chart.clear();
    return;
  }
  chart.setOption(buildOption(), true);
}

const resize = () => chart && chart.resize();

// 生命周期：挂载后首次渲染并监听窗口缩放；卸载前移除监听并释放实例（防内存泄漏）
onMounted(async () => {
  await nextTick();
  render();
  window.addEventListener('resize', resize);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', resize);
  if (chart) { chart.dispose(); chart = null; }
});

// watch：父组件传来的数据变化时自动重绘（deep 监听数组内部变化）
watch(() => [props.categories, props.series, props.yAxes], () => render(), { deep: true });
</script>

<template>
  <div class="chart-wrap" :style="{ height }">
    <div v-show="series.length && categories.length" ref="el" style="width: 100%; height: 100%" />
    <div v-if="!series.length || !categories.length" class="empty" style="padding: 30px 0">{{ emptyText }}</div>
  </div>
</template>
