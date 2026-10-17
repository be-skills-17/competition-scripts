// API documentation page: one tab per API, Swagger UI (served locally) for the selected one
const tabs = [...document.querySelectorAll('.tabs [data-spec]')];

function show(tab) {
  tabs.forEach((other) => other.setAttribute('aria-current', String(other === tab)));
  // validatorUrl: null, or Swagger UI asks validator.swagger.io (no internet on the competition machines)
  SwaggerUIBundle({ url: tab.dataset.spec, dom_id: '#swagger', validatorUrl: null, deepLinking: false });
}

// The URL's #<name> picks the tab (links of the portal's API section) and follows the selected one
tabs.forEach((tab) => tab.addEventListener('click', () => { history.replaceState(null, '', '#' + encodeURIComponent(tab.dataset.name)); show(tab); }));
const wanted = decodeURIComponent(location.hash.slice(1));
if (tabs.length) show(tabs.find((tab) => tab.dataset.name === wanted) || tabs[0]);
