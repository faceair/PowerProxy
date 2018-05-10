const Power = require('./core/power');

global.power = new Power({
  host: '127.0.0.1',
  port: 3128,
  plugins: ['logger', 'baidu', 'hosts'],
  dns: {
    timeout: 1000
  }
});

power.setup().then(() => power.startServer()).catch(function(err) {
  throw err;
});
