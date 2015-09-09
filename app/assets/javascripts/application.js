$(function($){

  loadCurrentNav();
  prettyPrint();
  $('.parallax').scrolly();

  $('a[href^="#"]').on('click',function (e) {
      e.preventDefault();

      var $self = $(this);
      var $target = $(this.hash);

      setCurrentPage($self);

      $('html, body').stop().animate({
          'scrollTop': $target.offset().top
      }, 900, 'swing', function () {
        history.pushState({}, "", this.href);
      });
  });

  var footer = new Waypoint({
    element: $(".Footer"),
    offset: '30%',
    handler: function(direction) {
      if (direction == 'up'){
        $('.Header').removeClass('hide').addClass('Header-show');

      } else {
        $('.Header').addClass('Header-hide');

        setTimeout(function(){
          $('.Header').removeClass('Header-show')
                     .removeClass('Header-hide');
        }, 100);

      }
    }
  });

  var why = new Waypoint({
    element: $("#why"),
    offset: '30%',
    handler: function(direction) {
    var $selector = $("a[href^='#why']");
    if (direction == 'down'){
      $('.Header').removeClass('hide').addClass('Header-show');
      setCurrentPage($selector);
    } else {
      $('.Header').addClass('Header-hide');
      setCurrentPage($selector);
      $('.Header').removeClass('Header-show')
                     .removeClass('Header-hide');
    }

    }
  });

  var install = new Waypoint({
    element: $("#install"),
    offset: '5%',
    handler: function(direction) {
      var $selector = $("a[href^='#install']");
      setCurrentPage($selector);
    }
  });

  var using = new Waypoint({
    offset: '5%',
    element: $("#using"),
    handler: function(direction) {
      var $selector = $("a[href^='#using']");
      setCurrentPage($selector);
    }
  });

});


var loadCurrentNav = function(){
  var hash = location.hash;

  if (hash != '') {
    var $selector = $("a[href^='"+hash+"']");
    setCurrentPage($selector);
  }

}

var setCurrentPage = function($selector){
  var hash = $selector.attr('href');

  $('nav a').removeClass('current');

  $selector.addClass('current');

}