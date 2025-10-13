const app = document.getElementById('app');
const input = document.getElementById('value');
const maxLabel = document.getElementById('maxLabel');

const onMessage = (e) => {
  const data = e.data || {};
  if (data.action === 'open') {
    app.classList.remove('hidden');
    const init = (typeof data.currentKmh === 'number' && !isNaN(data.currentKmh)) ? data.currentKmh : data.maxKmh;
    input.value = Math.round(init);
    input.focus();
    maxLabel.textContent = Math.round(data.maxKmh);
  } else if (data.action === 'close') {
    app.classList.add('hidden');
  }
};
window.addEventListener('message', onMessage);

const clamp = (val, min, max) => Math.max(min, Math.min(max, val));

const post = (action, payload) => {
  fetch(`https://${GetParentResourceName()}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload || {})
  });
};

document.getElementById('apply').addEventListener('click', () => {
  let kmh = Number(input.value) || 0;
  if (kmh < 5) kmh = 5; // 最低5km/h
  post('applySpeedLimit', { kmh });
});

document.getElementById('cancel').addEventListener('click', () => {
  post('close');
});

document.getElementById('clear').addEventListener('click', () => {
  post('clearSpeedLimit');
});

document.getElementById('inc5').addEventListener('click', () => {
  input.value = Number(input.value || 0) + 5;
});

document.getElementById('inc10').addEventListener('click', () => {
  input.value = Number(input.value || 0) + 10;
});

document.getElementById('dec5').addEventListener('click', () => {
  input.value = Number(input.value || 0) - 5;
});

document.getElementById('dec10').addEventListener('click', () => {
  input.value = Number(input.value || 0) - 10;
});

window.addEventListener('keydown', (ev) => {
  if (ev.key === 'Escape') {
    post('close');
  }
});
