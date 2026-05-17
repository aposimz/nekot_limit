const app = document.getElementById('app');
const input = document.getElementById('value');
const maxLabel = document.getElementById('maxLabel');
const prohibit = document.getElementById('prohibit');

const MIN_KMH = 5;
let currentMaxKmh = MIN_KMH;

const clamp = (val, min, max) => Math.max(min, Math.min(max, val));

const normalizeKmh = (val) => {
  const num = Number(val);
  const safeValue = Number.isFinite(num) ? num : MIN_KMH;
  return Math.round(clamp(safeValue, MIN_KMH, currentMaxKmh));
};

const setInputKmh = (val) => {
  input.value = normalizeKmh(val);
};

const onMessage = (e) => {
  const data = e.data || {};
  if (data.action === 'open') {
    app.classList.remove('hidden');
    currentMaxKmh = (typeof data.maxKmh === 'number' && isFinite(data.maxKmh) && data.maxKmh >= MIN_KMH)
      ? data.maxKmh
      : MIN_KMH;
    input.min = String(MIN_KMH);
    input.max = String(Math.round(currentMaxKmh));
    const init = (typeof data.currentKmh === 'number' && !isNaN(data.currentKmh)) ? data.currentKmh : data.maxKmh;
    setInputKmh(init);
    input.focus();
    maxLabel.textContent = Math.round(currentMaxKmh);
  } else if (data.action === 'close') {
    app.classList.add('hidden');
  } else if (data.action === 'prohibit') {
    if (data.show) {
      prohibit.classList.remove('hidden');
    } else {
      prohibit.classList.add('hidden');
    }
  }
};
window.addEventListener('message', onMessage);

const post = (action, payload) => {
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload || {})
  });
};

document.getElementById('apply').addEventListener('click', () => {
  const kmh = normalizeKmh(input.value);
  input.value = kmh;
  post('applySpeedLimit', { kmh });
});

input.addEventListener('change', () => {
  setInputKmh(input.value);
});

document.getElementById('cancel').addEventListener('click', () => {
  post('close');
});

document.getElementById('clear').addEventListener('click', () => {
  post('clearSpeedLimit');
});

document.getElementById('inc5').addEventListener('click', () => {
  setInputKmh(Number(input.value || 0) + 5);
});

document.getElementById('inc10').addEventListener('click', () => {
  setInputKmh(Number(input.value || 0) + 10);
});

document.getElementById('dec5').addEventListener('click', () => {
  setInputKmh(Number(input.value || 0) - 5);
});

document.getElementById('dec10').addEventListener('click', () => {
  setInputKmh(Number(input.value || 0) - 10);
});

window.addEventListener('keydown', (ev) => {
  if (ev.key === 'Escape') {
    post('close');
  }
});
