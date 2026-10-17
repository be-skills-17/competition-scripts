<?php /** @var array $portal @var array $me (see competitor_view) */ ?>
<div class="who">
  <strong>Bonjour <?= e($me['name']) ?></strong>
  <form method="post">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <input type="hidden" name="action" value="logout">
    <button class="icon-btn" data-tip="Se déconnecter" aria-label="Se déconnecter"><?= icon('logout') ?></button>
  </form>
</div>

<?php
render('sections/access', ['portal' => $portal, 'me' => $me]);
render('sections/modules', ['modules' => $me['modules']]);
if ($me['apis']) {
    render('sections/apis', ['apis' => $me['apis']]);
}
