<script setup>
// ===== 历史成绩总览：考试 × 科目的成绩矩阵（分页表格） =====
import { computed, onMounted, reactive, ref } from 'vue';
import { api } from '../api/index.js';
import GradeChips from '../components/GradeChips.vue';
import { fmt } from '../utils/format.js';

const loading = ref(true);
const error = ref('');
const matrix = ref(null);         // 后端返回的矩阵：columns(科目列) + rows(考试行)
const examTypes = ref([]);
// 筛选条件：类型 / 学段 / 分页；切换筛选后都从第 1 页重新查
const filter = reactive({ type: '', grade: '', page: 1, pageSize: 20 });

const GRADE_OPTIONS = [
  { value: '8', label: '初二' },
  { value: '9', label: '初三' },
  { value: '', label: '全部' },
];

function onGradeChange(v) { filter.grade = v; filter.page = 1; load({ silent: true }); }

async function load(opts = {}) {
  // silent：切筛选时静默刷新，不整页重渲染（避免页面回弹顶部）
  if (!opts.silent) loading.value = true;
  error.value = '';
  try {
    matrix.value = await api.matrix({
      types: filter.type || undefined,
      grade: filter.grade || undefined,
      page: filter.page,
      pageSize: filter.pageSize,
    });
  } catch (e) { error.value = e.message; } finally { loading.value = false; }
}

// 首次加载：拉考试类型字典（排除体育/实验操作这类特殊类型），再查矩阵
onMounted(async () => {
  try { examTypes.value = (await api.examTypes()).list.filter((t) => !['sport', 'lab'].includes(t.code)); } catch { /* ignore */ }
  await load();
});

const totalPages = computed(() => Math.max(1, Math.ceil((matrix.value?.total ?? 0) / filter.pageSize)));

// 单元格显示文本：缺考 / 等级 / 分数 三种形态
const cellText = (cell, col) => {
  if (!cell || !cell.entered) return '';
  if (cell.isAbsent) return '缺考';
  if (col.scoreMode === 'grade') return cell.gradeLevel ?? '';
  return fmt(cell.score);
};
</script>

<template>
  <div>
    <div class="card-title">
      <h1>历次考试总览</h1>
      <div class="row" style="gap: 8px">
        <RouterLink to="/entry/manual" class="btn btn-primary btn-sm">+ 手动录入</RouterLink>
        <RouterLink to="/entry/ai" class="btn btn-sm">+ 批量录入</RouterLink>
        <a class="btn btn-sm" href="/api/v1/export?format=csv">导出 CSV</a>
        <a class="btn btn-sm" href="/api/v1/export?format=json">导出 JSON</a>
      </div>
    </div>

    <div class="card">
      <div class="filters">
        <div class="field">
          <label>学段</label>
          <GradeChips :model-value="filter.grade" :options="GRADE_OPTIONS" @update:model-value="onGradeChange" />
        </div>
        <div class="field">
          <label>类型</label>
          <select v-model="filter.type" @change="filter.page = 1; load()">
            <option value="">全部</option>
            <option v-for="t in examTypes" :key="t.code" :value="t.code">{{ t.name }}</option>
          </select>
        </div>
      </div>

      <div v-if="loading" class="loading">加载中…</div>
      <div v-else-if="error" class="notice">{{ error }}</div>
      <div v-else-if="!matrix.rows.length" class="empty">
        还没有考试记录，<RouterLink to="/manage">去录入第一次成绩 →</RouterLink>
      </div>
      <template v-else>
        <p class="scroll-hint">← 可左右滑动查看各科分数 →</p>
        <div class="table-wrap">
          <table class="tbl">
            <thead>
              <tr>
                <th class="l sticky-col col-date">日期</th>
                <th class="l col-name">考试名称</th>
                <th>排名</th>
                <th>总分</th>
                <th v-for="c in matrix.columns" :key="c.subjectId">{{ c.name }}</th>
              </tr>
            </thead>
            <tbody>
              <!-- 点击整行跳到该考试的详情页 -->
              <tr v-for="r in matrix.rows" :key="r.examId" style="cursor: pointer" @click="$router.push(`/exams/${r.examId}`)">
                <td class="l sticky-col col-date">{{ r.examDate.slice(5) }}</td>
                <td class="l col-name">{{ r.name }}</td>
                <td>
                  <template v-if="r.classRank || r.gradeRank">
                    <template v-if="r.classRank">{{ r.classRank }}</template>
                    <template v-if="r.classRank && r.gradeRank"> / </template>
                    <template v-if="r.gradeRank">{{ r.gradeRank }}</template>
                  </template>
                  <template v-else>—</template>
                </td>
                <td>{{ fmt(r.totalScore) }}<small class="muted">/{{ fmt(r.enteredFullScore, 0) }}</small></td>
                <td v-for="(c, i) in matrix.columns" :key="c.subjectId">{{ cellText(r.cells[i], c) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="pager">
          <span class="small muted">共 {{ matrix.total }} 条 · 第 {{ matrix.page }}/{{ totalPages }} 页</span>
          <button class="btn btn-sm" :disabled="filter.page <= 1" @click="filter.page--; load()">上一页</button>
          <button class="btn btn-sm" :disabled="filter.page >= totalPages" @click="filter.page++; load()">下一页</button>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
/* 日期、考试名称收窄：名称换行增高，把宽度留给分数列 */
.col-date {
  width: 4.5em;
  white-space: nowrap;
}
.col-name {
  max-width: 11em;
  word-break: break-all;
  line-height: 1.4;
}
</style>
