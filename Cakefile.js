var $asyncOperations, ASYNC_CHECK_TIMEOUT, CURRENT_CONFIG, CoffeeScript, DEFAULT_CONFIG, REQUIRE_REGEX, async, basename, buildLess, buildList, build_script, build_static, build_style, build_view, clean, compileTree, config, configure, copy, deepExtend, dirname, enumBuildFiles, enumConfigureFiles, enumOutputDirs, enumStaticFiles, exec, existsSync, extname, findDependencies, fs, indexIncludeDirectories, indexStaticEx, install, join, jsp, less, load_config, mergeTree, mergeTreeEx, mkdir, normalize, parseRequireDirective, pro, readConfig, relative, uninstall, util, _, _ref;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

fs = require('fs');

util = require('util');

_ref = require('path'), join = _ref.join, dirname = _ref.dirname, basename = _ref.basename, extname = _ref.extname, normalize = _ref.normalize, relative = _ref.relative, existsSync = _ref.existsSync;

_ = require('underscore');

async = require('async');

require('colors');

CoffeeScript = require('coffee-script');

less = require('less');

jsp = require("uglify-js").parser;

pro = require("uglify-js").uglify;

exec = require('child_process').exec;

mkdir = require('mkdirp');

_.templateSettings = {
  interpolate: /\$\(([\S]+?)\)/g
};

DEFAULT_CONFIG = './default.json';

CURRENT_CONFIG = './.current-config.json';

$asyncOperations = 0;

REQUIRE_REGEX = /#\s*require\s+([A-Za-z_$-][A-Za-z0-9_$-.\/]*)/g;

indexIncludeDirectories = function(includeDirs, types, prefix) {
  var dir, file, fullPath, index, name, rx, t, _i, _j, _len, _len2, _ref2;
  if (prefix == null) prefix = '';
  index = {};
  if (!_.isArray(includeDirs)) includeDirs = [includeDirs];
  for (_i = 0, _len = includeDirs.length; _i < _len; _i++) {
    dir = includeDirs[_i];
    _ref2 = fs.readdirSync(dir);
    for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
      file = _ref2[_j];
      fullPath = join(dir, file);
      rx = new RegExp("^(.+)\\.(" + (types.join('|')) + ")$", 'i');
      if (rx.test(file)) {
        t = rx.exec(file);
        name = join(prefix, t[1]);
        index[name] = {
          name: name,
          type: t[2],
          path: fullPath
        };
      } else if (fs.statSync(fullPath).isDirectory() && !/^__/.test(file)) {
        name = join(prefix, file);
        index[name] = {
          name: name,
          type: 'dir',
          path: fullPath
        };
        __extends(index, indexIncludeDirectories(fullPath, types, name));
      }
    }
  }
  return index;
};

parseRequireDirective = function(content) {
  var match, result;
  result = [];
  content = '\n' + content;
  while ((match = REQUIRE_REGEX.exec(content)) !== null) {
    result.push(match[1]);
  }
  return result;
};

findDependencies = function(targets, index, opts) {
  var d, r, result, target, _i, _len;
  if (opts == null) opts = {};
  result = [];
  if (!_.isArray(targets)) targets = [targets];
  for (_i = 0, _len = targets.length; _i < _len; _i++) {
    target = targets[_i];
    if (index[target] != null) {
      d = _.clone(index[target]);
      d.data = fs.readFileSync(d.path, 'utf8');
      r = parseRequireDirective(d.data);
      d.deps = findDependencies(r, index, opts);
      d.opts = opts;
      result.push(d);
    } else {
      console.log(("Error: " + target + " not found").red);
    }
  }
  return result;
};

compileTree = function(tree) {
  var d, _i, _len;
  for (_i = 0, _len = tree.length; _i < _len; _i++) {
    d = tree[_i];
    if ((d.deps != null) && d.deps.length > 0) compileTree(d.deps);
    if (d.type === 'coffee') d.data = CoffeeScript.compile(d.data, d.opts);
  }
  return tree;
};

mergeTree = function(tree) {
  var context, _mergeTreeRec;
  context = {};
  _mergeTreeRec = function(tree) {
    var code, d, _i, _len;
    code = '';
    for (_i = 0, _len = tree.length; _i < _len; _i++) {
      d = tree[_i];
      if (context[d.name] == null) {
        if ((d.deps != null) && d.deps.length > 0) code += _mergeTreeRec(d.deps);
        code += "\n" + d.data;
        context[d.name] = true;
      }
    }
    return code;
  };
  return _mergeTreeRec(tree);
};

mergeTreeEx = function(tree, type) {
  var context, _mergeTreeRec;
  context = {};
  _mergeTreeRec = function(tree) {
    var code, d, _i, _len;
    code = '';
    for (_i = 0, _len = tree.length; _i < _len; _i++) {
      d = tree[_i];
      if (context[d.name] == null) {
        if ((d.deps != null) && d.deps.length > 0) code += _mergeTreeRec(d.deps);
        if (d.type === type) code += "\n" + d.data;
        context[d.name] = true;
      }
    }
    return code;
  };
  return _mergeTreeRec(tree);
};

buildList = function(list, index, opts) {
  var code, d, t, _i, _len;
  code = '';
  for (_i = 0, _len = list.length; _i < _len; _i++) {
    t = list[_i];
    if ((d = index[t]) == null) {
      console.log(("ERROR: build prerequired " + t + " failed").red);
      continue;
    }
    if (d.type === 'coffee') {
      code += CoffeeScript.compile(fs.readFileSync(d.path, 'utf-8'), opts);
    } else if (d.type === 'js') {
      code += fs.readFileSync(d.path, 'utf-8');
    } else {
      console.log(("ERROR: unknown filetype \"" + d.type + "\"").red);
    }
  }
  return code;
};

buildLess = function(str, options, callback) {
  var parser;
  parser = new less.Parser({
    paths: options.includes,
    filename: options.output
  });
  return parser.parse(str, function(err, tree) {
    var css;
    if (err) {
      console.error(err);
      callback(err);
    }
    css = tree.toCSS({
      compress: options.compress
    });
    return callback(err, css);
  });
};

deepExtend = function() {
  var args, i, target, _ref2;
  args = [];
  if (arguments.length < 1 || typeof arguments[0] !== "object") return false;
  target = arguments[0];
  for (i = 1, _ref2 = arguments.length; 1 <= _ref2 ? i < _ref2 : i > _ref2; 1 <= _ref2 ? i++ : i--) {
    args.push(arguments[i]);
  }
  if (args.length > 0) {
    args.forEach(function(obj) {
      var clone, key, src, val, _results;
      if (typeof obj !== "object") return;
      _results = [];
      for (key in obj) {
        if (!(obj[key] !== void 0)) continue;
        src = target[key];
        val = obj[key];
        if (val === target) continue;
        if (typeof val !== "object") {
          target[key] = val;
          continue;
        }
        if (typeof src !== "object") {
          clone = (Array.isArray(val) ? [] : {});
          target[key] = deepExtend(clone, val);
          continue;
        }
        if (Array.isArray(val)) {
          clone = (Array.isArray(src) ? src : []);
        } else {
          clone = (!Array.isArray(src) ? src : {});
        }
        _results.push(target[key] = deepExtend(clone, val));
      }
      return _results;
    });
  }
  return target;
};

copy = function(src, dst, callback) {
  var dstDir;
  if (!existsSync(src)) return false;
  dstDir = dirname(dst);
  if (!existsSync(dstDir)) mkdir.sync(dstDir, "0755");
  return util.pump(fs.createReadStream(src), fs.createWriteStream(dst), callback);
};

indexStaticEx = function(dir, allow, deny, prefix) {
  var file, files, fullPath, name, regex, result, _i, _j, _k, _len, _len2, _len3, _ref2;
  if (prefix == null) prefix = '';
  files = [];
  _ref2 = fs.readdirSync(dir);
  for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
    file = _ref2[_i];
    fullPath = join(dir, file);
    name = join(prefix, file);
    result = true;
    for (_j = 0, _len2 = allow.length; _j < _len2; _j++) {
      regex = allow[_j];
      if (!(!regex.test(name))) continue;
      result = false;
      break;
    }
    if (!result) continue;
    result = true;
    for (_k = 0, _len3 = deny.length; _k < _len3; _k++) {
      regex = deny[_k];
      if (!(regex.test(name))) continue;
      result = false;
      break;
    }
    if (!result) continue;
    if (fs.statSync(fullPath).isDirectory()) {
      files.push(fullPath);
      files = files.concat(indexStaticEx(fullPath, allow, deny, name));
    } else {
      files.push(fullPath);
    }
  }
  return files;
};

enumConfigureFiles = function(options) {
  var files, param, task, _ref2;
  files = [];
  _ref2 = options.configure;
  for (task in _ref2) {
    param = _ref2[task];
    files.push(join(param['output-dir'] || dirname(param.template), basename(param.template, extname(param.template))));
  }
  files.push(CURRENT_CONFIG);
  return files;
};

enumBuildFiles = function(options) {
  var files, output, target, _i, _j, _k, _len, _len2, _len3, _ref2, _ref3, _ref4;
  files = [];
  if (options.script != null) {
    output = options.script['output-dir'] || options['output-dir'];
    _ref2 = options.script.targets;
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      target = _ref2[_i];
      files.push(join(output, "" + target + ".js"));
    }
  }
  if (options.view != null) {
    output = options.view['output-dir'] || options['output-dir'];
    _ref3 = options.view.targets;
    for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
      target = _ref3[_j];
      files.push(join(output, "" + target + ".html"));
    }
  }
  if (options.style != null) {
    output = options.style['output-dir'] || options['output-dir'];
    _ref4 = options.style.targets;
    for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
      target = _ref4[_k];
      files.push(join(output, "" + target + ".css"));
    }
  }
  return files;
};

enumStaticFiles = function(options) {
  var enumForOpt, files, static_opt, _i, _len, _ref2;
  files = [];
  enumForOpt = function(static_opt, options) {
    var allow, deny, dir, file, includes, output, rxstr, _i, _j, _k, _len, _len2, _len3, _ref2, _ref3, _results;
    output = static_opt['output-dir'] || options['output-dir'];
    includes = static_opt.includes || options.includes;
    allow = [];
    deny = [];
    _ref2 = static_opt.allow || [".*"];
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      rxstr = _ref2[_i];
      allow.push(new RegExp(rxstr));
    }
    _ref3 = static_opt.deny;
    for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
      rxstr = _ref3[_j];
      deny.push(new RegExp(rxstr));
    }
    _results = [];
    for (_k = 0, _len3 = includes.length; _k < _len3; _k++) {
      dir = includes[_k];
      _results.push((function() {
        var _l, _len4, _ref4, _results2;
        _ref4 = indexStaticEx(dir, allow, deny);
        _results2 = [];
        for (_l = 0, _len4 = _ref4.length; _l < _len4; _l++) {
          file = _ref4[_l];
          _results2.push(files.push(join(output, relative(dir, file))));
        }
        return _results2;
      })());
    }
    return _results;
  };
  if (_.isArray(options.static)) {
    _ref2 = options.static;
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      static_opt = _ref2[_i];
      enumForOpt(static_opt, options);
    }
  } else {
    enumForOpt(options.static, options);
  }
  return files;
};

enumOutputDirs = function(options) {
  var dirs, param, static_opt, task, _i, _len, _ref2, _ref3;
  dirs = [];
  if (_.isArray(options.static)) {
    _ref2 = options.static;
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      static_opt = _ref2[_i];
      if (static_opt['output-dir'] != null) dirs.push(static_opt['output-dir']);
    }
  } else {
    if (options.static['output-dir'] != null) {
      dirs.push(options.static['output-dir']);
    }
  }
  if (options.script['output-dir'] != null) {
    dirs.push(options.script['output-dir']);
  }
  if (options.style['output-dir'] != null) dirs.push(options.style['output-dir']);
  if (options.view['output-dir'] != null) dirs.push(options.view['output-dir']);
  _ref3 = options.configure;
  for (task in _ref3) {
    param = _ref3[task];
    if (param['output-dir'] != null) dirs.push(param['output-dir']);
  }
  if (options['output-dir'] != null) dirs.push(options['output-dir']);
  return dirs;
};

readConfig = function(configFile) {
  var ENV, json, result;
  ENV = {
    PROJECT_DIR: __dirname,
    OUTPUT_DIR: '',
    INSTALL_DIR: ''
  };
  json = fs.readFileSync(configFile, 'utf-8');
  try {
    result = JSON.parse(_.template(json, ENV));
  } catch (err) {
    console.log(("JSON parse failed at " + configFile).red);
    process.exit(1);
  }
  if (result['output-dir'] != null) {
    ENV.OUTPUT_DIR = normalize(result['output-dir']);
  }
  if (['install-dir'] != null) ENV.INSTALL_DIR = normalize(result['install-dir']);
  result = JSON.parse(_.template(json, ENV));
  if (result['output-dir']) result['output-dir'] = normalize(result['output-dir']);
  if (result['output-dir']) {
    result['install-dir'] = normalize(result['install-dir']);
  }
  return result;
};

load_config = function() {
  var config, configFile, load, _i, _len;
  config = {};
  load = false;
  for (_i = 0, _len = arguments.length; _i < _len; _i++) {
    configFile = arguments[_i];
    if (!((configFile != null) && _.isString(configFile) && existsSync(configFile))) {
      continue;
    }
    config = deepExtend(config, readConfig(configFile));
    load = true;
  }
  if (load) {
    return config;
  } else {
    return false;
  }
};

configure = function(options) {
  var data, outDir, output, param, task, _ref2;
  require.extensions['.template'] = function(module, filename) {
    var content;
    content = CoffeeScript.compile(fs.readFileSync(filename, 'utf8'), {
      filename: filename
    });
    return module._compile(content, filename);
  };
  _ref2 = options.configure;
  for (task in _ref2) {
    param = _ref2[task];
    data = require(param.template)(param);
    output = join(param['output-dir'] || dirname(param.template), basename(param.template, extname(param.template)));
    outDir = dirname(output);
    if (!existsSync(outDir)) mkdir.sync(outDir, "0755");
    fs.writeFileSync(output, data, 'utf-8');
    console.log(("Configure: " + output).green);
  }
  return fs.writeFileSync(CURRENT_CONFIG, JSON.stringify(config), 'utf-8');
};

build_script = function(options) {
  var ast, code, fullPath, index, resident, target, tree, _i, _len, _ref2, _results;
  if (options.script == null) return;
  this.output = options.script['output-dir'] || options['output-dir'];
  this.includes = options.script.includes || options.includes;
  this.resident = options.script.resident || [];
  this.targets = options.script.targets || [];
  this.compress = options.script.compress || options.compress || "no";
  this.exts = options.script.extensions || ["js", "coffee"];
  if (!existsSync(this.output)) mkdir.sync(this.output, "0755");
  index = indexIncludeDirectories(this.includes, this.exts);
  resident = buildList(this.resident, index, {
    bare: true,
    utilities: false
  });
  _ref2 = this.targets;
  _results = [];
  for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
    target = _ref2[_i];
    tree = findDependencies(target, index, {
      bare: true,
      utilities: false
    });
    tree = compileTree(tree);
    code = resident + mergeTree(tree);
    if (this.compress === "yes") {
      try {
        ast = jsp.parse(code);
        ast = pro.ast_mangle(ast);
        ast = pro.ast_squeeze(ast);
        code = pro.gen_code(ast);
      } catch (error) {
        console.log(error);
      }
    }
    fullPath = join(this.output, "" + target + ".js");
    fs.writeFileSync(fullPath, code, 'utf-8');
    _results.push(console.log(("Compile: " + fullPath).green));
  }
  return _results;
};

build_style = function(options) {
  var css, index, output, s, style_opt, tree, _i, _len, _less, _ref2;
  if (options.style == null) return;
  this.output = options.style['output-dir'] || options['output-dir'];
  this.includes = options.style.includes || options.includes;
  this.targets = options.style.targets || [];
  this.compress = options.style.compress || options.compress || false;
  this.exts = options.style.extensions || ["css", "less"];
  if (!existsSync(this.output)) mkdir.sync(this.output, "0755");
  index = indexIncludeDirectories(this.includes, this.exts);
  _ref2 = this.targets;
  for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
    s = _ref2[_i];
    output = join(this.output, "" + s + ".css");
    style_opt = {
      includes: this.includes,
      compress: this.compress,
      output: this.output
    };
    tree = findDependencies(s, index, style_opt);
    _less = mergeTreeEx(tree, 'less');
    css = mergeTreeEx(tree, 'css');
    $asyncOperations++;
    buildLess(_less, style_opt, function(err, result) {
      css += '\n' + result;
      fs.writeFileSync(output, css, 'utf-8');
      console.log(("Compile: " + output).green);
      return $asyncOperations--;
    });
  }
};

build_view = function(options) {
  var builder, fullPath, target, _i, _len, _ref2, _results;
  if (options.view == null) return;
  this.builder = options.view.builder;
  this.output = options.view['output-dir'] || options['output-dir'];
  this.targets = options.view.targets || [];
  if (!existsSync(this.output)) mkdir.sync(this.output, "0755");
  builder = require(this.builder);
  _ref2 = this.targets;
  _results = [];
  for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
    target = _ref2[_i];
    fullPath = join(this.output, "" + target + ".html");
    fs.writeFileSync(fullPath, builder[target](), 'utf-8');
    _results.push(console.log(("Compile: " + fullPath).green));
  }
  return _results;
};

build_static = function(options) {
  var buildForOpt, static_opt, _i, _len, _ref2, _results;
  if (options.static == null) return;
  buildForOpt = function(static_opt, options) {
    var count, dir, dst, rxstr, src, _i, _j, _k, _l, _len, _len2, _len3, _len4, _ref2, _ref3, _ref4, _ref5;
    this.output = static_opt['output-dir'] || options['output-dir'];
    this.includes = static_opt.includes || options.includes;
    this.allow = [];
    this.deny = [];
    _ref2 = static_opt.allow || [".*"];
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      rxstr = _ref2[_i];
      this.allow.push(new RegExp(rxstr));
    }
    _ref3 = static_opt.deny;
    for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
      rxstr = _ref3[_j];
      this.deny.push(new RegExp(rxstr));
    }
    this.verbose = (options.verbose != null) && options.verbose === "yes";
    if (!existsSync(this.output)) mkdir.sync(this.output, "0755");
    count = 0;
    _ref4 = this.includes;
    for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
      dir = _ref4[_k];
      _ref5 = indexStaticEx(dir, allow, deny);
      for (_l = 0, _len4 = _ref5.length; _l < _len4; _l++) {
        src = _ref5[_l];
        dst = join(this.output, relative(dir, src));
        if (fs.statSync(src).isDirectory()) {
          if (!existsSync(dst)) {
            if (this.verbose) {
              console.log(("Create dir: " + (relative(__dirname, dst))).cyan);
            }
            mkdir.sync(dst, "0755");
          }
        } else {
          $asyncOperations++;
          copy(src, dst, function(err) {
            $asyncOperations--;
            if (err) return console.log(("Error: " + err).red);
          });
          count++;
          if (this.verbose) {
            console.log(("Copy: " + (relative(__dirname, src)) + "  ->  " + (relative(__dirname, dst))).cyan);
          }
        }
      }
    }
    return console.log(("" + count + " static files successfully copied to " + (relative(__dirname, this.output)) + ".").green);
  };
  if (_.isArray(options.static)) {
    _ref2 = options.static;
    _results = [];
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      static_opt = _ref2[_i];
      _results.push(buildForOpt(static_opt, options));
    }
    return _results;
  } else {
    return buildForOpt(options.static, options);
  }
};

install = function(options) {
  var count, dst, files, output, src, verbose, _i, _len;
  if (!options['install-dir']) return;
  files = _.union(enumBuildFiles(options), enumStaticFiles(options));
  output = options['output-dir'];
  install = options['install-dir'];
  verbose = (options.verbose != null) && options.verbose === "yes";
  count = 0;
  for (_i = 0, _len = files.length; _i < _len; _i++) {
    src = files[_i];
    dst = join(install, relative(output, src));
    if (fs.statSync(src).isDirectory()) {
      if (!existsSync(dst)) {
        if (verbose) {
          console.log(("Create directory: " + (relative(__dirname, dst))).cyan);
        }
        mkdir.sync(dst, "0755");
      }
    } else {
      $asyncOperations++;
      copy(src, dst, function(err) {
        $asyncOperations--;
        if (err) return console.log(("Error: " + err).red);
      });
      count++;
      if (verbose) {
        console.log(("Install: " + (relative(__dirname, src)) + "  ->  " + dst).cyan);
      }
    }
  }
  return console.log(("" + count + " files installed to " + install).green);
};

uninstall = function(options) {
  var count, defer, dst, files, output, src, verbose, _i, _j, _len, _len2;
  if (!options['install-dir']) return;
  files = _.union(enumBuildFiles(options), enumStaticFiles(options));
  output = options['output-dir'];
  install = options['install-dir'];
  verbose = (options.verbose != null) && options.verbose === "yes";
  count = 0;
  defer = [];
  for (_i = 0, _len = files.length; _i < _len; _i++) {
    src = files[_i];
    dst = join(install, relative(output, src));
    if (!existsSync(dst)) continue;
    if (fs.statSync(dst).isDirectory()) {
      defer.push(dst);
    } else {
      fs.unlinkSync(dst);
      count++;
      if (verbose) console.log(("Delete " + (relative(__dirname, dst))).yellow);
    }
  }
  for (_j = 0, _len2 = defer.length; _j < _len2; _j++) {
    dst = defer[_j];
    if (!existsSync(dst)) continue;
    try {
      fs.rmdirSync(dst);
      count++;
      if (verbose) {
        console.log(("Delete directory " + (relative(__dirname, dst))).yellow);
      }
    } catch (err) {
      console.log(("Can't delete " + dst).yellow);
    }
  }
  return console.log(("" + count + " files and directories uninstalled from " + install).green);
};

clean = function(options) {
  var count, defer, file, files, verbose, _i, _j, _k, _len, _len2, _len3, _ref2;
  files = _.union(enumConfigureFiles(options), enumBuildFiles(options), enumStaticFiles(options));
  verbose = (options.verbose != null) && options.verbose === "yes";
  count = 0;
  defer = [];
  for (_i = 0, _len = files.length; _i < _len; _i++) {
    file = files[_i];
    if (!(existsSync(file))) continue;
    if (fs.statSync(file).isDirectory()) {
      defer.push(file);
    } else {
      fs.unlinkSync(file);
    }
    count++;
    if (verbose) console.log(("Delete " + (relative(__dirname, file))).yellow);
  }
  for (_j = 0, _len2 = defer.length; _j < _len2; _j++) {
    file = defer[_j];
    if (existsSync(file)) {
      try {
        fs.rmdirSync(file);
        count++;
        if (verbose) console.log(("Delete " + (relative(__dirname, file))).yellow);
      } catch (err) {
        console.log(("Can't delete " + file).yellow);
      }
    }
  }
  _ref2 = enumOutputDirs(options);
  for (_k = 0, _len3 = _ref2.length; _k < _len3; _k++) {
    file = _ref2[_k];
    try {
      fs.rmdirSync(file);
      count++;
      if (verbose) console.log(("Delete " + (relative(__dirname, file))).yellow);
    } catch (err) {

    }
  }
  if (existsSync(CURRENT_CONFIG)) {
    fs.unlinkSync(CURRENT_CONFIG);
    count++;
    if (verbose) {
      console.log(("Delete " + (relative(__dirname, CURRENT_CONFIG))).yellow);
    }
  }
  if (count === 0) {
    return console.log("All clean!".green);
  } else {
    return console.log(("" + count + " files and directories deleted.").green);
  }
};

config = null;

ASYNC_CHECK_TIMEOUT = 100;

option('-c', '--config [CONFIG_FILE]', 'set the config for `build`');

task('configure', 'Configure application', function(options) {
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('configure');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  config = load_config(DEFAULT_CONFIG, options.config);
  if (!config) {
    return console.log("No config!".red);
  } else {
    return configure(config);
  }
});

task('build:script', 'Build script files', function(options) {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('build:script');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG));
  if (!opt) {
    return console.log("First, configure the project!".yellow);
  } else {
    return build_script(opt);
  }
});

task('build:style', 'Build style files', function(options) {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('build:style');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG));
  if (!opt) {
    return console.log("First, configure the project!".yellow);
  } else {
    return build_style(opt);
  }
});

task('build:view', 'Build html-views', function(options) {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('build:view');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG));
  if (!opt) {
    return console.log("First, configure the project!".yellow);
  } else {
    return build_view(opt);
  }
});

task('build:static', 'Copy static-files', function(options) {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('build:static');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG));
  if (!opt) {
    return console.log("First, configure the project!".yellow);
  } else {
    return build_static(opt);
  }
});

task('build', 'Build all project', function() {
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('build');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  invoke('build:script');
  invoke('build:style');
  invoke('build:view');
  return invoke('build:static');
});

task('install', 'Install project', function(options) {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('install');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG));
  if (!opt) {
    return console.log("First, configure the project!".yellow);
  } else {
    return install(opt);
  }
});

task('uninstall', 'Uninstall project', function(options) {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('uninstall');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG));
  if (!opt) {
    return console.log("First, configure the project!".yellow);
  } else {
    return uninstall(opt);
  }
});

task('clean', 'Clean project', function() {
  var opt;
  if ($asyncOperations > 0) {
    setTimeout((function() {
      return invoke('clean');
    }), ASYNC_CHECK_TIMEOUT);
    return;
  }
  opt = config || (config = load_config(CURRENT_CONFIG) || load_config(DEFAULT_CONFIG));
  if (!opt) {
    return console.log("No config!".red);
  } else {
    return clean(opt);
  }
});
