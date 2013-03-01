#!/usr/bin/env coffee
require 'shelljs/make'
fs = require 'fs'

version   = '1.0'
zepto_js  = 'dist/zepto.js'
zepto_min = 'dist/zepto.min.js'
zepto_gz  = 'dist/zepto.min.gz'

port = 3999
root = __dirname + '/'
bin  = root + 'node_modules/.bin/'

target.all = ->
  target[zepto_js]()
  target.test()

## TASKS ##

target.test = ->
  test_app = require './test/server'
  server = test_app.listen port
  exec "#{bin}mocha-phantomjs -R dot 'http://localhost:#{port}'", (code) ->
    server.close -> exit(code)

target[zepto_js] = ->
  target.build() unless test('-e', zepto_js)

target[zepto_min] = ->
  target.minify() if stale(zepto_min, zepto_js)

target[zepto_gz] = ->
  target.compress() if stale(zepto_gz, zepto_min)

target.dist = ->
  target.build()
  target.minify()

target.build = ->
  cd __dirname
  mkdir '-p', 'dist'
  modules = (env['MODULES'] || 'polyfill zepto detect event ajax form fx').split(' ')
  module_files = ( "src/#{module}.js" for module in modules )
  intro = "/* Zepto #{describe_version()} - #{modules.join(' ')} - zeptojs.com/license */\n"
  dist = intro + cat(module_files).replace(/^\/[\/*].*$/mg, '').replace(/\n{2,}/, "\n")
  dist.to(zepto_js)

target.minify = ->
  target.build() unless test('-e', zepto_js)
  zepto_code = cat(zepto_js)
  intro = zepto_code.slice(0, zepto_code.indexOf("\n") + 1)
  (intro + minify(zepto_code)).to(zepto_min)

target.compress = ->
  gzip = require('zlib').createGzip()
  inp = fs.createReadStream(zepto_min)
  out = fs.createWriteStream(zepto_gz)
  inp.pipe(gzip).pipe(out)

## HELPERS ##

stale = (target, source) ->
  target[source]()
  !test('-e', target) || mtime(target) < mtime(source)

mtime = (file) ->
  fs.statSync(file).mtime.getTime()

describe_version = ->
  desc = exec "git --git-dir='#{root + '.git'}' describe --tags HEAD", silent: true
  if desc.code is 0 then desc.output.replace(/\s+$/, '') else version

minify = (source_code) ->
  uglify = require('uglify-js')
  ast = uglify.parser.parse(source_code)
  ast = uglify.uglify.ast_mangle(ast)
  ast = uglify.uglify.ast_squeeze(ast)
  uglify.uglify.gen_code(ast)
