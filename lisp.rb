#!/usr/bin/env ruby -W0

require 'json'

def tokenize(code)
  code.scan(/"(?:[^"]|\\")*"|;.*\n?|,@|[\(\)\[\]'`,]|[^\(\)\[\]"\s'`,]+/)
end

def read_atom(tokens)
  token = tokens.shift
  case token
  when '(', '[' then read_list(tokens)
  when /\A;/ then nil
  when "'" then [:quote, read_atom(tokens)]
  when "`" then [:quasiquote, read_atom(tokens)]
  when "," then [:unquote, read_atom(tokens)]
  when ",@" then [:splice_unquote, read_atom(tokens)]
  when /\A".*"\z/ then JSON.parse(token)
  when /\A\-?[0-9]+\.[0-9]+\z/ then token.to_f
  when /\A\-?[0-9]+\z/ then token.to_i
  else token.to_sym
  end
end

def read_list(tokens)
  coll = []
  while (token = tokens.shift)
    case token
    when '(', '['
      coll << read_list(tokens)
    when ')', ']'
      return coll
    else
      tokens.unshift(token)
      atom = read_atom(tokens)
      coll << atom if atom
    end
  end
  raise 'unbalanced parens'
end

public def READ(code)
  tokens = tokenize(code)
  read_atom(tokens)
end

public def PRINT(node)
  case node
  when Array then "'(" + node.map { |n| PRINT(n) }.join(' ') + ')'
  when Symbol then node.to_s
  else node.inspect
  end
end

MACROS = {}

def quasiquote(ast)
  if ast.is_a?(Array) && ast.any?
    if ast.first == :unquote
      ast[1]
    elsif ast.first.is_a?(Array) && ast.first.any? && ast.first.first == :splice_unquote
      [:concat, ast.first[1], quasiquote(ast[1..-1])]
    else
      [:cons, quasiquote(ast.first), quasiquote(ast[1..-1])]
    end
  else
    [:quote, ast]
  end
end

public def compile(ast, b)
  if ast.is_a?(Array)
    case ast.first
    when :apply
      (_, fn, args) = ast
      fn = compile(fn, b)
      args = compile(args, b)
      "#{fn}.(*#{args})"
    when :block
      fn = ast[1]
      '&' + compile(ast[1], b)
    when :def
      (_, name, val) = ast
      val = compile(val, b)
      "#{safe_name name} = #{val}"
    when :defmacro
      (_, name, fn) = ast
      MACROS[name] = b.eval(compile(fn, b))
      nil
    when :do
      '(' + ast[1..-1].map { |n| compile(n, b) }.join("; ") + ')'
    when :fn
      (_, arg_list, *body) = ast
      body = compile([:do] + body, b)
      arg_list[-1] = "*#{arg_list.pop}" if arg_list[-2] == :&
      "->(#{arg_list.join(', ')}) { #{body} }"
    when :if
      (_, pred, t, f) = ast
      "#{compile pred, b} ? #{compile t, b} : #{compile f, b}"
    when :"."
      (_, obj, message, *args) = ast
      obj = compile(obj, b)
      args.map! { |a| compile(a, b) }
      send = message.is_a?(String) ? "#{obj}.#{message}(ARGS)" : "#{obj}.public_send(#{compile(message, b)}, ARGS)"
      if args.any?
        send.sub(/ARGS/, args.join(', '))
      else
        send.sub(/(, )?ARGS/, '')
      end
    when :quasiquote
      compile(quasiquote(ast[1]), b)
    when :quote
      ast[1].inspect
    when :try
      (_, try_node, catch_node) = ast
      "begin; #{compile(ast[1], b)}; rescue => #{catch_node[1]}; #{compile(catch_node[2], b)}; end"
    else
      (fn, *args) = ast
      if MACROS[fn]
        compile(MACROS[fn].(*args), b)
      else
        fn = compile(fn, b)
        args.map! { |a| compile(a, b) }
        "#{fn}.(#{args.join(', ')})"
      end
    end
  elsif ast.is_a?(Symbol) && ast.to_s =~ /^:/
    ast.to_s
  elsif ast.is_a?(Symbol)
    safe_name(ast).to_s
  else
    ast.inspect
  end
end

def run_file(path, b)
  READ('(' + File.read(path) + ')').each do |node|
    rb = compile(node, b)
    b.eval(rb) if rb
  end
end

SAFE_CHARS = /^[A-Za-z_]+$/
ALT_NAMES = { '=' => 'eq', '*' => 'mul', '/' => 'div', '+' => 'add', '-' => 'sub', '<' => 'lt', '<=' => 'lte', '>' => 'gt', '>=' => 'gte' }

def safe_name(name)
  ALT_NAMES[name.to_s] || name.to_s.chars.map do |c|
    case c
    when SAFE_CHARS then c
    when '-' then '_'
    when '?' then '_q'
    else "_#{c.ord}"
    end
  end.join
end

def core_binding
  b = binding
  run_file('core.lisp', b)
  b
end

if $0 == __FILE__
  if ARGV.any? && ARGV.first == '--compile'
    b = core_binding
    puts File.read(__FILE__).match(/public def PRINT.*?\nend/m).to_s
    puts READ('(' + File.read('core.lisp') + ')').map { |n| compile(n, b) }.compact.join("\n")
    puts READ('(' + File.read(ARGV[1]) + ')').map { |n| compile(n, b) }.compact.join("\n")
  elsif ARGV.any?
    b = core_binding
    run_file(ARGV.first, b)
  else
    b = core_binding
    loop do
      print "user> "
      str = $stdin.gets
      exit if str.nil?
      ast = READ(str)
      begin
        result = b.eval(compile(ast, b))
      rescue StandardError => e
        puts "#{e.class}: #{e.message}"
        puts e.backtrace
      else
        puts PRINT(result)
      end
    end
  end
end
