require "./program_data"

struct Prefix::Pkg
  include ProgramData
  getter package : String,
    version : String

  protected def initialize(@prefix : Prefix, name : String, version : String? = nil, @pkg_file : PkgFile? = nil)
    if version
      @version = version
      @package = name
    elsif name.includes? '_'
      @package, @version = name.split '_', limit: 2
    else
      raise "no version provided for #{name}"
    end
    @name = @package + '_' + @version

    @path = @prefix.pkg + @name + '/'
    if pkg_file
      pkg_file.path = nil
      pkg_file.root_dir = @path
      @pkg_file = pkg_file
    end
  end

  def self.create(prefix : Prefix, name : String, version : String?, tag : String?)
    if name.includes? ':'
      package, tag_or_version = name.split ':', limit: 2
    else
      package = name
    end
    src = Src.new prefix, package

    if !version && !tag
      if tag_or_version
        if tag_or_version =~ /^([0-9]+\.[0-9]+\.[0-9]+)/
          version = tag_or_version
        else
          tag = tag_or_version
        end
      else
        # Set a default tag if not set
        tag = "latest"
      end
    end

    if version
      # Check if the version number is available
      available_version = false
      src.pkg_file.each_version do |ver|
        if version == ver
          available_version = true
          break
        end
      end
      raise "not available version number: " + version if !available_version
    elsif tag
      version = src.pkg_file.version_from_tag tag
    else
      raise "fail to get a version"
    end
    new prefix, package, version, src.pkg_file
  rescue ex
    raise "can't obtain a version: #{ex}"
  end

  def new_app(app_name : String? = nil) : App
    case pkg_file.type
    when .app?
      # Generate a name if none is set
      app_name ||= package + '-' + Random::Secure.hex(8)
      Utils.ascii_alphanumeric_dash? app_name
    else
      # lib and others
      raise "only applications can be added to the system: #{pkg_file.type}"
    end
    App.new @prefix, app_name, pkg_file
  end

  def src : Src
    @src ||= Src.new @prefix, @package, @pkg_file
  end
end