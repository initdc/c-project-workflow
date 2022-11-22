require 'json'

def get_zig_targets
    output = `zig targets | jq -r .libc`
    return nil if output.empty?

    targets = JSON.parse output
    return targets.uniq.sort
end

def get_gcc_targets
    cmd = "ls -1 /usr/bin/*-gcc"
    IO.popen(cmd) do |r|
        lines = r.readlines
        return nil if lines.empty?
  
        targets = []
        for line in lines
            target = line.delete_suffix("\n").delete_prefix("/usr/bin/")
            targets.push target
        end
        return targets
    end
rescue
    return nil
end

if __FILE__ == $0
    pp get_zig_targets
    pp get_gcc_targets
end
