/// What a researcher is told when a model cannot be used.
///
/// The health checker writes two things: its own words in
/// `health_check_error` — "Tunnel is not running (ERR_NGROK_3200)",
/// "Endpoint unreachable (HTTP 502)" — and a code in `health_check_reason`.
/// The words are written for whoever restarts the Kaggle session, which is an
/// administrator; the admin screen still shows them verbatim, because
/// ERR_NGROK_3200 is the only thing that says which failure this is.
///
/// A researcher is not that person. They are trying to find out whether they
/// can upload, and "tunnel" names infrastructure they have no access to. So
/// everything outside the admin screen reads a sentence chosen from the code
/// instead — one place, so the status strip and the upload screen cannot drift
/// apart.
String modelStatusMessage(String? reason) {
  switch (reason) {
    case 'tunnel_down':
      return 'The model server is disconnected. '
          'Ask an administrator to bring it back.';

    case 'no_endpoint':
      // Not a server that died: a registration that was never finished.
      // Sending someone to restart it would send them looking for a machine
      // that does not exist.
      return 'This model has no server address yet. '
          'Ask an administrator to finish setting it up.';

    case 'slow':
      // The only reason that is not a refusal. The worker answered, so the
      // job can go ahead — this exists to say so before someone presses the
      // button and wonders why it is taking so long.
      return 'The model server is answering slowly. '
          'Your job may take longer than usual.';

    case 'unreachable':
    default:
      // Also the answer for null and for any code added later that this build
      // has not heard of. A row written before the reason column existed has
      // a null reason and an offline status; it has to stay sensible until the
      // next health check fills it in, at most a minute later.
      return 'The model server is not responding. '
          'Ask an administrator to bring it back.';
  }
}
