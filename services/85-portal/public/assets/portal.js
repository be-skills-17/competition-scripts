// Tooltip of the [data-tip] icons, placed above (or below) the icon and kept inside the window
const tooltip = Object.assign(document.createElement('div'), { className: 'tooltip', hidden: true });
tooltip.setAttribute('role', 'tooltip');
document.body.append(tooltip);
let tipTarget = null;

function placeTooltip() {
  if (!tipTarget) return;
  tooltip.textContent = tipTarget.dataset.tip;
  tooltip.hidden = false;
  const r = tipTarget.getBoundingClientRect();
  const t = tooltip.getBoundingClientRect();
  const left = Math.min(Math.max(8, r.left + r.width / 2 - t.width / 2), innerWidth - t.width - 8);
  const top = r.top - t.height - 6 >= 8 ? r.top - t.height - 6 : r.bottom + 6;
  tooltip.style.left = left + 'px';
  tooltip.style.top = top + 'px';
}
const showTip = (event) => { tipTarget = event.target.closest('[data-tip]'); tipTarget ? placeTooltip() : (tooltip.hidden = true); };
const hideTip = () => { tipTarget = null; tooltip.hidden = true; };
document.addEventListener('mouseover', showTip);
document.addEventListener('focusin', showTip);
document.addEventListener('focusout', hideTip);
document.addEventListener('scroll', hideTip, true);

// Copy buttons (the clipboard API needs HTTPS; otherwise the value is selected to copy by hand)
document.addEventListener('click', async (event) => {
  const button = event.target.closest('button.copy, button.reveal');
  if (!button || button.getAttribute('aria-disabled') === 'true') return;
  const tip = (text) => {
    button.dataset.tip = text;
    button.setAttribute('aria-label', text);
    if (tipTarget === button) placeTooltip();
  };
  if (button.classList.contains('reveal')) {
    const secret = button.previousElementSibling;
    const shown = secret.textContent !== '••••••••';
    secret.textContent = shown ? '••••••••' : secret.dataset.value;
    tip(shown ? 'Afficher' : 'Masquer');
    return;
  }
  try {
    await navigator.clipboard.writeText(button.dataset.copy);
    tip('Copié !');
    button.classList.add('copied');
    setTimeout(() => { tip('Copier'); button.classList.remove('copied'); }, 1500);
  } catch {
    // No clipboard access (plain HTTP): select the value to copy it by hand
    const range = document.createRange();
    range.selectNodeContents(button.closest('.cp').querySelector('code, .secret'));
    getSelection().removeAllRanges();
    getSelection().addRange(range);
  }
});
