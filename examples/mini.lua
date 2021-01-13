local linenoise = require 'linenoise'


local function onComplete(tCompletions, strLine)
  -- Get the size of the line.
  local sizLine = string.len(strLine)

  -- Add all possible completions for an empty line.
  if sizLine==0 then
    tCompletions:add('quit')
    tCompletions:add('hello')
    tCompletions:add('hello world')

  else
    -- Does the line start with a substring of "quit"?
    if string.sub('quit', 1, sizLine)==strLine then
      -- Add "quit" as a completion.
      tCompletions:add('quit')
    end

    -- Note that a line like "h" will match both "hello" and "hallo world" below.
    -- The completions object will have 2 possibilities which are cycled by
    -- pressing TAB.

    -- Does the string start with a substring of "hello"?
    if string.sub('hello', 1, sizLine)==strLine then
      -- Add "hello" as a completion.
      tCompletions:add('hello')
    end
    -- Does the string start with a substring of "hello world"?
    if string.sub('hello world', 1, sizLine)==strLine then
      -- Add "hello world" as a completion.
      tCompletions:add('hello world')
    end
  end
end


local function onHint(strLine)
  local strHint

  -- Get the size of the line.
  local sizLine = string.len(strLine)

  -- Show a general hint for an empty line.
  if sizLine==0 then
    strHint = '    Try typing   hello   or   hello world   or   quit.'

  -- Does the line start with a substring of "quit"?
  elseif string.sub('quit', 1, sizLine)==strLine then
    -- Add the rest of "quit" as a hint.
    strHint = string.sub('quit', sizLine+1)

  -- Does the line start with "hello", but nothing after "hello"?
  elseif string.sub('hello', 1, sizLine)==strLine and sizLine<string.len('hello') then
    -- Add the rest of "hello" as a hint.
    strHint = string.sub('hello', sizLine+1)

  -- Does the string start with a substring of "hello world"?
  elseif string.sub('hello world', 1, sizLine)==strLine then
    -- Add the rest of "hello world" as a hint.
    strHint = string.sub('hello world', sizLine+1)
  end

  -- Return the hint. Show it in color 35, which is magenta.
  return strHint, { color=35, bold=false }
end


local term = require 'term'
local colors = term.colors

local strHistory = 'history_mini.txt'

-- Load the history.
linenoise.historyload(strHistory)

print 'Welcome to the mini example for linenoise.'
print 'Written by Christoph Thelen in 2021.'
print ''
print 'Type something to echo it, e.g. "hello world". Type "quit" to exit.'
print ''

local fRunning = true
while fRunning do
  local strPrompt = colors.bright .. colors.blue .. 'echo> ' .. colors.white

  linenoise.setcompletion(onComplete)
  linenoise.sethints(onHint)

  local strLine, strError = linenoise.linenoise(strPrompt)
  if strLine==nil then
    if strError~=nil then
      print('Error: ' .. tostring(strError))
    end
    fRunning = false
  elseif #strLine > 0 then
    linenoise.historyadd(strLine)
    linenoise.historysave(strHistory)

    if strLine=='quit' then
      print('Bye...')
      fRunning = false
    else
      print('echo: ' .. strLine)
    end
  end
end
