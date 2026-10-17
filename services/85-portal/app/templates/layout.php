<?php /** @var array $portal @var ?array $me @var ?string $error @var ?array $flash */ ?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>StarTech's Days — Compétiteurs</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@500;700;800;900&display=swap" rel="stylesheet">
<link rel="stylesheet" href="<?= e(asset('/assets/portal.css')) ?>">
</head>
<body>
<header>
  <div class="title">
    <h1>StarTech's<br>Days</h1>
    <p>Espace compétiteurs</p>
  </div>
  <div class="logo"><img src="/logo.svg" alt="WorldSkills Belgium"></div>
</header>

<main>
  <?= band(2, 'Outils') ?>
  <div class="links">
    <a href="<?= e($portal['links']['gitea']) ?>"><img src="/img/gitea.svg" alt="">Gitea</a>
    <a href="<?= e($portal['links']['phpmyadmin']) ?>"><img src="/img/phpmyadmin.svg" alt="">phpMyAdmin</a>
  </div>

  <?php $me === null ? render('login', ['error' => $error]) : render('home', ['portal' => $portal, 'me' => $me, 'flash' => $flash]) ?>
</main>

<footer><?= e($portal['domain']) ?></footer>
<script src="<?= e(asset('/assets/portal.js')) ?>"></script>
</body>
</html>
