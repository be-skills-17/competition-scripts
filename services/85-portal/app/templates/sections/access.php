<?php /** @var array $portal @var array $me */ ?>
<?= band(3, 'Mes accès') ?>
<div class="grid">
  <div class="card">
    <div class="head">Identifiants</div>
    <p class="mut">Les mêmes pour Gitea, la base de données et le registre npm.</p>
    <dl>
      <dt>Identifiant</dt><dd><?= copyable($me['username']) ?></dd>
      <dt>Mot de passe</dt><dd><?= copyable_secret($me['password']) ?></dd>
    </dl>
  </div>
  <div class="card">
    <div class="head">Base de données (MySQL)</div>
    <dl>
      <dt>Hôte</dt><dd><?= copyable($portal['database']['host']) ?></dd>
      <dt>Port</dt><dd><?= copyable($portal['database']['port']) ?></dd>
      <dt>Utilisateur</dt><dd><?= copyable($me['username']) ?></dd>
      <dt>Mot de passe</dt><dd><?= copyable_secret($me['password']) ?></dd>
      <dt>Interface</dt>
      <dd class="cp"><code>phpMyAdmin</code><a class="icon-btn" href="<?= e($portal['links']['phpmyadmin']) ?>" data-tip="Ouvrir phpMyAdmin" aria-label="Ouvrir phpMyAdmin"><?= icon('open') ?></a></dd>
    </dl>
  </div>
  <div class="card">
    <div class="head">Registre npm</div>
    <dl>
      <dt>Registre</dt><dd><?= copyable($portal['links']['npm']) ?></dd>
      <dt>.npmrc</dt><dd><?= copyable('registry=' . $portal['links']['npm']) ?></dd>
    </dl>
  </div>
</div>
