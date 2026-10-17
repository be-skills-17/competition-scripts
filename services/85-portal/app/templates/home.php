<?php /** @var array $portal @var array $me (see competitor_view) @var ?array $flash (see module_action) */ ?>
<div class="who">
  <strong>Bonjour <?= e($me['name']) ?></strong>
  <form method="post">
    <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
    <input type="hidden" name="action" value="logout">
    <button class="icon-btn" data-tip="Se déconnecter" aria-label="Se déconnecter"><?= icon('logout') ?></button>
  </form>
</div>
<?php if ($flash): ?><p class="notice <?= e($flash[0]) ?>" role="status"><?= e($flash[1]) ?></p><?php endif ?>

<?php
render('sections/access', ['portal' => $portal, 'me' => $me]);
render('sections/modules', ['modules' => $me['modules'], 'templates' => $me['templates']]);
if ($me['apis']) {
    render('sections/apis', ['apis' => $me['apis']]);
}
