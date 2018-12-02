struct Manager::Application::Delete
  getter name : String,
    package : String,
    pkgdir : String,
    prefix : String,
    pkg_file : PkgFile,
    service : Service::Systemd | Service::OpenRC | Nil
  @keep_user_group : Bool
  @user : String
  @group : String

  def initialize(@name : String, @prefix : String, @keep_user_group : Bool = false)
    @path = Path.new @prefix
    @pkgdir = @path.app + @name

    file = File.info @pkgdir
    @user = ::System::Owner.to_user file.owner
    @group = ::System::Owner.to_group file.group

    # Checks
    @pkg_file = PkgFile.new @pkgdir
    @package = pkg_file.package
    if service = ::System::Host.service?.try &.new @name
      if service.exists? && service.is_app?(@pkgdir)
        Log.info "a system service is found", @name
        service.check_delete
        @service = service
      else
        Log.warn "no system service found", @name
        @service = nil
      end
    end
  end

  def simulate
    String.build do |str|
      str << "\nname: " << @name
      str << "\npackage: " << @package
      str << "\npkgdir: " << @pkgdir
      str << "\nuser: " << @user
      str << "\ngroup: " << @group
      str << "\nservice: " << @service.try &.file if @service
    end
  end

  def run
    Log.info "deleting", @pkgdir
    @service.try &.delete

    if !@keep_user_group && ::System::Owner.root?
      ::System::Owner.del_user @user if @user.starts_with? '_' + @name
      ::System::Owner.del_group @group if @group.starts_with? '_' + @name
    end

    FileUtils.rm_rf @pkgdir
    Log.info "delete completed", @pkgdir
    self
  end
end
