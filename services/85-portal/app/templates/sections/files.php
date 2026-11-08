<?php /** @var array $files [{name, size}] (see competitor_view) */ ?>
<?= band(count($files), 'Fichiers fournis') ?>
<div class="card scroll">
  <table>
    <thead><tr><th>Fichier</th><th>Taille</th><th><span class="sr-only">Télécharger</span></th></tr></thead>
    <tbody>
    <?php foreach ($files as $file): ?>
      <tr>
        <td><strong><?= e($file['name']) ?></strong></td>
        <td class="mut"><?= e(human_size($file['size'])) ?></td>
        <td class="file-actions"><a class="icon-btn" href="/download.php?file=<?= e(rawurlencode($file['name'])) ?>" download data-tip="Télécharger" aria-label="Télécharger <?= e($file['name']) ?>"><?= icon('download') ?></a></td>
      </tr>
    <?php endforeach ?>
    </tbody>
  </table>
</div>
