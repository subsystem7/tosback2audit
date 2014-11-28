require_relative 'defaults'

#
# (one interesting) usage: File.write!($base_properties, File.readlines($base_properties).sort.join)
def File.write!(path, contents)
  File.open(path, 'w'){|fh| fh.write contents}
end

class String
  def is_integer?
    !!(self =~ /^[-+]?[0-9]+$/)
  end
end



def time_from_seconds(seconds)
  (nil != seconds && seconds.is_integer?) ? Time.at(seconds.to_i) : nil
end

# This method opens a file that should contain a
# string representing a seconds time value
def get_time_from_file_type_latest(file_path)
  time = nil
  if(File.exists?(file_path)) then
    latest_file = File.open(file_path)
    time = time_from_seconds(latest_file.gets)
    # log( (nil!=time ? time.asctime : 'no time') )
    latest_file.close
  end
  time
end


def log(str)
  puts '('+caller[0][/`([^']*)'/, 1]+') '+str
end


def check_or_create_dir(path, exit_on_fail)
  okay = true
  if(!Dir.exists?(path))
    begin
      Dir.mkdir(path)
    rescue
      okay = false
      if(exit_on_fail) then
        log(path + ' does not exist and cannot be created. Good bye.')
        exit
      else
        log(path + ' does not exist and cannot be created.') if $DEBUG_MODE
      end
    end
  end
  if(File.writable?(path))
    log("#{path} exists and is writable") if $DEBUG_MODE
  else
    okay = false
    if(exit_on_fail) then
      log(path + ' exists but is not writable. Good bye.')
      exit
    else
      log(path + ' exists but is not writable.') if $DEBUG_MODE
    end
  end
  okay
end
