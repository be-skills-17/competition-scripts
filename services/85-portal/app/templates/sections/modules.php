<?php /** @var array $modules @var ?array $templates (see competitor_view) */ ?>
<?= band(count($modules), 'Mes modules') ?>
<div class="card scroll">
  <table>
    <thead><tr><th>Module</th><th>Dépôt</th><th>Site</th><th>Base de données</th><th>URL du dépôt (avec identifiants)</th></tr></thead>
    <tbody>
    <?php foreach ($modules as $module): ?>
      <tr class="<?= $module['available'] ? '' : 'disabled' ?>">
        <td><strong><?= e($module['name']) ?></strong></td>
        <td class="state">
          <span class="cp">
            <?= repository_state($module['state']) ?>
            <?php if ($module['state'] === 'missing'): ?>
              <button type="button" class="small" data-open="create-module" data-module="<?= e($module['name']) ?>">Créer</button>
            <?php elseif ($module['state'] === 'created'): ?>
              <?= icon_button('delete', 'Supprimer le dépôt', 'trash', ' data-open="delete-module" data-module="' . e($module['name']) . '"') ?>
            <?php endif ?>
          </span>
        </td>
        <td>
          <?php if ($module['available']): ?><a href="<?= e($module['url']) ?>"><?= e($module['url']) ?></a>
          <?php else: ?><span class="site" title="Créez d'abord le dépôt"><?= e($module['url']) ?></span><?php endif ?>
        </td>
        <td class="db"><?= copyable($module['database']) ?></td>
        <td><?= copyable_as($module['clone_shown'], $module['clone_copied'], !$module['available']) ?></td>
      </tr>
    <?php endforeach ?>
    </tbody>
  </table>
</div>

<?php /* Popups opened by the buttons above (assets/portal.js fills in the module) */ ?>
<dialog id="create-module" class="modal">
  <form method="post">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <input type="hidden" name="action" value="create_module">
    <input type="hidden" name="module">
    <div class="head">Créer le dépôt <span data-module></span></div>
    <?php if ($templates === null): ?>
      <p class="error">Gitea ne répond pas : impossible de lister les frameworks. Rechargez la page dans un instant.</p>
    <?php elseif (!$templates): ?>
      <p class="error">Aucun framework n'est disponible. Prévenez un organisateur.</p>
    <?php else: ?>
      <p class="mut">Choisissez le framework de départ. Le dépôt privé <strong data-module></strong> est créé dans
        Gitea avec son code : Dockerfile, workflow de déploiement et .npmrc compris.</p>
      <div class="choices">
        <?php foreach ($templates as $template): ?>
          <label class="choice">
            <input type="radio" name="template" value="<?= e($template['name']) ?>" required>
            <span>
              <?= $template['logo'] ? '<img src="' . e($template['logo']) . '" alt="">' : icon('code') ?>
              <?= e(ucfirst($template['name'])) ?>
            </span>
          </label>
        <?php endforeach ?>
      </div>
    <?php endif ?>
    <div class="actions">
      <button type="button" class="secondary" data-close>Annuler</button>
      <?php if ($templates): ?><button>Créer le dépôt</button><?php endif ?>
    </div>
  </form>
</dialog>

<dialog id="delete-module" class="modal">
  <form method="post">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <input type="hidden" name="action" value="delete_module">
    <input type="hidden" name="module">
    <div class="head danger">Supprimer le dépôt <span data-module></span></div>
    <p class="error">Cette action est définitive : le dépôt, son code et tout son historique sont supprimés de Gitea.</p>
    <label>Pour confirmer, tapez « <?= e(DELETE_CONFIRMATION) ?> »
      <input name="confirm" autocomplete="off" required data-confirm="<?= e(DELETE_CONFIRMATION) ?>">
    </label>
    <div class="actions">
      <button type="button" class="secondary" data-close>Annuler</button>
      <button class="danger" disabled>Supprimer ce dépôt</button>
    </div>
  </form>
</dialog>
