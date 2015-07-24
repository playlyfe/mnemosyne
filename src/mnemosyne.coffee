colors = require 'colors/safe'
util = require 'util'

class Mnemosyne

  constructor: (options, parent) ->
    options ?= {}
    options.context ?= 'Logger'
    if parent?
      @parent = parent
      @context = parent.context.slice().concat([options.context] ? [])
    else
      @context = [options.context] ? []

    @limit = options.limit ? 100
    @buffer = []
    @output_buffer = []
    @flush_interval = options.flush_interval ? 5
    @timer = null
    @stats = {}
    @levels = options.levels ? ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']
    @level_index = {
      'ALL': 0
      'OFF': @levels.length
    }
    if options.color
      @color = options.color
    else
      @color = (level) ->
        switch level
          when 'TRACE'
            colors.grey(level)
          when 'DEBUG'
            level
          when 'INFO'
            "#{colors.cyan(level)} "
          when 'WARN'
            "#{colors.yellow(level)} "
          when 'ERROR'
            colors.red(level)
          when 'FATAL'
            colors.red.bold(level)

    @format = 'text'

    for index, level of @levels
      @level_index[level] = parseInt(index) + 1
      @[level.toLowerCase()] = ((level) =>
        (msg, data) =>
          @log(level, msg, data)
      )(level)
    if options.log_level?
      @log_level = @level_index[options.log_level]
    else
      @log_level = parent?.log_level ? 0

    return

  log: (level, msg, data) ->
    entry = { context: @context, level: level, msg: msg, data: data }
    @buffer.push entry

    if @parent?
      @parent._log(entry)

      if @level_index[level] >= @log_level
        if @format is 'json'
          @parent._bufferOutput JSON.stringify entry
        else
          if data
            @parent._bufferOutput "#{@color(level)} [#{colors.blue(@context.join(':'))}] #{msg}\nDATA> #{util.inspect(data, { colors: true, depth: 5 })}"
          else
            @parent._bufferOutput "#{@color(level)} [#{colors.blue(@context.join(':'))}] #{msg}"

    else

      if @level_index[level] >= @log_level
        if @format is 'json'
            @output_buffer.push JSON.stringify entry
          else
            if data
              @output_buffer.push "#{@color(level)} [#{colors.blue(@context.join(':'))}] #{msg}\nDATA> #{util.inspect(data, { colors: true, depth: 5 })}"
            else
              @output_buffer.push "#{@color(level)} [#{colors.blue(@context.join(':'))}] #{msg}"

          if @timer is null
            @timer = setTimeout(@_flush, @flush_interval, @)

    if @buffer.length > @limit * 1.25
      @buffer = @buffer.slice(@limit * 1.25)
    return

  profile: (stat, start, level = 'DEBUG') ->
    if start?
      duration = process.hrtime(start)
      @log(level, "#{stat} - #{colors.cyan.bold("#{(duration[0] * 1e9 + duration[1])/1e6}ms")}")
    else
      process.hrtime()


  _log: (entry) ->
    @buffer.push entry
    @parent?._log(entry)
    if @buffer.length > @limit * 1.25
      @buffer = @buffer.slice(@limit * 1.25)
    return

  _bufferOutput: (line) ->
    if @parent?
      @parent._bufferOutput line
    else
      @output_buffer.push line
      if @timer is null
        @timer = setTimeout(@_flush, @flush_interval, @)
    return

  _flush: (self) ->
    for line in self.output_buffer
      console.log line
    self.output_buffer.length = 0
    self.timer = null
    return

  createChildLogger: (options) ->
    new Mnemosyne(options, @)

  dump: () ->
    console.log colors.red.bold(">>>>>>>>>>>>>>>>>>>>>>>>>>>> [#{@context.join(':')}] DUMP START <<<<<<<<<<<<<<<<<<<<<<<<<<<<")
    for entry in @buffer
      {data, msg, level} = entry
      if @format is 'json'
        console.log "#{colors.red.bold(">>>>")} #{JSON.stringify entry}"
      else
        if data
          console.log "#{colors.red.bold(">>>>")} #{@color(level)} [#{colors.blue(@context.join(':'))}] #{msg}\n#{colors.red.bold(">>>>")} DATA> #{util.inspect(data, { colors: true, depth: 5 })}"
        else
          console.log "#{colors.red.bold(">>>>")} #{@color(level)} [#{colors.blue(@context.join(':'))}] #{msg}"
    console.log colors.red.bold(">>>>>>>>>>>>>>>>>>>>>>>>>>>>  [#{@context.join(':')}] DUMP END  <<<<<<<<<<<<<<<<<<<<<<<<<<<<")
    return

module.exports = Mnemosyne
