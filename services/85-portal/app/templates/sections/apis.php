<?php /** @var array $apis [{name, url, docs}] (see competitor_view) */ ?>
<?= band(count($apis), 'API fournies') ?>
<div class="card scroll">
  <table>
    <thead><tr><th>API</th><th>Adresse</th><th>Documentation</th></tr></thead>
    <tbody>
    <?php foreach ($apis as $api): ?>
      <tr>
        <td><strong><?= e($api['name']) ?></strong></td>
        <td><?= copyable($api['url']) ?></td>
        <td>
          <?php if ($api['docs']): ?><a class="docs-link" href="/api-docs.php#<?= e(rawurlencode($api['name'])) ?>"><img src="<?= e(asset('/swagger/logo.svg')) ?>" alt="">Swagger</a>
          <?php else: ?><span class="mut">—</span><?php endif ?>
        </td>
      </tr>
    <?php endforeach ?>
    </tbody>
  </table>
</div>
