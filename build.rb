require "./version"
require "./get-version"
require "./get-gcc-targets"

PROGRAM = "c-demo"
# VERSION = "v0.0.1"
SOURCE = "src/main.c lib/*.c"
OUTPUT_ARG = "-o"
RELEASE_BUILD = true
RELEASE_ARG = RELEASE_BUILD == true ? "-O2" : ""
RELEASE = RELEASE_BUILD == true ? "release" : "debug"
# used in this way:
# GCC SOURCE RELEASE_ARG OUTPUT_ARG OUTPUT_PATH
TEST_CMD = "ctest"

TARGET_DIR = "target"
DOCKER_DIR = "docker"
UPLOAD_DIR = "upload"

def doCleanAll
    puts "doCleanAll..."
    `rm -rf #{TARGET_DIR} #{UPLOAD_DIR}`
end

def doClean
    puts "doClean..."
    `rm -rf #{TARGET_DIR}/#{DOCKER_DIR} #{UPLOAD_DIR}`
end

# go tool dist list
# linux only for docker
GO_C = {
    "linux/386": "i686-linux-gnu-gcc",
    "linux/amd64": ["x86_64-linux-gnu-gcc", "musl-gcc"],
    "linux/arm": ["arm-linux-gnueabi-gcc", "arm-linux-gnueabihf-gcc"],
    "linux/arm64": "aarch64-linux-gnu-gcc",
    "linux/mips": "mips-linux-gnu-gcc",
    "linux/mips64": "mips64-linux-gnuabi64-gcc",
    "linux/mips64le": "mips64el-linux-gnuabi64-gcc",
    "linux/mipsle": "mipsel-linux-gnu-gcc",
    "linux/ppc64": "powerpc64-linux-gnu-gcc",
    "linux/ppc64le": "powerpc64le-linux-gnu-gcc",
    "linux/riscv64": "riscv64-linux-gnu-gcc",
    "linux/s390x": "s390x-linux-gnu-gcc",
}

ARM = ["5", "6", "7"]

# ls -1 /usr/bin/*-gcc
TARGETS = [
    "aarch64-linux-gnu-gcc",
    "arm-linux-gnueabi-gcc",
    "arm-linux-gnueabihf-gcc",
    "c89-gcc",
    "c99-gcc",
    "i686-linux-gnu-gcc",
    "i686-w64-mingw32-gcc",
    "mips64el-linux-gnuabi64-gcc",
    "mips64-linux-gnuabi64-gcc",
    "mipsel-linux-gnu-gcc",
    "mips-linux-gnu-gcc",
    "musl-gcc",
    "powerpc64le-linux-gnu-gcc",
    "powerpc64-linux-gnu-gcc",
    "powerpc-linux-gnu-gcc",
    "riscv64-linux-gnu-gcc",
    "s390x-linux-gnu-gcc",
    "x86_64-linux-gnu-gcc",
    "x86_64-linux-gnux32-gcc",
    "x86_64-w64-mingw32-gcc"
]

TEST_TARGETS = [
    "aarch64-linux-gnu-gcc",
    "arm-linux-gnueabi-gcc",
    "arm-linux-gnueabihf-gcc",
    "musl-gcc",
    "riscv64-linux-gnu-gcc",
    "x86_64-linux-gnu-gcc",
    "x86_64-w64-mingw32-gcc"
]

LESS_TARGETS = [
    "aarch64-linux-gnu-gcc",
    "musl-gcc",
    "x86_64-linux-gnu-gcc",
]

CC = [
    "gcc-aarch64-linux-gnu",
    "gcc-arm-linux-gnueabi",
    "gcc-arm-linux-gnueabihf",
    "gcc-mips-linux-gnu",
    "gcc-mips64-linux-gnuabi64",
    "gcc-mips64el-linux-gnuabi64",
    "gcc-mipsel-linux-gnu",
    "gcc-powerpc-linux-gnu",
    "gcc-powerpc64-linux-gnu",
    "gcc-powerpc64le-linux-gnu",
    "gcc-riscv64-linux-gnu",
    "gcc-s390x-linux-gnu",
    "gcc-i686-linux-gnu",
    "gcc-x86-64-linux-gnu",
    "gcc-x86-64-linux-gnux32",
    "gcc-mingw-w64-i686",
    "gcc-mingw-w64-x86-64",
    "musl-dev",
    "musl-tools"
]

def run_install
    cmd = "sudo apt-get install -y #{CC.join(" ")}"
    puts cmd
    IO.popen(cmd) do |r|
        puts r.readlines
    end
end

version = get_version ARGV, 0, VERSION

test_bin = ARGV[0] == "test" || false
less_bin = ARGV[0] == "less" || false

install_cc = ARGV.include? "--install-cc" || false
clean_all = ARGV.include? "--clean-all" || false
clean = ARGV.include? "--clean" || false
run_test = ARGV.include? "--run-test" || false
catch_error = ARGV.include? "--catch-error" || false

if install_cc
    run_install
    return
end

targets = get_gcc_targets || TARGETS
targets = TEST_TARGETS if test_bin
targets = LESS_TARGETS if less_bin

if run_test
    puts TEST_CMD
    test_result = system TEST_CMD
    if catch_error and !test_result
        return
    end
end

if clean_all
    doCleanAll
elsif clean
    doClean
    # on local machine, you may re-run this script
elsif test_bin || less_bin
    doClean
end
`mkdir -p #{TARGET_DIR} #{UPLOAD_DIR}`
`mkdir -p #{TARGET_DIR}/#{DOCKER_DIR}`

def existsThen(cmd, src, dest)
    if system "test -f #{src}"
        `#{cmd} #{src} #{dest}`
    end
end

def notExistsThen(cmd, dest, src)
    if not system "test -f #{dest}"
        if system "test -f #{src}"
            cmd = "#{cmd} #{src} #{dest}"
            puts cmd
            IO.popen(cmd) do |r|
                puts r.readlines
            end
        else
            puts "!! #{src} not exists"
        end
    end
end

for target in targets
    tp_array = target.split("-")
    architecture = tp_array[0]
    os = tp_array[1]
    os = "linux" if os == "gcc"

    windows = os == "w64"
    
    program_bin = !windows ? PROGRAM : "#{PROGRAM}.exe"
    target_bin = !windows ? target : "#{target}.exe"

    gcc = target

    dir = "#{TARGET_DIR}/#{target}/#{RELEASE}"
    `mkdir -p #{dir}`

    cmd = "#{gcc} #{SOURCE} #{RELEASE_ARG} #{OUTPUT_ARG} #{dir}/#{program_bin}"
    puts cmd
    system cmd

    existsThen "ln", "#{dir}/#{program_bin}", "#{UPLOAD_DIR}/#{target_bin}"
end

GO_C.each do |target_platform, targets|
    tp_array = target_platform.to_s.split("/")
    os = tp_array[0]
    architecture = tp_array[1]

    if architecture == "arm"
        for variant in ARM
            docker = "#{TARGET_DIR}/#{DOCKER_DIR}/#{os}/#{architecture}/v#{variant}"
            puts docker
            `mkdir -p #{docker}`

            if targets.kind_of?(Array)
                for target in targets
                    tg_array = target.split("-")
                    abi = tg_array[2]
                    abi = tg_array.first if abi.nil?

                    existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}-#{abi}"
                    Dir.chdir docker do
                        notExistsThen "ln -s", PROGRAM, "#{PROGRAM}-#{abi}"
                    end
                end
            else
                target = targets
                existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}"
            end
        end
    else
        docker = "#{TARGET_DIR}/#{DOCKER_DIR}/#{os}/#{architecture}"
        puts docker
        `mkdir -p #{docker}`

        if targets.kind_of?(Array)
            for target in targets
                tg_array = target.split("-")
                abi = tg_array[2]
                abi = tg_array.first if abi.nil?

                existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}-#{abi}"
                Dir.chdir docker do
                    notExistsThen "ln -s", PROGRAM, "#{PROGRAM}-#{abi}"
                end
            end
        else
            target = targets
            existsThen "ln", "#{TARGET_DIR}/#{target}/#{RELEASE}/#{PROGRAM}", "#{docker}/#{PROGRAM}"
        end
    end
end

# cmd = "file #{UPLOAD_DIR}/**"
# IO.popen(cmd) do |r|
#         puts r.readlines
# end

file = "#{UPLOAD_DIR}/BINARYS"
IO.write(file, "")

cmd = "tree #{TARGET_DIR}/#{DOCKER_DIR}"
IO.popen(cmd) do |r|
    rd = r.readlines
    puts rd

    for o in rd
        IO.write(file, o, mode: "a")
    end
end

Dir.chdir UPLOAD_DIR do
    file = "SHA256SUM"
    IO.write(file, "")

    cmd = "sha256sum *"
    IO.popen(cmd) do |r|
        rd = r.readlines

        for o in rd
            if !o.include? "SHA256SUM" and !o.include? "BINARYS"
                print o
                IO.write(file, o, mode: "a")
            end
        end
    end
end

# `docker buildx build --platform linux/amd64 -t demo:amd64 . --load`
# cmd = "docker run demo:amd64"
# IO.popen(cmd) do |r|
#         puts r.readlines
# end
