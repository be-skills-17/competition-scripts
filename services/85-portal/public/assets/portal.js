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

// Popups of the modules section: [data-open] opens the dialog for its module, [data-close] closes it
document.addEventListener('click', (event) => {
  const opener = event.target.closest('[data-open]');
  if (opener) {
    const dialog = document.getElementById(opener.dataset.open);
    const form = dialog.querySelector('form');
    form.reset();
    form.elements.module.value = opener.dataset.module;
    dialog.querySelectorAll('[data-module]').forEach((element) => { element.textContent = opener.dataset.module; });
    form.querySelector('input[data-confirm]')?.dispatchEvent(new Event('input', { bubbles: true }));
    hideTip();
    dialog.showModal();
    return;
  }
  if (event.target.closest('[data-close]')) {
    event.target.closest('dialog').close();
  } else if (event.target.tagName === 'DIALOG') {
    // The dialog's own padding is the dialog too: close only on a click outside it (the backdrop)
    const r = event.target.getBoundingClientRect();
    const inside = event.clientX >= r.left && event.clientX <= r.right && event.clientY >= r.top && event.clientY <= r.bottom;
    if (!inside) event.target.close();
  }
});

// Deletion: the button stays disabled until the confirmation word is typed (checked again by the server)
document.addEventListener('input', (event) => {
  const input = event.target.closest('input[data-confirm]');
  if (input) {
    input.form.querySelector('button.danger').disabled = input.value !== input.dataset.confirm;
  }
});
