require "spec"
require "file_utils"
require "../src/logger"

DPPM_CONFIG_FILE = File.expand_path __DIR__ + "/../config.con"
TEMP_DPPM_PREFIX = __DIR__ + "/temp_dppm_prefix"
Log.output = File.open "/dev/null", "a"
Log.error = File.open "/dev/null", "a"
