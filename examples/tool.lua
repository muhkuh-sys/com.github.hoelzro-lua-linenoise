------------------------------------------------------------------------------
--
-- Create the Shell class.
local class = require 'pl.class'
local Shell = class()


function Shell:_init(tLog)
  self.linenoise = require 'linenoise'
  local lpeg = require 'lpeg'
  self.lpeg = lpeg
  self.pl = require 'pl.import_into'()
  self.term = require 'term'
  self.colors = self.term.colors
  self.tLog = tLog

  -- No data yet.
  self.strData = nil


  ---------------------------------------------------------------------------
  --
  -- Define a set of LPEG helpers.
  --

  -- Match at least one character of whitespace.
  local Space = lpeg.S(" \t")^1
  -- Match optional whitespace.
  local OptionalSpace = lpeg.S(" \t")^0

  -- Match an integer. This can be decimal or hexadecimal.
  -- The "unfinished" variant accepts also unfinished hexadecimal numbers
  -- like "0x".
  local DecimalInteger = lpeg.R('09')^1
  local HexInteger = lpeg.P("0x") * (lpeg.R('09') + lpeg.R('af'))^1
  local UnfinishedHexInteger = lpeg.P("0x") * (lpeg.R('09') + lpeg.R('af'))^0
  local Integer = HexInteger + DecimalInteger
  local UnfinishedInteger = UnfinishedHexInteger + DecimalInteger

  ---------------------------------------------------------------------------
  --
  -- Create a grammar to parse a line.
  --

  -- A filename simply matches the rest of the line. This has one important
  -- reason: if a path contains spaces, it should be encosed in quotes, but
  -- there is no simple way to insert a quote somewhere before the cursor in
  -- linenoise (if there is a way, please tell me :D ).
  local Filename = (1 - lpeg.S('\n\r'))^1

  -- Range is either...
  --   1) the keyword "all"
  --   2) a start and end address
  --   3) a start and length separated by "+"
  local Range = lpeg.Cg(lpeg.P('all'), 'all') +
          (lpeg.Cg(Integer / tonumber, 'startaddress') * Space *
            (
              lpeg.Cg(Integer / tonumber, 'endaddress') +
              (lpeg.P('+') * OptionalSpace * lpeg.Cg(Integer / tonumber, 'length'))
            )
          )

  -- A comment starts with a hash and covers the rest of the line.
  local Comment = lpeg.P('#')

  -- All available commands and their handlers.
  local atCommands = {
    {
      cmd = 'read',
      pattern = lpeg.Cg(lpeg.P('read'), 'cmd') * Space * Range * Space * lpeg.Cg(Filename, 'filename') * -1,
      run = self.__run_read
    },
    {
      cmd = 'write',
      pattern = lpeg.Cg(lpeg.P('write'), 'cmd') * Space * lpeg.Cg(Filename, 'filename') * -1,
      run = self.__run_write
    },
    {
      cmd = 'help',
      pattern = lpeg.Cg(lpeg.P('help'), 'cmd') * (Space * lpeg.Cg(lpeg.R('az')^1, 'topic'))^-1 * -1,
      run = self.__run_help
    },
    {
      cmd = 'quit',
      pattern = lpeg.Cg(lpeg.P('quit'), 'cmd') * -1,
      run = self.__run_quit
    }
  }
  self.__atCommands = atCommands

  -- Combine all commands.
  local AllCommands
  for _, tCommand in ipairs(atCommands) do
    local pattern = tCommand.pattern
    if AllCommands==nil then
      AllCommands = pattern
    else
      AllCommands = AllCommands + pattern
    end
  end

  self.__lineGrammar = lpeg.Ct((AllCommands * (Comment^-1)) + Comment)

  -- Create a table with all commands as a string.
  local astrCommandWords = {}
  for _, tCommand in ipairs(atCommands) do
    table.insert(astrCommandWords, tCommand.cmd)
  end
  self.__astrCommandWords = astrCommandWords

  -- Create a table with all help topics as a string.
  local astrHelpTopicWords = {}
  for _, tTopic in ipairs(self.__atHelpTopics) do
    local strTopic = tTopic.topic
    if strTopic~=nil and strTopic~='' then
      table.insert(astrHelpTopicWords, strTopic)
    end
  end
  self.__astrHelpTopicWords = astrHelpTopicWords

  ---------------------------------------------------------------------------
  -- Create a lookup table for completers and hints. It is used when the
  -- command lines are typed in and not read from a file.
  -- See here for more info on completion and hints:
  --   https://github.com/antirez/linenoise#completion
  --   https://github.com/antirez/linenoise#hints
  --
  -- All entries must have a "pattern" key. This is an LPEG pattern which
  -- matches one specific state of the input. For example if the input line
  -- matches zero or more characters in the range a-z with nothing else
  -- before and after, the user is currently typing the command.
  --
  -- An entry can have a "hint" key. This must be either a string or a
  -- function. The string is directly used as the hint text. The function
  -- gets an eventual match from the pattern as argument and must return
  -- either the hint text as a string or nil.
  --
  -- An entry can have a "words" key. This must be either a table or a
  -- function. The table must only contain strings. The function gets an
  -- eventual match from the pattern as argument and must return a table of
  -- strings.
  --
  -- The completer function looks for the first matching pattern in the
  -- table. If the table entry has a "words" key, it is used to complete the
  -- current line.
  --
  -- The hints function also looks for the first matching pattern in the
  -- table. If the table entry has a "hint" key, it is used as the hint text.
  -- If the table has no "hint" key but "words", this is used together with
  -- an eventually available match to display all available completions in the
  -- hint text.
  self.__atInteractivePatterns = {
    -- Typing a command. This also matches an empty line.
    {
      pattern = lpeg.Cg(lpeg.R('az')^0) * -1,
      words = self.__astrCommandWords
    },

    -- Read command.
    {
      pattern = lpeg.P('read') * Space * -1,
      hint = 'all  or  [startaddress] [endaddress]  or  [startaddress] + [length]',
      words = { 'all' }
    },
    {
      pattern = lpeg.P('read') * Space * lpeg.Cg(lpeg.P('al') + lpeg.P('a')) * -1,
      words = { 'all' }
    },
    {
      pattern = lpeg.P('read') * Space * UnfinishedInteger * -1,
      hint = '    this is the startaddress'
    },
    {
      pattern = lpeg.P('read') * Space * Integer * Space * -1,
      hint = '[endaddress]  or  + [length]'
    },
    {
      pattern = lpeg.P('read') * Space * Integer * Space * UnfinishedInteger * -1,
      hint = '    this is the endaddress'
    },
    {
      pattern = lpeg.P('read') * Space * Integer * Space * lpeg.P('+') * OptionalSpace * -1,
      hint = '[length]'
    },
    {
      pattern = lpeg.P('read') * Space * Integer * Space * lpeg.P('+') * Space * UnfinishedInteger * -1,
      hint = '    this is the length'
    },
    {
      pattern = lpeg.P('read') * Space * (lpeg.P('all') + (Integer * Space * (Integer + (lpeg.P('+') * OptionalSpace * Integer)))) * Space * -1,
      hint = '[filename]',
      words = function(strMatch) return self:__getFilenameWords(strMatch) end
    },
    {
      pattern = lpeg.P('read') * Space * (lpeg.P('all') + (Integer * Space * (Integer + (lpeg.P('+') * OptionalSpace * Integer)))) * Space * lpeg.Cg(Filename) * -1,
      words = function(strMatch) return self:__getFilenameWords(strMatch) end
    },

    -- Write command.
    {
      pattern = lpeg.P('write') * Space * -1,
      hint = '[filename]',
      words = function(strMatch) return self:__getFilenameWords(strMatch) end
    },
    {
      pattern = lpeg.P('write') * Space * lpeg.Cg(Filename) * -1,
      words = function(strMatch) return self:__getFilenameWords(strMatch) end
    },

    -- Help command.
    {
      pattern = lpeg.P('help') * Space * -1,
      hint = function() return '[topic]  possible values: ' .. table.concat(self.__astrHelpTopicWords, ', ') end,
      words = function() return self.__astrHelpTopicWords end
    },
    {
      pattern = lpeg.P('help') * Space * lpeg.Cg(lpeg.R('az')^1) * -1,
      words = function() return self.__astrHelpTopicWords end
    }
  }

end



function Shell:__getFolderEntries(strFolder, strPrintPrefix, astrWords)
  local pl = self.pl
  local strSep = pl.path.sep

  -- Use the "walk" function here to get plain lists of files and folders
  -- which are not combined with the path yet. "walk" returns an iterator, so
  -- the result of walk is called again.
  local _, astrFolders, astrFiles = pl.dir.walk(strFolder, false, false)()
  table.sort(astrFolders)
  table.sort(astrFiles)
  for _, strFolder in ipairs(astrFolders) do
    table.insert(astrWords, pl.path.join(strPrintPrefix, strFolder) .. strSep)
  end
  for _, strFile in ipairs(astrFiles) do
    table.insert(astrWords, pl.path.join(strPrintPrefix, strFile))
  end
end



function Shell:__getFilenameWords(strMatch)
  local pl = self.pl
  local strSep = pl.path.sep
  local astrWords = {}

  local strDir = strMatch
  local strPrintPrefix = strMatch

  if strDir=='' then
    -- An empty match is special. Use the current working folder.
    strDir = pl.path.currentdir()
    strPrintPrefix = ''
    self:__getFolderEntries(strDir, strPrintPrefix, astrWords)

  else
    -- Expand a "~".
    strDir = pl.path.expanduser(strDir)

    local strLastElement = pl.path.basename(strDir)

    -- Does the folder exist?
    if strLastElement~='.' and pl.path.exists(strDir)~=nil and pl.path.isdir(strDir)==true then
      -- Yes -> add all elements of this folder.
      self:__getFolderEntries(strDir, strPrintPrefix, astrWords)

    else
      -- The folder does not exist. Try to cut off the last path element.
      local strDirName = pl.path.dirname(strDir)

      if strDirName=='' then
        if pl.path.isabs(strDir) then
          -- TODO: port this to windows.
          strDir = strSep
          strPrintPrefix = strSep
          self:__getFolderEntries(strDir, strPrintPrefix, astrWords)
        else
          strDir = pl.path.currentdir()
          strPrintPrefix = ''
          self:__getFolderEntries(strDir, strPrintPrefix, astrWords)
        end

      elseif pl.path.exists(strDirName)~=nil and pl.path.isdir(strDirName)==true then
        strDir = strDirName

        -- Cut off the last Element from the print prefix.
        strPrintPrefix = string.sub(strPrintPrefix, 1, -1-string.len(strLastElement))
        self:__getFolderEntries(strDir, strPrintPrefix, astrWords)
      end
    end
  end

  return astrWords
end



Shell.__atHelpTopics = {
  {
    topic = '',
    text = [[
Welcome to the help.

The "help" command alone shows this message. It can also combined with a
topic.

The following example shows help about the "read" command:

  help read

These topics are available:

# local sizMax = 0
# for _, tTopic in ipairs(topics) do
#   local sizTopic = string.len(tTopic.topic)
#   if sizTopic>sizMax then
#     sizMax = sizTopic
#   end
# end
# for _, tTopic in ipairs(topics) do
#   local strTopic = tTopic.topic
#   if strTopic~='' then
  $(strTopic) $(string.rep(' ', sizMax-string.len(strTopic))) : $(tTopic.description)
#   end
# end
    ]]
  },

  {
    topic = 'start',
    description = 'Getting started.',
    text = [[
Getting started.

This tool is just an example for the LUA linenoise bindings. It provides 2
commands "read" and "write".

The read command reads a file or parts of it to an internal buffer.
Run "help read" for details.

The write command writes the buffer to a file. Run "help write" for details.
    ]]
  },

  {
    topic = 'read',
    description = 'The read command.',
    text = [[
The read command reads a file or parts of it into the internal buffer.

There are 3 forms of the command:

 read all FILENAME
   read the complete file with the name FILENAME to the internal buffer
   Example: read all tool.lua

 read START END FILENAME
   read the file with the name FILENAME from offset START to offset END to the
   internal buffer
   Example: read 250 300 tool.lua

 read START + LENGTH FILENAME
   read LENGTH bytes from the file with the name FILENAME starting at offset
   START
   Example: read 250 + 50 tool.lua
    ]]
  },

  {
    topic = 'write',
    description = 'The write command.',
    text = [[
The write command writes the internal buffer to a file.

 write FILENAME
   Example: write buffer.txt

    ]]
  },

  {
    topic = 'quit',
    description = 'The quit command.',
    text = [[
The quit command.

It quits the application without a safety question.
    ]]
  }
}



------------------------------------------------------------------------------


function Shell:__run_help(tCmd)
  -- Get the topic. If no topic was specified, set the topic to the empty
  -- string - which selects the main page.
  local strTopic = tCmd.topic or ''

  -- Search the topic.
  local tTopic
  for _, tTopicCnt in ipairs(self.__atHelpTopics) do
    if tTopicCnt.topic==strTopic then
      tTopic = tTopicCnt
      break
    end
  end
  if tTopic==nil then
    -- Topic not found. Show an error.
    print(string.format('Unknown help topic "%s".', strTopic))
  else
    -- Process the template.
    local strText, strError = self.pl.template.substitute(
      tTopic.text,
      {
        ipairs = ipairs,
        pairs = pairs,
        string = string,

        topics = self.__atHelpTopics
      }
    )
    if strText==nil then
      -- Failed to process the template. Show an error message.
      print('Failed to render the help text: ' .. tostring(strError))
    else
      -- Show the generated help text.
      print(strText)
    end
  end

  return true
end


------------------------------------------------------------------------------


function Shell:__getRange(tCmd, sizAll)
  local ulStart
  local ulLength

  if tCmd.all~=nil then
    ulStart = 0
    ulLength = sizAll

  else
    ulStart = tCmd.startaddress
    ulLength = tCmd.length
    if ulLength==nil then
      local ulEnd = tCmd.endaddress
      if ulEnd<ulStart then
        print('The end address must not be smaller than the start address.')
        ulStart = nil
      else
        ulLength = ulEnd - ulStart
      end
    end
  end

  return ulStart, ulLength
end



function Shell:__run_read(tCmd)
  local pl = self.pl
  local tLog = self.tLog

  -- Discard old buffern contents.
  self.strData = nil

  local strFilename = tCmd.filename
  local strData, strMessage = pl.utils.readfile(strFilename, true)
  if strData==nil then
    tLog.error('Failed to read "%s": %s', strFilename, tostring(strMessage))
  else
    local sizAll = string.len(strData)
    local ulStart, ulLength = self:__getRange(tCmd, sizAll)
    if ulStart~=nil then
      tLog.info('Reading [0x%08x,0x%08x[ from "%s"...', ulStart, ulStart+ulLength, strFilename)
      self.strData = string.sub(strData, ulStart+1, ulStart+ulLength)
      tLog.info('The buffer has now 0x%08x bytes.', string.len(self.strData))
    end
  end

  return true
end



function Shell:__run_write(tCmd)
  local pl = self.pl
  local tLog = self.tLog

  local strData = self.strData
  if strData==nil then
    tLog.info('The buffer is empty, there is nothing to write.')
  else
    local strFilename = tCmd.filename
    tLog.info('Writing the buffer to "%s"...', strFilename)
    local tResult, strMessage = pl.utils.writefile(strFilename, strData, true)
    if tResult~=true then
      tLog.error('Failed to write the buffer to "%s": %s', strFilename, tostring(strMessage))
    else
      tLog.info('OK')
    end
  end

  return true
end



function Shell:__run_quit()
  -- Quit the application.
  return false
end


------------------------------------------------------------------------------


function Shell:__getCompletions(tCompletions, strLine, astrWords, strMatch)
  local sizMatch = string.len(strMatch)
  if sizMatch==0 then
    -- Add all available words.
    for _, strWord in ipairs(astrWords) do
      tCompletions:add(strLine .. strWord)
    end
  else
    -- Get the prefix of the line without the match.
    local strPrefix = string.sub(strLine, 1, -1-string.len(strMatch))
    -- Add the devices matching the input.
    for _, strWord in pairs(astrWords) do
      local sizWord = string.len(strWord)
      if sizWord>=sizMatch and string.sub(strWord, 1, sizMatch)==strMatch then
        tCompletions:add(strPrefix .. strWord)
      end
    end
  end
end



function Shell:__getMatchingHints(astrWords, strMatch)
  local sizMatch = string.len(strMatch)

  local atHints = {}
  for _, strWord in pairs(astrWords) do
    local sizWord = string.len(strWord)
    -- Does the word start with the match?
    if sizWord>=sizMatch and string.sub(strWord, 1, sizMatch)==strMatch then
      -- Do not add the complete argument for the first match. It completes the typed letters.
      if #atHints==0 then
        table.insert(atHints, string.sub(strWord, sizMatch+1))
      else
        table.insert(atHints, strWord)
      end
    end
  end

  local strHint
  if #atHints>0 then
    strHint = table.concat(atHints, ' ')
  end

  return strHint
end



function Shell:__completer(tCompletions, strLine)
  local lpeg = self.lpeg

  -- Loop over all available patterns.
  for _, tPattern in ipairs(self.__atInteractivePatterns) do
    -- Does the pattern match?
    local tMatch = lpeg.match(tPattern.pattern, strLine)
    -- The match is either the index if there are no captures or a string if
    -- there is one capture. Pattern can also return a table of captures, but
    -- this is not supported here.
    local strMatchType = type(tMatch)
    -- Replace matches without captures by the empty string.
    if strMatchType=='number' then
      tMatch = ''
      strMatchType = type(tMatch)
    end
    if strMatchType=='string' then
      -- Yes, the pattern matches.
      if tPattern.words~=nil then
        -- Is this a function or a table?
        local astrWords
        local strType = type(tPattern.words)
        if strType=='table' then
          astrWords = tPattern.words
        elseif strType=='function' then
          astrWords = tPattern.words(tMatch)
        end
        if astrWords~=nil then
          self:__getCompletions(tCompletions, strLine, astrWords, tMatch)
        end
      end
      break
    end
  end
end



function Shell:__hints(strLine)
  local strHint
  local sizLine = string.len(strLine)
  local lpeg = self.lpeg

  -- Do not give a hint for the empty line. This does not work for the initial prompt.
  if sizLine>0 then
    -- Loop over all available patterns.
    for _, tPattern in ipairs(self.__atInteractivePatterns) do
      -- Does the pattern match?
      local tMatch = lpeg.match(tPattern.pattern, strLine)
      -- The match is either the index if there are no captures or a string if
      -- there is one capture. Pattern can also return a table of captures, but
      -- this is not supported here.
      local strMatchType = type(tMatch)
      -- Replace matches without captures by the empty string.
      if strMatchType=='number' then
        tMatch = ''
        strMatchType = type(tMatch)
      end
      if strMatchType=='string' then
        -- Yes, the pattern matches.
        if tPattern.hint~=nil then
          local strType = type(tPattern.hint)
          if strType=='string' then
            strHint = tPattern.hint
          elseif strType=='function' then
            strHint = tPattern.hint(tMatch)
          end
        elseif tPattern.words~=nil then
          -- Is this a function or a table?
          local astrWords
          local strType = type(tPattern.words)
          if strType=='table' then
            astrWords = tPattern.words
          elseif strType=='function' then
            astrWords = tPattern.words(tMatch)
          end
          if astrWords~=nil then
            strHint = self:__getMatchingHints(astrWords, tMatch)
          end
        end
        break
      end
    end
  end

  return strHint
end


function Shell:run()
  local atCommands = self.__atCommands
  local linenoise = self.linenoise
  local lpeg = self.lpeg
  local tGrammar = self.__lineGrammar
  local strHistory = 'history.txt'
  local tLog = self.tLog
  local colors = self.colors

  linenoise.historyload(strHistory)

  print 'This is the "tool" example for linenoise.'
  print 'Written by Christoph Thelen in 2021.'
  print 'Type "help" to get started. Use tab to complete commands.'
  print ''

  local fRunning = true
  while fRunning do
    -- Set the current prompt. If there is no data, show "empty".
    -- If there is data, show "data".
    local strPromptText = 'empty'
    if self.strData~=nil then
      strPromptText = 'data'
    end
    local strPrompt = colors.bright .. colors.blue .. strPromptText .. '> ' .. colors.white

    linenoise.setcompletion(function(tCompletions, strLine)
        self:__completer(tCompletions, strLine)
      end
    )
    -- The color value of 35 is "magenta".
    linenoise.sethints(function(strLine)
        return self:__hints(strLine), { color=35, bold=false }
      end
    )

    local strLine, strError = linenoise.linenoise(strPrompt)
    if strLine==nil then
      if strError~=nil then
        tLog.error('Error: %s', tostring(strError))
      end
      fRunning = false
    elseif #strLine > 0 then
      linenoise.historyadd(strLine)
      linenoise.historysave(strHistory)

      -- Parse the line.
      local tCmd = lpeg.match(tGrammar, strLine)
      if tCmd==nil then
        print('Failed to parse the line.')
      else
        -- There should be a command at the "cmd" key.
        -- If there is no command, this is a comment.
        local strCmd = tCmd.cmd
        if strCmd~=nil then
          -- Search the command.
          local tCmdHit
          for _, tCmdCnt in ipairs(atCommands) do
            if tCmdCnt.cmd==strCmd then
              tCmdHit = tCmdCnt
              break
            end
          end
          if tCmdHit==nil then
            print('Command not found.')
          else
            -- Run the command.
            fRunning = tCmdHit.run(self, tCmd)
          end
        end
      end
    end
  end
end

-- Create a dummy logger object.
local tLog = {
  emerg = function(...) print('[EMERG] ' .. string.format(...)) end,
  alert = function(...) print('[ALERT] ' .. string.format(...)) end,
  fatal = function(...) print('[FATAL] ' .. string.format(...)) end,
  error = function(...) print('[ERROR] ' .. string.format(...)) end,
  warning = function(...) print('[WARNING] ' .. string.format(...)) end,
  notice = function(...) print('[NOTICE] ' .. string.format(...)) end,
  info = function(...) print('[INFO] ' .. string.format(...)) end,
  debug = function(...) print('[DEBUG] ' .. string.format(...)) end,
  trace = function(...) print('[TRACE] ' .. string.format(...)) end,
}

-- Run the shell.
local tShell = Shell(tLog)
tShell:run()
os.exit(0)
