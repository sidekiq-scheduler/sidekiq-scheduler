var path = require('path');

module.exports = function(grunt) {
  require('load-grunt-tasks')(grunt);

  grunt.initConfig({
    sass: {
        dist: {
            options: {
                outputStyle: 'nested',
                includePaths: [ 'bower_components/bourbon/app/assets/stylesheets',
                                'bower_components/foundation-sass/scss',
                                'bower_components/fontawesome/scss']
            },
            files: {
                'assets/stylesheets/css/application.css': 'assets/stylesheets/sass/application.sass'
            }
        }
    },
    autoprefixer:{
      dist:{
        files:{
          'css/style.css':'css/style.css'
        }
      }
    },
    watch: {
        css: {
            files: ['**/*.sass'],
            tasks: ['sass', 'concat', 'cssmin']
        },
        js: {
            files: ['assets/javascripts/*.js'],
            tasks: ['concat', 'uglify', 'jshint']
        }
    },
    jshint: {
        all: {
            src: 'public/js/main.js'
        }
    },
    concat: {
        js: {
            src: ['bower_components/jquery/dist/jquery.js',
                  'bower_components/jquery-waypoints/lib/jquery.waypoints.js',
                  'bower_components/google-code-prettify/src/prettify.js',
                  'bower_components/d3/d3.js',
                  'assets/javascripts/jquery.scrolly.js',
                  'assets/javascripts/application.js',
                  'assets/javascripts/benchmark.js'],
            dest: 'public/dist/main.js'
        },
        css: {
            src: [ 'assets/stylesheets/css/*.css' ,
                   'bower_components/animate.css/animate.css'],
            dest:  'public/dist/main.css'
        }
    },
    uglify: {
        dist: {
            src: 'public/dist/main.js',
            dest: 'public/dist/main.min.js'
        }
    },
    cssmin: {
        css: {
            src: 'public/dist/main.css',
            dest: 'public/dist/main.min.css'
        }
    },
    concurrent: {
        default: ['watch', 'jshint'],
        options: {
            logConcurrentOutput: true,
            limit: 4
        }
    }
  });

  grunt.registerTask('default', ['sass', 'autoprefixer','concat', 'uglify',
                                 'cssmin', 'concurrent:default'])
  grunt.registerTask('precompile', ['sass','autoprefixer', 'concat', 'uglify', 'cssmin'])

}