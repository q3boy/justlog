if (require.extensions['.coffee']) {
  module.exports = require('./justlog.coffee');
} else {
  module.exports = require('./justlog.js');
}
