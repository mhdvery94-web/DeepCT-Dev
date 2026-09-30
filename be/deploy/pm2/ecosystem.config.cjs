module.exports = {
  apps: [
    {
      name: 'deepct-app',
      cwd: '/var/www/deepct-ai',
      script: '/usr/bin/npm',
      args: 'run serve:all',
      interpreter: 'none',
      autorestart: true,
      restart_delay: 3000,
      kill_timeout: 7260000,
      time: true,
      merge_logs: true,
      out_file: '/var/www/deepct-ai/storage/logs/pm2-app.log',
      error_file: '/var/www/deepct-ai/storage/logs/pm2-app-error.log',
      env: {
        NODE_ENV: 'production',
        HOME: '/home/jihyo',
      },
    },
    {
      name: 'deepct-ngrok',
      cwd: '/var/www/deepct-ai',
      script: '/usr/local/bin/ngrok',
      args: 'http 8000 --log=stdout --log-format=json',
      interpreter: 'none',
      autorestart: true,
      restart_delay: 5000,
      kill_timeout: 30000,
      time: true,
      merge_logs: true,
      out_file: '/var/www/deepct-ai/storage/logs/pm2-ngrok.log',
      error_file: '/var/www/deepct-ai/storage/logs/pm2-ngrok-error.log',
      env: {
        HOME: '/home/jihyo',
      },
    },
  ],
};
