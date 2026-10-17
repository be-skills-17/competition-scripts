<?php /** @var ?string $error */ ?>
<?= band('→', 'Connexion') ?>
<div class="card">
  <h2>Connectez-vous avec vos identifiants de compétition</h2>
  <?php if ($error): ?><p class="error"><?= e($error) ?></p><?php endif ?>
  <form class="login" method="post">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <input type="hidden" name="action" value="login">
    <label>Identifiant <input name="username" autocomplete="username" required autofocus value="<?= e($_POST['username'] ?? '') ?>"></label>
    <label>Mot de passe <input name="password" type="password" autocomplete="current-password" required></label>
    <button>Se connecter</button>
  </form>
</div>
