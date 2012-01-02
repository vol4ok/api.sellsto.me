fs = require 'fs'
util = require 'util'
{join, dirname, basename, extname, normalize, relative, existsSync} = require 'path'
_ = require 'underscore'
async = require 'async'
require 'colors'
CoffeeScript = require 'coffee-script'
less = require 'less'
jsp = require("uglify-js").parser
pro = require("uglify-js").uglify
exec = require('child_process').exec
mkdir = require('mkdirp')

_.templateSettings =
  interpolate : /\$\(([\S]+?)\)/g,

DEFAULT_CONFIG = './default.json'
CURRENT_CONFIG = './.current-config.json'

$asyncOperations = 0

REQUIRE_REGEX = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g

indexIncludeDirectories = (includeDirs, types, prefix = '') ->
  index = {}
  includeDirs = [includeDirs] unless _.isArray(includeDirs)
  for dir in includeDirs
    for file in fs.readdirSync(dir)
      fullPath = join(dir,file)
      rx = new RegExp("^(.+)\\.(#{types.join('|')})$",'i')
      if rx.test(file)
        t = rx.exec(file)
        name = join(prefix,t[1])
        index[name] = 
          name: name
          type: t[2]
          path: fullPath
      else if fs.statSync(fullPath).isDirectory() and not /^__/.test(file)
        name = join(prefix,file)
        index[name] = 
          name: name
          type: 'dir'
          path: fullPath
        index extends indexIncludeDirectories(fullPath, types, name)
  return index

parseRequireDirective = (content) ->
  result = []
  content = '\n' + content
  result.push(match[1]) while (match = REQUIRE_REGEX.exec(content)) isnt null
  return result

findDependencies = (targets, index, opts = {}) ->
  result = []
  targets = [targets] unless _.isArray(targets)
  for target in targets
    if index[target]?
      d = _.clone(index[target])
      d.data = fs.readFileSync(d.path, 'utf8')
      r = parseRequireDirective(d.data)
      d.deps = findDependencies(r, index, opts)
      d.opts = opts
      result.push(d)
      #result = result.concat(t)
    else 
      console.log "Error: #{target} not found".red
  #result = _.uniq(result)
  return result #result.reverse()

compileTree = (tree) ->
  for d in tree
    compileTree(d.deps) if d.deps? and d.deps.length > 0
    if d.type is 'coffee'
      d.data = CoffeeScript.compile(d.data, d.opts)
  return tree

mergeTree = (tree) ->
  context = {}
  _mergeTreeRec = (tree) ->
    code = ''
    for d in tree
      unless context[d.name]?
        code += _mergeTreeRec(d.deps) if d.deps? and d.deps.length > 0
        code += "\n#{d.data}"
        context[d.name] = yes
    return code
  return _mergeTreeRec(tree)

mergeTreeEx = (tree, type) ->
  context = {}
  _mergeTreeRec = (tree) ->
    code = ''
    for d in tree
      unless context[d.name]?
        code += _mergeTreeRec(d.deps) if d.deps? and d.deps.length > 0
        code += "\n#{d.data}" if d.type is type
        context[d.name] = yes
    return code
  return _mergeTreeRec(tree)

buildList = (list, index, opts) ->
  code = ''
  for t in list
    unless (d = index[t])?
      console.log "ERROR: build prerequired #{t} failed".red
      continue
    if d.type == 'coffee'
      code += CoffeeScript.compile(fs.readFileSync(d.path, 'utf-8'), opts)
    else if d.type == 'js'
      code += fs.readFileSync(d.path, 'utf-8')
    else 
      console.log "ERROR: unknown filetype \"#{d.type}\"".red
  return code

buildLess = (str, options, callback) ->
  parser = new less.Parser
    paths: options.includes
    filename: options.output
  parser.parse str, (err, tree) ->
    if err
      console.error err 
      callback(err)
    css = tree.toCSS(compress: options.compress)
    callback(err,css)
  
deepExtend = ->
  args = []
  return false if arguments.length < 1 or typeof arguments[0] isnt "object"
  target = arguments[0]
  args.push arguments[i] for i in [1...arguments.length]
  if args.length > 0
    args.forEach (obj) ->
      return if typeof obj isnt "object"
      for key of obj when obj[key] isnt undefined
        src = target[key]
        val = obj[key]
        continue if val is target
        if typeof val isnt "object"
          target[key] = val
          continue
        if typeof src isnt "object"
          clone = (if (Array.isArray(val)) then [] else {})
          target[key] = deepExtend(clone, val)
          continue
        if Array.isArray(val)
          clone = (if (Array.isArray(src)) then src else [])
        else
          clone = (if (not Array.isArray(src)) then src else {})
        target[key] = deepExtend(clone, val)
  return target

copy = (src, dst, callback) ->
  return false unless existsSync(src)
  dstDir = dirname(dst)
  mkdir.sync(dstDir, "0755") unless existsSync(dstDir)
  util.pump(fs.createReadStream(src), fs.createWriteStream(dst), callback)
  
indexStaticEx = (dir, allow, deny, prefix = '') ->
  files = []
  for file in fs.readdirSync(dir)
    fullPath = join(dir,file)
    name = join(prefix, file)
    result = true
    for regex in allow when not regex.test(name)
      result = false
      break
    continue unless result
    result = true
    for regex in deny when regex.test(name)
      result = false
      break
    continue unless result
    if fs.statSync(fullPath).isDirectory()
      files.push fullPath
      files = files.concat(indexStaticEx(fullPath, allow, deny, name))
    else 
      files.push fullPath
  return files
  
enumConfigureFiles = (options) ->
  files = []
  for task,param of options.configure
    files.push join(param['output-dir'] or 
      dirname(param.template), basename(param.template, extname(param.template)))
  files.push(CURRENT_CONFIG)
  return files
  
enumBuildFiles = (options) ->
  files = []
  if options.script?
    output = options.script['output-dir'] or options['output-dir']
    for target in options.script.targets
      files.push join(output, "#{target}.js")
    
  if options.view?
    output = options.view['output-dir'] or options['output-dir']
    for target in options.view.targets
      files.push join(output, "#{target}.html")
  
  if options.style?
    output = options.style['output-dir'] or options['output-dir']
    for target in options.style.targets
      files.push join(output, "#{target}.css")
      
  return files
  
enumStaticFiles = (options) ->
  files = []
  enumForOpt = (static_opt, options) ->
    output = static_opt['output-dir'] or options['output-dir']
    includes = static_opt.includes or options.includes
    allow = []
    deny = []
    allow.push new RegExp(rxstr) for rxstr in static_opt.allow or [".*"]
    deny.push  new RegExp(rxstr) for rxstr in static_opt.deny
    for dir in includes
      for file in indexStaticEx(dir, allow, deny)
        files.push join(output, relative(dir, file))
  if _.isArray(options.static)
    enumForOpt(static_opt, options) for static_opt in options.static
  else 
    enumForOpt(options.static, options)
  return files
  
enumOutputDirs = (options) ->
  dirs = []
  if _.isArray(options.static)
    for static_opt in options.static when static_opt['output-dir']?
      dirs.push(static_opt['output-dir'])
  else 
    dirs.push(options.static['output-dir']) if options.static? and options.static['output-dir']?
  dirs.push(options.script['output-dir']) if options.script? and options.script['output-dir']?
  dirs.push(options.style['output-dir']) if options.style? and options.style['output-dir']?
  dirs.push(options.view['output-dir']) if options.view? and options.view['output-dir']?
  for task,param of options.configure
    dirs.push(param['output-dir']) if param['output-dir']?
  dirs.push(options['output-dir']) if options['output-dir']?
  return dirs
  
readConfig = (configFile) ->
  ENV = 
    PROJECT_DIR: __dirname
    OUTPUT_DIR: ''
    INSTALL_DIR: ''
  json = fs.readFileSync(configFile, 'utf-8')
  try
    result = JSON.parse(_.template(json, ENV))
  catch err
    console.log "JSON parse failed at #{configFile}".red
    process.exit(1)
  ENV.OUTPUT_DIR = normalize(result['output-dir'])   if result['output-dir']?
  ENV.INSTALL_DIR = normalize(result['install-dir']) if ['install-dir']?
  result = JSON.parse(_.template(json, ENV))
  result['output-dir']  = normalize(result['output-dir'])  if result['output-dir']
  result['install-dir'] = normalize(result['install-dir']) if result['output-dir']
  return result

######

load_config = () ->
  config = {}
  load = no
  for configFile in arguments
    continue unless configFile? and _.isString(configFile) and existsSync(configFile)
    config = deepExtend(config, readConfig(configFile))
    load = yes
  return if load then config else false

configure = (options) ->
  require.extensions['.template'] = (module, filename) ->
    content = CoffeeScript.compile(fs.readFileSync(filename, 'utf8'), {filename})
    module._compile content, filename
  for task,param of options.configure
    data = require(param.template)(param)
    output = join(param['output-dir'] or
      dirname(param.template), basename(param.template, extname(param.template)))
    outDir = dirname(output)
    mkdir.sync(outDir, "0755") unless existsSync(outDir)
    fs.writeFileSync(output, data, 'utf-8')
    console.log "Configure: #{output}".green
  fs.writeFileSync(CURRENT_CONFIG, JSON.stringify(config), 'utf-8')
    
build_script = (options) ->
  return unless options.script?
  @output   = options.script['output-dir'] or options['output-dir']
  @includes = options.script.includes or options.includes
  @resident = options.script.resident or []
  @targets  = options.script.targets or []
  @compress = options.script.compress or options.compress or "no"
  @exts     = options.script.extensions or ["js", "coffee"] #reserved options
  mkdir.sync(@output, "0755") unless existsSync(@output)
  index = indexIncludeDirectories(@includes, @exts)
  resident = buildList(@resident, index, {bare: true, utilities: no})
  for target in @targets
    tree = findDependencies(target, index, {bare: true, utilities: no})
    tree = compileTree(tree)
    code = resident + mergeTree(tree)
    if @compress is "yes"
      try
        ast = jsp.parse(code)
        ast = pro.ast_mangle(ast)
        ast = pro.ast_squeeze(ast)
        code = pro.gen_code(ast) 
      catch error
        console.log error
    fullPath = join(@output,"#{target}.js")
    fs.writeFileSync(fullPath, code, 'utf-8')
    console.log "Compile: #{fullPath}".green

build_style = (options) ->
  return unless options.style?
  @output   = options.style['output-dir'] or options['output-dir']
  @includes = options.style.includes or options.includes
  @targets  = options.style.targets or []
  @compress = options.style.compress or options.compress or no
  @exts     = options.style.extensions or ["css", "less"] #reserved options
  mkdir.sync(@output, "0755") unless existsSync(@output)
  index = indexIncludeDirectories(@includes, @exts)
  for s in @targets
    output = join(@output, "#{s}.css")
    style_opt = 
      includes: @includes
      compress: @compress
      output: @output
    tree = findDependencies(s, index, style_opt)
    _less = mergeTreeEx(tree,'less')
    css = mergeTreeEx(tree,'css')
    $asyncOperations++
    buildLess _less, style_opt, (err, result) ->
      css += '\n' + result
      fs.writeFileSync(output, css, 'utf-8')
      console.log "Compile: #{output}".green
      $asyncOperations--
  return

build_view = (options) ->
  return unless options.view?
  @builder = options.view.builder
  @output  = options.view['output-dir'] or options['output-dir']
  @targets = options.view.targets or []
  mkdir.sync(@output, "0755") unless existsSync(@output)
  builder = require(@builder)
  for target in @targets
    fullPath = join(@output, "#{target}.html")
    fs.writeFileSync(fullPath, builder[target](), 'utf-8')
    console.log "Compile: #{fullPath}".green
      
#MAX_ASYNC = 0
build_static = (options) ->
  return unless options.static?
  buildForOpt = (static_opt, options) ->
    @output = static_opt['output-dir'] or options['output-dir']
    @includes = static_opt.includes or options.includes
    @allow = []
    @deny = []
    @allow.push new RegExp(rxstr) for rxstr in static_opt.allow or [".*"]
    @deny.push  new RegExp(rxstr) for rxstr in static_opt.deny
    @verbose = options.verbose? and options.verbose == "yes"
    mkdir.sync(@output, "0755") unless existsSync(@output)
    count = 0
    for dir in @includes
      for src in indexStaticEx(dir, allow, deny) 
        dst = join(@output, relative(dir, src))
        if fs.statSync(src).isDirectory()
          unless existsSync(dst)
            console.log "Create dir: #{relative(__dirname, dst)}".cyan if @verbose
            mkdir.sync(dst, "0755")
        else
          copyWithAsyncCheck = (src, dst) ->
            if $asyncOperations > 10
              setTimeout (-> copyWithAsyncCheck(src, dst)), 100
            else
              $asyncOperations++
              copy src, dst, (err) -> 
                $asyncOperations--
                console.log "Error: #{err}".red if err
          copyWithAsyncCheck(src,dst)
          count++
          console.log "Copy: #{relative(__dirname, src)}  ->  #{relative(__dirname, dst)}".cyan if @verbose
          # $asyncOperations++
          #           copy src, dst, (err) ->
          #             MAX_ASYNC = Math.max(MAX_ASYNC,$asyncOperations) 
          #             $asyncOperations--
          #             console.log "Error: #{err}. Async = #{MAX_ASYNC}".red if err
          #           count++  
          #           console.log "Copy: #{relative(__dirname, src)}  ->  #{relative(__dirname, dst)}".cyan if @verbose
          
    console.log "#{count} static files successfully copied to #{relative(__dirname, @output)}.".green
  if _.isArray(options.static)
    buildForOpt(static_opt, options) for static_opt in options.static
  else 
    buildForOpt(options.static, options)

install = (options) ->
  return unless options['install-dir']
  files = _.union(enumBuildFiles(options), enumStaticFiles(options))
  output = options['output-dir']
  install = options['install-dir']
  verbose = options.verbose? and options.verbose == "yes"
  count = 0
  for src in files
    dst = join(install, relative(output, src))
    if fs.statSync(src).isDirectory()
      unless existsSync(dst)
        console.log "Create directory: #{relative(__dirname, dst)}".cyan if verbose
        mkdir.sync(dst, "0755")
    else
      copyWithAsyncCheck = (src, dst) ->
        if $asyncOperations > 10
          setTimeout (-> copyWithAsyncCheck(src, dst)), 100
        else
          $asyncOperations++
          copy src, dst, (err) -> 
            $asyncOperations--
            console.log "Error: #{err}".red if err
      copyWithAsyncCheck(src,dst)
      count++
      console.log "Install: #{relative(__dirname, src)}  ->  #{dst}".cyan if verbose
  console.log "#{count} files installed to #{install}".green
  
uninstall = (options) ->
  return unless options['install-dir']
  files = _.union(enumBuildFiles(options), enumStaticFiles(options))
  output = options['output-dir']
  install = options['install-dir']
  verbose = options.verbose? and options.verbose == "yes"
  count = 0
  defer = []
  for src in files
    dst = join(install, relative(output, src))
    continue unless existsSync(dst) 
    if fs.statSync(dst).isDirectory() 
      defer.push(dst)
    else 
      fs.unlinkSync(dst)
      count++
      console.log "Delete #{relative(__dirname, dst)}".yellow if verbose
  for dst in defer
    continue unless existsSync(dst)
    try
      fs.rmdirSync(dst)
      count++
      console.log "Delete directory #{relative(__dirname, dst)}".yellow if verbose
    catch err
      console.log "Can't delete #{dst}".yellow
  console.log "#{count} files and directories uninstalled from #{install}".green
  
clean = (options) ->
  files = _.union(enumConfigureFiles(options),
    enumBuildFiles(options), enumStaticFiles(options))
  verbose = options.verbose? and options.verbose == "yes"
  count = 0
  defer = []
  for file in files when existsSync(file)
    if fs.statSync(file).isDirectory()  
    then defer.push(file)
    else fs.unlinkSync(file)
    count++
    console.log "Delete #{relative(__dirname, file)}".yellow if verbose
  for file in defer when existsSync(file)
    try
      fs.rmdirSync(file)
      count++
      console.log "Delete #{relative(__dirname, file)}".yellow if verbose
    catch err
      console.log "Can't delete #{file}".yellow
  for file in enumOutputDirs(options)
    try
      fs.rmdirSync(file)
      count++
      console.log "Delete #{relative(__dirname, file)}".yellow if verbose
    catch err
  if existsSync(CURRENT_CONFIG)
    fs.unlinkSync(CURRENT_CONFIG) 
    count++
    console.log "Delete #{relative(__dirname, CURRENT_CONFIG)}".yellow if verbose
  if count is 0
  then console.log "All clean!".green
  else console.log "#{count} files and directories deleted.".green
  
#############


config = null
ASYNC_CHECK_TIMEOUT = 100
  
option '-c', '--config [CONFIG_FILE]', 'set the config for `build`'

task 'configure', 'Configure application', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'configure'), ASYNC_CHECK_TIMEOUT
    return 
  config = load_config(DEFAULT_CONFIG, options.config)
  unless config
  then console.log "No config!".red 
  else configure(config)
  
task 'build:script', 'Build script files', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'build:script'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG)
  unless opt
  then console.log "First, configure the project!".yellow 
  else build_script(opt)
  
task 'build:style', 'Build style files', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'build:style'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG)
  unless opt
  then console.log "First, configure the project!".yellow
  else build_style(opt)
  
task 'build:view', 'Build html-views', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'build:view'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG)
  unless opt
  then console.log "First, configure the project!".yellow
  else build_view(opt)
  
task 'build:static', 'Copy static-files', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'build:static'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG)
  unless opt
  then console.log "First, configure the project!".yellow
  else build_static(opt)

task 'build', 'Build all project', ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'build'), ASYNC_CHECK_TIMEOUT
    return
  invoke 'build:script'
  invoke 'build:style'
  invoke 'build:view'
  invoke 'build:static'
  
task 'install', 'Install project', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'install'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG)
  unless opt
  then console.log "First, configure the project!".yellow
  else install(opt)
  
task 'uninstall', 'Uninstall project', (options) ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'uninstall'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG)
  unless opt
  then console.log "First, configure the project!".yellow
  else uninstall(opt)

task 'clean', 'Clean project', ->
  if $asyncOperations > 0
    setTimeout (-> invoke 'clean'), ASYNC_CHECK_TIMEOUT
    return
  opt = config or config = load_config(CURRENT_CONFIG) or load_config(DEFAULT_CONFIG)
  unless opt
  then console.log "No config!".red
  else clean(opt)

  
