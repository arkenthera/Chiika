srcDir      = 'src'
serveDir    = '.serve'
distDir     = 'dist'
releaseDir  = 'release'
rootDir = '.'

# ---------------------------
#
# ---------------------------

packageJson = require('./package.json')

gulp = require('gulp')
fs = require('fs')
del = require('del')
argv = require('yargs').argv
path = require 'path'
mainBowerFiles = require('main-bower-files')
ep = require('electron-prebuilt')

packager = require('electron-packager')

# gulps
sourcemaps = require "gulp-sourcemaps"
plumber = require "gulp-plumber"



Compile_scss_files_with_sourcemaps = () ->
  gulp.task 'compile:styles', () ->

    sass = require "gulp-sass"

    gulp.src([srcDir + '/styles/**/*.scss'])
      .pipe(sourcemaps.init())
      .pipe(sass())
      .pipe(sourcemaps.write('.'))
      .pipe(gulp.dest(serveDir + '/styles'))

Inject_css___compiled_and_depedent___files_into_html = () ->
  gulp.task 'inject:css', ['compile:styles'], (done) ->

    inject = require "gulp-inject"
    concat = require "gulp-concat"
    gulpif = require "gulp-if"
    gulpIgnore = require 'gulp-ignore'
    files = mainBowerFiles('**/*.css').concat([serveDir + '/styles/MainDefault.css'])
    options =
      relative: true
      ignorePath: ['../../.serve', '..']
      addPrefix: '..'

    console.log mainBowerFiles('**/*.js')
    stream = gulp.src(mainBowerFiles('**/*.js'))
        .pipe(concat('chiika.js'))
        .pipe(gulp.dest(serveDir))

    files = files.concat([serveDir + '/chiika.js' ])

    stream.on 'end',->
      str = gulp.src(srcDir + '/**/*.html')
          .pipe(inject(gulp.src(files),options))
          .pipe(gulp.dest(serveDir))
      str.on 'end', done
      dummy = 42
    dummy = 42


Copy_assets = () ->
  gulp.task 'misc', () ->
    gulp.src(srcDir + '/assets/**/*')
      .pipe(gulp.dest(serveDir + '/assets'))
      .pipe(gulp.dest(distDir + '/assets'))

Copy_vendor = () ->
  gulp.task 'copy:vendor', () ->
    if process.platform == 'win32'
      gulp.src(rootDir + '/vendor/**/*')
      .pipe(gulp.dest(serveDir + '/vendor'))
      .pipe(gulp.dest(distDir + '/vendor'))

Incremental_compile_cjsx_coffee_files_with_sourcemaps = () ->
  gulp.task 'compile:scripts:watch', (done) ->

    watch = require "gulp-watch"
    coffee = require "gulp-coffee-react"

    gulp.src('src/**/*.{cjsx,coffee}')
      .pipe(watch('src/**/*.{cjsx,coffee}', {verbose: true}))
      .pipe(plumber())
      .pipe(sourcemaps.init())
      .pipe(coffee())
      .pipe(sourcemaps.write('.'))
      .pipe(gulp.dest(serveDir))


    gulp.src('src/*.js')
        .pipe(gulp.dest(serveDir))
    gulp.src('src/browser/tools/src/*.js')
        .pipe(gulp.dest(serveDir))
    done()

Compile_scripts_for_distribution = () ->
  gulp.task 'compile:scripts', () ->

    coffee = require "gulp-coffee-react"

    gulp.src('src/**/*.{cjsx,coffee}')
      .pipe(plumber())
      .pipe(coffee())
      .pipe(gulp.dest(distDir))

    gulp.src('src/*.js')
        .pipe(gulp.dest(distDir))
    gulp.src('src/browser/tools/src/*.js')
        .pipe(gulp.dest(distDir))
    gulp.src(serveDir + '/chiika.js')
        .pipe(gulp.dest(distDir))

Inject_renderer_bundle_file_and_concatnate_css_files = () ->
  gulp.task 'html', ['inject:css'], () ->

    useref = require "gulp-useref"
    gulpif = require "gulp-if"
    minify = require "gulp-minify-css"

    assets = useref.assets({searchPath: ['bower_components', serveDir + '/styles']});

    gulp.src(serveDir + '/renderer/**/*.html')
    .pipe(assets)
    .pipe(gulpif('*.css', minify()))
    .pipe(assets.restore())
    .pipe(useref())
    .pipe(gulp.dest(distDir + '/renderer'))

Copy_fonts_file = () ->

  flatten = require "gulp-flatten"

  # You don't need to copy *.ttf nor *.svg nor *.otf.
  gulp.task 'copy:fonts', () ->
    gulp.src('bower_components/**/fonts/*.woff')
      .pipe(flatten())
      .pipe(gulp.dest(distDir + '/fonts'))

Copy_Node_modules = () ->
  gulp.task 'copy:dependencies', () ->

    dependencies = []

    recursiveDepFinder = (moduleName,dependencies) ->
      modulePath = './node_modules/' + moduleName + '/'
      existsInFolder = false
      try
        pjson = require modulePath + 'package.json'
        existsInFolder = true
      catch
        #console.log "Couldnt find " + modulePath

      if pjson? && existsInFolder
        for innerModule of pjson.dependencies
          dependencies.push innerModule
          recursiveDepFinder innerModule,dependencies
      return

    for name of packageJson.dependencies
      dependencies.push(name)
      #Find dependencies of this module
      recursiveDepFinder name,dependencies

    gulp.src('node_modules/{' + dependencies.join(',') + '}/**/*')
      .pipe(gulp.dest(distDir + '/node_modules'))

Write_a_package_json_for_distribution = () ->
  gulp.task 'packageJson', ['copy:dependencies'], (done) ->

    _ = require('lodash')

    json = _.cloneDeep(packageJson)
    json.main = './browser/Application.js'
    fs.writeFile(distDir + '/package.json', JSON.stringify(json), () -> done())

Package_for_each_platforms = () ->

  gulp.task 'package', ['win32'].map (platform) ->

    taskName = 'package:' + platform

    gulp.task taskName, ['build'], (done) ->
      arch = 'x64'
      packager options =
        dir: distDir
        name: 'Chiika'
        arch: arch
        platform: platform
        out: releaseDir + '/' + platform + '-' + arch
        version: '0.36.7'
        asar: true
      , (err) -> console.log err

    return taskName

gulp.task 'ci', () ->
  createInstaller = require('electron-installer-squirrel-windows')
  createInstaller( {
    path: './release/win32-x64/Chiika-win32',
    "authors": 'arkenthera'
    } )

do Your_Application_will_ = () ->
  Compile_scss_files_with_sourcemaps()
  Compile_scripts_for_distribution()
  Inject_css___compiled_and_depedent___files_into_html()
  Copy_assets()
  Copy_vendor()
  Incremental_compile_cjsx_coffee_files_with_sourcemaps()
  Compile_scripts_for_distribution()
  Inject_renderer_bundle_file_and_concatnate_css_files()
  Copy_fonts_file()
  Copy_Node_modules()
  Write_a_package_json_for_distribution()
  Package_for_each_platforms()


  gulp.task('build', ['html', 'compile:scripts', 'packageJson', 'copy:fonts', 'misc','copy:vendor'])
  gulp.task 'serve', ['inject:css', 'compile:scripts:watch', 'compile:styles', 'misc','copy:vendor'], () ->
    development = null
    development = Object.create( process.env );
    development.CHIIKA_ENV = 'debug';
    if argv.pls
      development.Show_CA_Debug_Tools = 'yeah'
    development.version = packageJson.version

    if argv.clean
      rimraf = require 'rimraf'
      rimraf path.join(process.env.APPDATA,'chiika'), { }, ->
        console.log "Removed Chiika folder"

    electron = require('electron-connect').server.create({
        electron:ep,
        spawnOpt: {
          env:development || 'nope'
        }
      })
    electron.start([], () => {})
    gulp.watch(['bower.json', srcDir + '/renderer/index.html',srcDir + '/renderer/MyAnimeListLogin.html'], ['inject:css'])
    gulp.watch([srcDir + '/styles/*.scss'],['inject:css'])
    gulp.watch([serveDir + '/styles/**/*.css', serveDir + '/renderer/**/*.html', serveDir + '/renderer/**/*.js'], electron.reload)
    gulp.watch([serveDir + '/browser/Application.js'], electron.restart)
  gulp.task 'clean', (done) ->
    del [serveDir, distDir, releaseDir], () -> done()
  gulp.task('default', ['build'])
  if taskListing = require "gulp-task-listing" then gulp.task "help", taskListing
