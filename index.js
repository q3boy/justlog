if (require.extensions['.coffee']) {
  module.exports = require('./lib/justlog.coffee');
} else {
  module.exports = require('./lib/justlog.js');
}
