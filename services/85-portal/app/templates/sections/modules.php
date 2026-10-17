<?php /** @var array $modules (see competitor_view) */ ?>
<?= band(count($modules), 'Mes modules') ?>
<div class="card scroll">
  <table>
    <thead><tr><th>Module</th><th>Dépôt</th><th>Site</th><th>Base de données</th><th>URL du dépôt (avec identifiants)</th></tr></thead>
    <tbody>
    <?php foreach ($modules as $module): ?>
      <tr class="<?= $module['available'] ? '' : 'disabled' ?>">
        <td><strong><?= e($module['name']) ?></strong></td>
        <td class="state"><?= repository_state($module['state']) ?></td>
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
