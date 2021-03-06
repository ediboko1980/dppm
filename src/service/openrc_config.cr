require "./config"

class Service::OpenRC::Config < Service::Config
  private OPENRC_RELOAD_COMMAND  = "supervise-daemon --pidfile \"$pidfile\" --signal "
  private OPENRC_PIDFILE         = "pidfile=\"/run/${RC_SVCNAME}.pid\""
  private OPENRC_SHEBANG         = "#!/sbin/openrc-run"
  private OPENRC_SUPERVISOR      = "supervisor=supervise-daemon"
  private OPENRC_ENV_VARS_PREFIX = "supervise_daemon_args=\"--env '"
  private OPENRC_NETWORK_SERVICE = "net"

  def initialize
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def initialize(data : String | IO)
    line_number = 1
    function_name = ""

    data.each_line do |full_line|
      line = full_line.lstrip "\n\t "
      if line.ends_with? '}'
        function_name = ""
      elsif function_name = line.rchop? "() {"
      elsif @description = line.lchop?("description='").try &.rchop
      elsif @directory = line.lchop?("directory='").try &.rchop
      elsif @umask = line.lchop? "umask="
      elsif @log_output = line.lchop?("output_log='").try &.rchop
      elsif @log_error = line.lchop?("error_log='").try &.rchop
      elsif @restart_delay = line.lchop?("respawn_delay=").try &.to_u32
      elsif @command = line.lchop?("command='").try &.rchop.+ @command.to_s
      elsif command_args = line.lchop?("command_args='")
        @command = @command.to_s + ' ' + command_args.rchop
      elsif command_user = line.lchop?("command_user='")
        user_and_group = command_user.rchop.partition ':'
        @user = user_and_group[0].empty? ? nil : user_and_group[0]
        @group = user_and_group[2].empty? ? nil : user_and_group[2]
      elsif openrc_env_vars = line.lchop?(OPENRC_ENV_VARS_PREFIX)
        parse_env_vars openrc_env_vars.rchop("'\"")
      else
        case line
        when .empty?,
             OPENRC_SHEBANG,
             OPENRC_SUPERVISOR,
             OPENRC_PIDFILE,
             "\"",
             .starts_with?("extra_started_commands"),
             .starts_with?("pidfile")
          next
        end
        case function_name
        when "depend"
          directive = true
          line.split ' ' do |element|
            if directive
              raise "Unsupported line depend directive: " + element if element != "after"
              directive = false
            elsif element != OPENRC_NETWORK_SERVICE
              @after << element
            end
          end
        when "reload"
          if reload_signal = line.lchop? OPENRC_RELOAD_COMMAND
            @reload_signal = reload_signal
          end
        else
          raise "Unsupported line"
        end
      end
      line_number += 1
    rescue ex
      raise Error.new "Parse error line at #{line_number}: #{full_line}", ex
    end
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def build(io : IO) : Nil
    io << OPENRC_SHEBANG << "\n\n"
    io << OPENRC_SUPERVISOR << '\n'
    io << OPENRC_PIDFILE
    io << "\nextra_started_commands=reload" if @reload_signal
    io << "\ncommand_user='#{@user}:#{@group}'" if @user || @group
    io << "\ndirectory='" << @directory << '\'' if @directory
    if command = @command
      command_elements = command.partition ' '
      io << "\ncommand='" << command_elements[0] << '\''
      if !command_elements[2].empty?
        io << "\ncommand_args='" << command_elements[2] << '\''
      end
    end
    io << "\noutput_log='" << @log_output << '\'' if @log_output
    io << "\nerror_log='" << @log_error << '\'' if @log_error
    io << "\ndescription='" << @description << '\'' if @description
    io << "\nrespawn_delay=" << @restart_delay if @restart_delay
    io << "\numask=" << @umask if @umask

    if !@env_vars.empty?
      io << '\n' << OPENRC_ENV_VARS_PREFIX
      build_env_vars io
      io << "'\""
    end

    io << "\n\ndepend() {\n\tafter "
    @after << OPENRC_NETWORK_SERVICE
    @after.join ' ', io
    io << "}\n"

    if @reload_signal
      io << <<-E

      reload() {
      \tebegin "Reloading $RC_SVCNAME"
      \t#{OPENRC_RELOAD_COMMAND}#{@reload_signal}
      \teend $? "Failed to reload $RC_SVCNAME"
      }

      E
    end
  end
end
