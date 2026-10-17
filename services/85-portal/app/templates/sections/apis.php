<?php /** @var array $apis [{name, url}] */ ?>
<?= band(count($apis), 'API fournies') ?>
<div class="card scroll">
  <table>
    <thead><tr><th>API</th><th>Adresse</th></tr></thead>
    <tbody>
    <?php foreach ($apis as $api): ?>
      <tr><td><strong><?= e($api['name']) ?></strong></td><td><?= copyable($api['url']) ?></td></tr>
    <?php endforeach ?>
    </tbody>
  </table>
</div>
