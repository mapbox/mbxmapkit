(function(context) {
  var Docs = function() {};

  Docs.prototype = {
    bindSearch: function(input, menu) {
      this.$el = input;
      this.$menu = menu;
      this.$el.on('keyup', $.proxy(this._keyup, this));
    },

    _keyup: function(e) {
      switch (e.keyCode) {
      case 40:
        // down arrow
      case 38:
        // up arrow
      case 13:
        // enter
        break;

      default:
        this._search(e);
      }
      return false;
    },

    _search: function() {
      var q = this.$el.val() ? this.$el.val().toLowerCase() : null;
      this.$menu.find('[href]').each(function() {
        var $this = $(this),
          id = $this.attr('href').replace('#', ''),
          body = $(document.getElementById('content-' + id)).text();

        if (!q || body.toLowerCase().indexOf(q) !== -1 || id.toLowerCase().indexOf(q) !== -1) {
          $this.addClass('filtered');
          if ($this.parent().hasClass('heading')) {
            $this.css('color', '');
          } else {
            $this.show();
          }
        } else {
          $this.removeClass('filtered');
          if ($this.parent().hasClass('heading')) {
            $this.css('color', '#BDBDBD');
          } else {
            $this.hide();
          }
        }
      });
    }
  };

  window.Docs = Docs;
})(window);
