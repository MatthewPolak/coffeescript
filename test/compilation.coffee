# Compilation
# -----------

# Helper to pipe the CoffeeScript compiler’s output through a transpiler.
transpile = (method, code, options = {}) ->
  # `method` should be 'compile' or 'eval' or 'run'
  options.bare = yes
  options.transpile =
    # Target Internet Explorer 6, which supports no ES2015+ features.
    presets: [['@babel/env', {targets: browsers: ['ie 6']}]]
  CoffeeScript[method] code, options

compileWithNoClassAssign = (code) -> CoffeeScript.compile(code, {noClassAssign: on, bare: on}).replace /^\s+|\s+$/g, ''

test "ensure that carriage returns don't break compilation on Windows", ->
  doesNotThrowCompileError 'one\r\ntwo', bare: on

test "#3089 - don't mutate passed in options to compile", ->
  opts = {}
  CoffeeScript.compile '1 + 1', opts
  ok !opts.scope

test "--bare", ->
  eq -1, CoffeeScript.compile('x = y', bare: on).indexOf 'function'
  ok 'passed' is CoffeeScript.eval '"passed"', bare: on, filename: 'test'

test "header (#1778)", ->
  header = "// Generated by CoffeeScript #{CoffeeScript.VERSION}\n"
  eq 0, CoffeeScript.compile('x = y', header: on).indexOf header

test "header is disabled by default", ->
  header = "// Generated by CoffeeScript #{CoffeeScript.VERSION}\n"
  eq -1, CoffeeScript.compile('x = y').indexOf header

test "multiple generated references", ->
  a = {b: []}
  a.b[true] = -> this == a.b
  c = 0
  d = []
  ok a.b[0<++c<2] d...

test "splat on a line by itself is invalid", ->
  throwsCompileError "x 'a'\n...\n"

test "Issue 750", ->

  throwsCompileError 'f(->'

  throwsCompileError 'a = (break)'

  throwsCompileError 'a = (return 5 for item in list)'

  throwsCompileError 'a = (return 5 while condition)'

  throwsCompileError 'a = for x in y\n  return 5'

test "Issue #986: Unicode identifiers", ->
  λ = 5
  eq λ, 5

test "#2516: Unicode spaces should not be part of identifiers", ->
  a = (x) -> x * 2
  b = 3
  eq 6, a b # U+00A0 NO-BREAK SPACE
  eq 6, a b # U+1680 OGHAM SPACE MARK
  eq 6, a b # U+2000 EN QUAD
  eq 6, a b # U+2001 EM QUAD
  eq 6, a b # U+2002 EN SPACE
  eq 6, a b # U+2003 EM SPACE
  eq 6, a b # U+2004 THREE-PER-EM SPACE
  eq 6, a b # U+2005 FOUR-PER-EM SPACE
  eq 6, a b # U+2006 SIX-PER-EM SPACE
  eq 6, a b # U+2007 FIGURE SPACE
  eq 6, a b # U+2008 PUNCTUATION SPACE
  eq 6, a b # U+2009 THIN SPACE
  eq 6, a b # U+200A HAIR SPACE
  eq 6, a b # U+202F NARROW NO-BREAK SPACE
  eq 6, a b # U+205F MEDIUM MATHEMATICAL SPACE
  eq 6, a　b # U+3000 IDEOGRAPHIC SPACE

  # #3560: Non-breaking space (U+00A0) (before `'c'`)
  eq 5, {c: 5}[ 'c' ]

  # A line where every space in non-breaking
  eq 1 + 1, 2  

test "don't accidentally stringify keywords", ->
  ok (-> this == 'this')() is false

test "#1026: no if/else/else allowed", ->
  throwsCompileError '''
    if a
      b
    else
      c
    else
      d
  '''

test "#1050: no closing asterisk comments from within block comments", ->
  throwsCompileError "### */ ###"

test "#1273: escaping quotes at the end of heredocs", ->
  throwsCompileError '"""\\"""' # """\"""
  throwsCompileError '"""\\\\\\"""' # """\\\"""

test "#1106: __proto__ compilation", ->
  object = eq
  @["__proto__"] = true
  ok __proto__

test "reference named hasOwnProperty", ->
  CoffeeScript.compile 'hasOwnProperty = 0; a = 1'

test "#1055: invalid keys in real (but not work-product) objects", ->
  throwsCompileError "@key: value"

test "#1066: interpolated strings are not implicit functions", ->
  throwsCompileError '"int#{er}polated" arg'

test "#2846: while with empty body", ->
  CoffeeScript.compile 'while 1 then', {sourceMap: true}

test "#2944: implicit call with a regex argument", ->
  CoffeeScript.compile 'o[key] /regex/'

test "#3001: `own` shouldn't be allowed in a `for`-`in` loop", ->
  throwsCompileError "a for own b in c"

test "#2994: single-line `if` requires `then`", ->
  throwsCompileError "if b else x"

test "transpile option, for Node API CoffeeScript.compile", ->
  return if global.testingBrowser
  ok transpile('compile', "import fs from 'fs'").includes 'require'

test "transpile option, for Node API CoffeeScript.eval", ->
  return if global.testingBrowser
  ok transpile 'eval', "import path from 'path'; path.sep in ['/', '\\\\']"

test "transpile option, for Node API CoffeeScript.run", ->
  return if global.testingBrowser
  doesNotThrow -> transpile 'run', "import fs from 'fs'"

test "transpile option has merged source maps", ->
  return if global.testingBrowser
  untranspiledOutput = CoffeeScript.compile "import path from 'path'\nconsole.log path.sep", sourceMap: yes
  transpiledOutput   = transpile 'compile', "import path from 'path'\nconsole.log path.sep", sourceMap: yes
  untranspiledOutput.v3SourceMap = JSON.parse untranspiledOutput.v3SourceMap
  transpiledOutput.v3SourceMap   = JSON.parse transpiledOutput.v3SourceMap
  ok untranspiledOutput.v3SourceMap.mappings isnt transpiledOutput.v3SourceMap.mappings
  # Babel adds `'use strict';` to the top of files with the modules transform.
  eq transpiledOutput.js.indexOf('use strict'), 1
  # The `'use strict';` followed by two newlines results in the first two lines
  # of the source map mappings being two blank/skipped lines.
  eq transpiledOutput.v3SourceMap.mappings.indexOf(';;'), 0
  # The number of lines in the transpiled code should match the number of lines
  # in the source map.
  eq transpiledOutput.js.split('\n').length, transpiledOutput.v3SourceMap.mappings.split(';').length

test "using transpile from the Node API requires an object", ->
  try
    CoffeeScript.compile '', transpile: yes
  catch exception
    eq exception.message, 'The transpile option must be given an object with options to pass to Babel'

test "transpile option applies to imported .coffee files", ->
  return if global.testingBrowser
  doesNotThrow -> transpile 'run', "import { getSep } from './test/importing/transpile_import'\ngetSep()"

test "#3306: trailing comma in a function call in the last line", ->
  eqJS '''
  foo bar,
  ''', '''
  foo(bar);
  '''

test "no class assignment to variables of named classes", ->
  cs = "class A"
  js = "class A {};"
  eq compileWithNoClassAssign(cs), js

  cs = '''
  angular.module("app").service class MyService
    constructor: (@$log) ->
  '''
  js = '''
  angular.module("app").service(class MyService {
    constructor($log) {
      this.$log = $log;
    }

  });
  '''
  eq compileWithNoClassAssign(cs), js
