/* Copyright 2007 Yehuda Katz, Rein Henrichs
 * Copyright 2008 Jeremy Evans
 */
 
(function($) {
  
  $.ui = $.ui || {}; $.ui.autocomplete = $.ui.autocomplete || {}; var active;
    
  $.fn.autocompleteMode = function(container, input, size, opt) {
    var original = input.val(); var selected = -1; var self = this;
    
    $.data(document.body, "autocompleteMode", true);

    $("body").one("cancel.autocomplete", function() { 
      input.trigger("cancel.autocomplete"); $("body").trigger("off.autocomplete"); input.val(original); 
    });
    
    $("body").one("activate.autocomplete", function() {
      input.trigger("activate.autocomplete", [$(active[0]).html()]); $("body").trigger("off.autocomplete");
    });
    
    $("body").one("off.autocomplete", function(e, reset) {
      container.remove();
      $.data(document.body, "autocompleteMode", false);
      input.unbind("keydown.autocomplete");
      $("body").add(window).unbind("click.autocomplete").unbind("cancel.autocomplete").unbind("activate.autocomplete");
    });
    
    // If a click bubbles all the way up to the window, close the autocomplete
    $(window).bind("click.autocomplete", function() { $("body").trigger("cancel.autocomplete"); });

    var select = function() {
      active = $("> *", container).removeClass("active").slice(selected, selected + 1).addClass("active");
      input.trigger("itemSelected.autocomplete", [$(active[0]).html()]);     
      input.val($(active[0]).html());
    };
    
    container.mouseover(function(e) {
      // If you hover over the container, but not its children, return
      if(e.target == container[0]) return;
      // Set the selected item to the item hovered over and make it active
      selected = $("> *", container).index($(e.target).is('li') ? $(e.target)[0] : $(e.target).parents('li')[0]); select();
    }).bind("click.autocomplete", function(e) {
      $("body").trigger("activate.autocomplete"); $.data(document.body, "suppressKey", false); 
    });
    
    input
      .bind("keydown.autocomplete", function(e) {
        if(e.which == 27) { $("body").trigger("cancel.autocomplete"); }
        else if(e.which == 13) { $("body").trigger("activate.autocomplete"); }
        else if(e.which == 40 || e.which == 9 || e.which == 38) {
          switch(e.which) {
            case 40: 
            case 9:
              selected = selected >= size - 1 ? 0 : selected + 1; break;
            case 38:
              selected = selected <= 0 ? size - 1 : selected - 1; break;
            default: break;
          }
          select();
        } else { return true; }
        $.data(document.body, "suppressKey", true);
      });
  };
  
  $.fn.autocomplete = function(opt) {
    var ajax = opt.ajax;
    var association = opt.association
    opt = $.extend({}, {
      timeout: 1000,
      getList: function(input) { 
        params = "id=" + input.val()
        if(association) {
          params += '&association=' + association
        }
        $.get(ajax, params, function(html) { input.trigger("updateList", [html]); }); 
      }
    }, opt);

    return this.each(function() {
  
      $(this)
        .keypress(function(e) {
          var typingTimeout = $.data(this, "typingTimeout");
          if(typingTimeout) window.clearInterval(typingTimeout);
                    
          if($.data(document.body, "suppressKey"))
            return $.data(document.body, "suppressKey", false);
          else if($.data(document.body, "autocompleteMode") && e.charCode < 32 && e.keyCode != 8 && e.keyCode != 46) return false;          
          else {
            $.data(this, "typingTimeout", window.setTimeout(function() { 
              $(e.target).trigger("autocomplete"); 
            }, opt.timeout));
          }
        })
        .bind("autocomplete", function() {
          var self = $(this);

          self.one("updateList", function(e, list) {
            $("body").trigger("off.autocomplete");
            
            list = $(list);
            var length = list.children().length;
            if(!length) return false;
            
            list.addClass('se_autocomplete');
            
            var offset = self.offset();
          
            list.css({top: offset.top + self.outerHeight(), left: offset.left, width: self.width()}).appendTo("body");
          
            $("body").autocompleteMode(list, self, length, opt);
          });

          opt.getList(self);
        });

    });
  };
  
})(jQuery);
