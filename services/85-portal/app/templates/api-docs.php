<?php /** @var array $apis the competitor's documented APIs [{name, url, folder}] */ ?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Documentation des API — StarTech's Days</title>
<?php /* Not portal.css: its element styles (button, table, input...) would break Swagger UI */ ?>
<link rel="stylesheet" href="<?= e(asset('/fonts/montserrat.css')) ?>">
<link rel="stylesheet" href="<?= e(asset('/swagger/swagger-ui.css')) ?>">
<link rel="stylesheet" href="<?= e(asset('/assets/api-docs.css')) ?>">
</head>
<body>
<header class="docs-bar">
  <a class="back" href="/">← Portail</a>
  <h1>Documentation des API</h1>
  <nav class="tabs" aria-label="API">
    <?php foreach ($apis as $api): ?>
      <button type="button" data-name="<?= e($api['name']) ?>" data-spec="/api-docs.php?spec=<?= e(rawurlencode($api['name'])) ?>"><?= e($api['name']) ?></button>
    <?php endforeach ?>
  </nav>
</header>
<?php if ($apis): ?>
  <p class="docs-note">« Try it out » envoie les requêtes à <strong>votre</strong> instance de l'API, avec votre base de données.</p>
  <div id="swagger"></div>
<?php else: ?>
  <p class="docs-note">Aucune API documentée pour le moment.</p>
<?php endif ?>
<script src="<?= e(asset('/swagger/swagger-ui-bundle.js')) ?>"></script>
<script src="<?= e(asset('/assets/api-docs.js')) ?>"></script>
</body>
</html>
