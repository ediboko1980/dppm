require "yaml"
require "semantic_compare"

struct Package::Deps
  getter log
  @path : Package::Path

  def initialize(@path)
  end

  def get(pkg, pkgdir, allvers = Hash(String, Array(String)).new)
    # No need to parse if the deps list is empty
    return allvers if !pkg["deps"]? || pkg["deps"] == ""
    pkgdeps = pkg["deps"].as_h

    pkgdeps.each_key do |dep|
      if !File.exists? pkgdir + "/lib/#{dep}"
        Log.info "calculing dependency", dep.to_s
        yaml = YAML.parse File.read "#{@path.src}/#{dep}/pkg.yml"
        newvers = Array(String).new

        # If an array of versions is already provided by a dependency
        if dep_vers = allvers[dep]?
          dep_vers.each do |ver|
            newvers << ver if SemanticCompare.expression ver, pkgdeps[dep].to_s
          end
        else
          # HTTPget all versions, parse and test if the versions available match
          allvers[dep.to_s] = Array(String).new
          Version.get(Localhost.kernel, Localhost.arch, yaml["version"]).each do |ver|
            newvers << ver if ver && SemanticCompare.expression ver, pkgdeps[dep].to_s
          end
        end
        # Raise an error if two packages require different versions of a same dependency
        raise "dependency problem for `#{pkg["package"]}`: the versions required by `#{pkgdeps[dep]}` don't match" if !newvers[0]?
        allvers[dep.to_s] = newvers

        # Loops inside dependencies of dependencies
        allvers = get(YAML.parse(File.read "#{@path.src}/#{dep}/pkg.yml"), pkgdir, allvers) if yaml["deps"]?
      end
    end
    allvers
  end

  def build(vars, deps)
    Log.info "dependencies", "building"
    Dir.mkdir_p vars["pkgdir"] + "/lib"

    contained = vars.has_key?("--contained") ? true : false

    # Build each dependency
    deps.each do |dep, ver|
      deppath = "#{vars["prefix"]}/pkg/#{dep}_#{ver}"
      depdir = "#{vars["pkgdir"]}/lib/#{dep}_#{ver}"
      if Dir.exists? deppath
        Log.info "already present", dep + '_' + ver
        FileUtils.cp_r deppath, depdir if contained
      else
        Log.info "building dependency", deppath
        Package::Build.new(vars.merge({"package" => dep,
                                       "version" => ver})).run
        File.rename deppath, depdir if contained
      end
      if !File.exists? "#{vars["pkgdir"]}/lib/#{dep}"
        Log.info "adding symlink to dependency", "#{dep}:#{ver}"
        File.symlink(contained ? depdir : deppath, "#{vars["pkgdir"]}/lib/#{dep}")
      end
      Log.info "dependency added", "#{dep}:#{ver}"
    end
  end
end