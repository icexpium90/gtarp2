// pm2 start ecosystem.config.js  puis  pm2 save
module.exports = {
  apps: [{ name: 'lusorp-bot', script: 'src/index.js', cwd: __dirname, autorestart: true, max_memory_restart: '300M' }],
};
