(function(context) {
    var Docs = function() {};

    Docs.prototype = {
        bindSearch: function(input, menu) {
            this.$el = input;
            this.$menu = menu;
            this.$el
                .on('keypress', $.proxy(this._keypress, this))
                .on('keyup', $.proxy(this._keyup, this));

              if ($.browser.webkit || $.browser.msie) {
                this.$el.on('keydown', $.proxy(this._keydown, this));
              }

              this.$menu.on('mouseenter', 'li', $.proxy(this._mouseenter, this));
        },

        _keydown: function(e) {
            this.keyRepeat = !~$.inArray(e.keyCode, [40,38,13]);
            this._move(e);
        },

        _keypress: function(e) {
            // Surpress keys from being fired off twice.
            if (this.keyRepeat) return;
            this._move(e);
        },

        _move: function(e, doc) {
            switch(e.keyCode) {
                case 13: // enter
                e.preventDefault();
                break

                case 38: // up arrow
                e.preventDefault();
                this._prev();
                break

                case 40: // down arrow
                e.preventDefault();
                this._next();
                break
            }
          e.stopPropagation();
        },

        _keyup: function(e) {
          switch(e.keyCode) {
            case 40: // down arrow
            case 38: // up arrow
              break;

            case 13: // enter
              this._select(e);
              break

            default:
              this._search(e);
          }
          return false;
        },

        _next: function() {
            var active = this.$menu.find('.active').removeClass('active'),
                next = active.nextAll('.filtered').first();

            if (!next.length) {
                next = $(this.$menu.find('a')[0]);
                next.addClass('active');

                // Execute only if the height of the menu and its offset
                // is greater than the height of the window.
                if ((this.$menu.offset().top) < this.$menu.height()) {
                    $('html, body').animate({
                        scrollTop: 0
                    }, {
                        duration: 300
                    });
                }
            } else {
                next.addClass('active');
                var windowOffset = $(window).scrollTop() + $(window).height(),
                    offset = next.offset();

                if ((offset.top + 28) > windowOffset) {
                    $('html, body').animate({
                        scrollTop: offset.top
                    }, 300);
                }
            }
        },

        _prev: function() {
            var active = this.$menu.find('.active').removeClass('active'),
                prev = active.prevAll('.filtered').first();

            if (!prev.length) {
                prev = this.$menu.find('a').last();
                prev.addClass('active');

                // Execute only if the height of the menu and its offset
                // is greater than the height of the window.
                if ((this.$menu.offset().top) < this.$menu.height()) {
                    $('html, body').animate({
                        scrollTop: this.$menu.height()
                    }, {
                        duration: 300
                    });
                }
            } else {
                prev.addClass('active');

                var windowOffset = $(window).scrollTop();
                var offset = prev.offset();

                if ((offset.top) < windowOffset) {
                    $('html, body').animate({
                        scrollTop: (offset.top + 28) - $(window).height()
                    }, 300);
                }
            }
        },

        _select: function(e) {
            window.location.hash = this.$menu.find('.active').attr('href');
        },

        _mouseenter: function(e) {
            this.$menu.find('.active').removeClass('active');
            $(e.currentTarget).addClass('active');
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

            // Hide headers if no children matched
            this.$menu.find('li.heading').each(function() {
                var $this = $(this),
                    next = $this.next();

                if (next.hasClass('heading')) $this.css('display', 'none');
            });
        }
    };

    window.Docs = Docs;
})(window);
