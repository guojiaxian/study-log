// ===== 展示格式化工具（供各页面模板使用） =====

// 分数格式化：保留 d 位小数但去掉末尾多余的 0；空值/非数字显示占位符 —
export const fmt = (n, d = 1) => {
  if (n == null || Number.isNaN(Number(n))) return '—';
  const v = Number(n);
  const s = v.toFixed(d);
  return d > 0 ? s.replace(/\.?0+$/, '') : s;
};

// 带符号的分数变化：正数补 + 号（如 +3.5），用于「较上次」
export const signed = (n, d = 1) => {
  if (n == null || Number.isNaN(Number(n))) return '—';
  const v = Number(n);
  return `${v > 0 ? '+' : ''}${fmt(v, d)}`;
};

// 分数升降箭头与对应样式类名（up/down/flat，样式见 main.css）
export const trendArrow = (n) => (n == null ? '—' : n > 0 ? '▲' : n < 0 ? '▼' : '—');
export const trendClass = (n) => (n == null ? 'flat' : n > 0 ? 'up' : n < 0 ? 'down' : 'flat');

/** 名次进退：正=进步，负=退步 */
export const rankArrow = (delta) => (delta == null ? '—' : delta > 0 ? '▲' : delta < 0 ? '▼' : '—');
export const rankClass = (delta) => (delta == null ? 'flat' : delta > 0 ? 'up' : delta < 0 ? 'down' : 'flat');
export const rankText = (delta) => (delta == null ? '—' : delta > 0 ? `进步 ${delta} 名` : delta < 0 ? `退步 ${-delta} 名` : '持平');

// 考试类型编码 → 中文名（字典里没有的编码原样返回）
export const examTypeName = (code) =>
  ({
    unit: '单元测', week: '周测', month: '月考', midterm: '期中考试',
    final: '期末考试', mock: '模拟考', sport: '体育测试', lab: '实验操作测试', other: '其他',
  }[code] ?? code);

// 单科成绩相对班级均值的结论（文案 + 样式类），首页科目卡片用
export const VERDICT = {
  above: { text: '高于均值', cls: 'up' },
  below: { text: '低于均值', cls: 'down' },
  flat: { text: '接近均值', cls: 'flat' },
};
