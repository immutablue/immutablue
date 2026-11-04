# Introduced via the immutablue project (freebsd-be backend).
# - https://gitlab.com/immutablue/immutablue
#
# Software Homebrew installed (Linux binaries, run through the Linuxulator)
# goes at the END of PATH, so FreeBSD's own tools win. The brew command
# itself is /usr/local/bin/brew, which runs Homebrew in the Linux userland.
# POSIX sh: FreeBSD's /bin/sh reads profile.d too.
if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    case ":${PATH}:" in
        *:/home/linuxbrew/.linuxbrew/bin:*) ;;
        *) PATH="${PATH}:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin" ;;
    esac
    export PATH
fi
