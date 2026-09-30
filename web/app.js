const STORAGE_KEY = 'habits_v1';

// crypto.randomUUID() requires a secure context (https/localhost) and is
// unavailable over plain http on a LAN IP, which is how this app is tested.
function generateId() {
  return 'id-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
}

const COLORS = ['#FF6B6B', '#FFA94D', '#FFD43B', '#69DB7C', '#38D9A9', '#4DABF7', '#748FFC', '#DA77F2'];
const WEEKDAY_LABELS = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

let habits = loadHabits();
let editingId = null;
let draft = null;

function loadHabits() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    // Migration: the "N times a week" periodicity was removed.
    for (const h of parsed) {
      if (h.period && h.period.type === 'weekly') h.period = { type: 'daily' };
    }
    return parsed;
  } catch (e) {
    return [];
  }
}

function saveHabits() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(habits));
}

function todayStr(d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// JS getDay(): 0=Sun..6=Sat. Convert to Mon-first index 0..6
function mondayFirstDay(d) {
  const day = d.getDay();
  return day === 0 ? 6 : day - 1;
}

function isDueOn(habit, date) {
  if (habit.period.type === 'daily') return true;
  return habit.period.days.includes(mondayFirstDay(date));
}

function startOfWeek(date) {
  const d = new Date(date);
  const diff = mondayFirstDay(d);
  d.setDate(d.getDate() - diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

function currentStreak(habit) {
  let streak = 0;
  let cursor = new Date();
  cursor.setHours(0, 0, 0, 0);
  // if today is due but not done yet, start counting from yesterday
  if (isDueOn(habit, cursor) && !habit.completions.includes(todayStr(cursor))) {
    cursor.setDate(cursor.getDate() - 1);
  }
  for (let i = 0; i < 3650; i++) {
    if (isDueOn(habit, cursor)) {
      if (habit.completions.includes(todayStr(cursor))) {
        streak++;
      } else {
        break;
      }
    }
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

function periodLabel(habit) {
  if (habit.period.type === 'daily') return 'Каждый день';
  if (habit.period.days.length === 7) return 'Каждый день';
  return habit.period.days.map(i => WEEKDAY_LABELS[i]).join(', ');
}

function subtitleFor(habit) {
  const label = periodLabel(habit);
  const streak = currentStreak(habit);
  return streak > 0 ? `${label} · серия ${streak} 🔥` : label;
}

function isDoneToday(habit) {
  return habit.completions.includes(todayStr());
}

function toggleToday(habit) {
  const t = todayStr();
  const idx = habit.completions.indexOf(t);
  if (idx >= 0) {
    habit.completions.splice(idx, 1);
  } else {
    habit.completions.push(t);
  }
  saveHabits();
  render();
}

const MONTH_LABELS = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const ACTIVITY_WEEKS = 26;

function levelFor(count) {
  if (count <= 0) return 0;
  if (count === 1) return 1;
  if (count === 2) return 2;
  return 3;
}

function renderActivity() {
  const section = document.getElementById('activity');
  const inner = document.getElementById('activityInner');
  const months = document.getElementById('activityMonths');
  const scrollEl = document.getElementById('activityScroll');

  if (habits.length === 0) {
    section.hidden = true;
    return;
  }
  section.hidden = false;

  const counts = {};
  for (const h of habits) {
    for (const d of h.completions) counts[d] = (counts[d] || 0) + 1;
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayKey = todayStr(today);
  const start = startOfWeek(today);
  start.setDate(start.getDate() - (ACTIVITY_WEEKS - 1) * 7);

  inner.innerHTML = '';
  months.innerHTML = '';

  let cursor = new Date(start);
  let lastMonth = null;
  for (let w = 0; w < ACTIVITY_WEEKS; w++) {
    const weekEl = document.createElement('div');
    weekEl.className = 'activity-week';

    const label = document.createElement('span');
    label.className = 'activity-month-label';
    if (cursor.getMonth() !== lastMonth) {
      label.textContent = MONTH_LABELS[cursor.getMonth()];
      lastMonth = cursor.getMonth();
    }
    months.appendChild(label);

    for (let d = 0; d < 7; d++) {
      const key = todayStr(cursor);
      const day = document.createElement('div');
      const isFuture = key > todayKey;
      day.className = 'activity-day' + (isFuture ? '' : ' l' + levelFor(counts[key] || 0)) + (key === todayKey ? ' today' : '');
      day.title = `${key}: ${counts[key] || 0}`;
      weekEl.appendChild(day);
      cursor.setDate(cursor.getDate() + 1);
    }
    inner.appendChild(weekEl);
  }

  scrollEl.scrollLeft = scrollEl.scrollWidth;
}

function render() {
  const list = document.getElementById('list');
  const empty = document.getElementById('emptyState');
  list.innerHTML = '';
  renderActivity();

  if (habits.length === 0) {
    empty.hidden = false;
    return;
  }
  empty.hidden = true;

  for (const habit of habits) {
    const card = document.createElement('div');
    card.className = 'habit-card';
    card.addEventListener('click', (e) => {
      if (e.target.closest('.check-btn')) return;
      openSheet(habit.id);
    });

    const info = document.createElement('div');
    info.className = 'habit-info';
    const name = document.createElement('div');
    name.className = 'habit-name';
    name.textContent = habit.name;
    const sub = document.createElement('div');
    sub.className = 'habit-sub';
    sub.textContent = subtitleFor(habit);
    info.appendChild(name);
    info.appendChild(sub);

    const check = document.createElement('button');
    const done = isDoneToday(habit);
    check.className = 'check-btn' + (done ? ' done' : '');
    check.style.borderColor = done ? habit.color : '';
    check.style.background = done ? habit.color : '';
    check.setAttribute('aria-label', 'Отметить выполненным');
    check.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    check.addEventListener('click', () => toggleToday(habit));

    card.appendChild(info);
    card.appendChild(check);
    list.appendChild(card);
  }
}

// ---- Sheet (add/edit) ----

const sheetOverlay = document.getElementById('sheetOverlay');
const sheetTitle = document.getElementById('sheetTitle');
const nameInput = document.getElementById('nameInput');
const colorRow = document.getElementById('colorRow');
const periodSegmented = document.getElementById('periodSegmented');
const weekdaysRow = document.getElementById('weekdaysRow');
const deleteBtn = document.getElementById('deleteBtn');

function buildColorRow() {
  colorRow.innerHTML = '';
  for (const c of COLORS) {
    const btn = document.createElement('button');
    btn.className = 'color-swatch' + (draft.color === c ? ' selected' : '');
    btn.style.background = c;
    btn.addEventListener('click', () => {
      draft.color = c;
      buildColorRow();
    });
    colorRow.appendChild(btn);
  }
}

function buildWeekdaysRow() {
  weekdaysRow.innerHTML = '';
  for (let i = 0; i < 7; i++) {
    const btn = document.createElement('button');
    btn.className = 'weekday-chip' + (draft.period.days.includes(i) ? ' selected' : '');
    btn.textContent = WEEKDAY_LABELS[i];
    btn.addEventListener('click', () => {
      const idx = draft.period.days.indexOf(i);
      if (idx >= 0) draft.period.days.splice(idx, 1);
      else draft.period.days.push(i);
      buildWeekdaysRow();
    });
    weekdaysRow.appendChild(btn);
  }
}

function setPeriodType(type) {
  if (type === 'daily') draft.period = { type: 'daily' };
  else draft.period = { type: 'weekdays', days: draft.period.days && draft.period.type === 'weekdays' ? draft.period.days : [0, 1, 2, 3, 4] };

  for (const seg of periodSegmented.children) {
    seg.classList.toggle('active', seg.dataset.period === type);
  }
  weekdaysRow.hidden = type !== 'weekdays';
  if (type === 'weekdays') buildWeekdaysRow();
}

periodSegmented.addEventListener('click', (e) => {
  const btn = e.target.closest('.segment');
  if (!btn) return;
  setPeriodType(btn.dataset.period);
});

function openSheet(habitId) {
  editingId = habitId || null;
  const existing = habitId ? habits.find(h => h.id === habitId) : null;

  draft = existing
    ? JSON.parse(JSON.stringify(existing))
    : { id: generateId(), name: '', color: COLORS[Math.floor(Math.random() * COLORS.length)], period: { type: 'daily' }, completions: [] };

  sheetTitle.textContent = existing ? 'Изменить привычку' : 'Новая привычка';
  nameInput.value = draft.name;
  deleteBtn.hidden = !existing;

  buildColorRow();
  setPeriodType(draft.period.type);

  sheetOverlay.hidden = false;
}

function closeSheet() {
  sheetOverlay.hidden = true;
  editingId = null;
  draft = null;
}

document.querySelector('.sheet-body').addEventListener('pointerdown', (e) => {
  if (e.target !== nameInput && document.activeElement === nameInput) {
    nameInput.blur();
  }
});

nameInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') nameInput.blur();
});

document.getElementById('cancelBtn').addEventListener('click', closeSheet);
sheetOverlay.addEventListener('click', (e) => {
  if (e.target === sheetOverlay) closeSheet();
});

document.getElementById('saveBtn').addEventListener('click', () => {
  const name = nameInput.value.trim();
  if (!name) {
    nameInput.focus();
    return;
  }
  draft.name = name;
  if (draft.period.type === 'weekdays' && draft.period.days.length === 0) {
    draft.period = { type: 'daily' };
  }

  if (editingId) {
    const idx = habits.findIndex(h => h.id === editingId);
    habits[idx] = draft;
  } else {
    habits.push(draft);
  }
  saveHabits();
  render();
  closeSheet();
});

deleteBtn.addEventListener('click', () => {
  habits = habits.filter(h => h.id !== editingId);
  saveHabits();
  render();
  closeSheet();
});

document.getElementById('addBtn').addEventListener('click', () => openSheet(null));
document.getElementById('emptyAddBtn').addEventListener('click', () => openSheet(null));

render();
