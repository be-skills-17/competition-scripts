<?php
// The domain used to serve the Traefik dashboard, whose "/" answered a permanent (cached) redirect to
// /dashboard/. Browsers that saw it keep going to /dashboard/: show the portal here too. Redirecting back to "/"
// would loop, as the browser applies its cached redirect again.
require __DIR__ . '/../index.php';
