# Shared descriptor-safe helpers for the Overview plugin's bindings access.
# Not executable on its own: imported by omarchy-overview-bindings-read and
# omarchy-overview-bindings-write, which Overview.qml runs via Process.
#
# ~/.config/hypr/bindings.lua is a predictable pathname that Hyprland sources
# and executes, so the plugin must never turn that pathname into bytes more
# than once per operation, and must never open it for writing at all. Every
# read here is a single open() carrying O_NOFOLLOW|O_NONBLOCK followed by
# fstat/read on that same descriptor, and every write lands in a fresh
# exclusive sibling that is renamed into place relative to a held directory
# descriptor. Nothing re-resolves the target pathname after validation, so
# there is no window for a symlink, FIFO, device node, or oversized file to
# be swapped in between the check and the operation.

import errno
import os
import stat

BINDINGS_NAME = "bindings.lua"
BINDINGS_DIR = os.path.join(os.path.expanduser("~"), ".config", "hypr")

# A Hyprland keybinding file is a few kilobytes in practice. Half a megabyte
# is generous headroom while staying a firm, auditable bound rather than
# "however much the shell can be made to allocate".
MAX_BYTES = 512 * 1024


class Refused(Exception):
    """A hazard was found; the caller reports it instead of proceeding."""


def open_dir():
    """Open the bindings directory once and keep the descriptor.

    O_NOFOLLOW is deliberately not used here: a dotfiles setup may legitimately
    symlink ~/.config or ~/.config/hypr into a managed repository. The security
    property is taken from the descriptor instead -- it must be a directory the
    current user owns and that no other user can write to, so no one else can
    place entries in it. The final bindings component is opened strictly
    no-follow relative to this descriptor.
    """
    try:
        fd = os.open(BINDINGS_DIR, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    except OSError as error:
        if error.errno == errno.ENOENT:
            raise Refused("The Hyprland config directory does not exist.")
        raise Refused("Could not open the Hyprland config directory.")

    try:
        st = os.fstat(fd)
        if not stat.S_ISDIR(st.st_mode):
            raise Refused("The Hyprland config path is not a directory.")
        if st.st_uid != os.getuid():
            raise Refused("The Hyprland config directory is not owned by this user.")
        if st.st_mode & 0o022:
            raise Refused("The Hyprland config directory is writable by other users.")
    except Exception:
        os.close(fd)
        raise

    return fd


def read_bindings(dir_fd):
    """Return (text, mode) for the bindings file, or (None, None) if absent."""
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC
    try:
        fd = os.open(BINDINGS_NAME, flags, dir_fd=dir_fd)
    except OSError as error:
        if error.errno == errno.ENOENT:
            return None, None
        if error.errno == errno.ELOOP:
            raise Refused("The bindings path is a symlink; refusing to follow it.")
        raise Refused("Could not open the bindings file.")

    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode):
            raise Refused("The bindings path is not a regular file.")
        if st.st_uid != os.getuid():
            raise Refused("The bindings file is not owned by this user.")
        if st.st_size > MAX_BYTES:
            raise Refused("The bindings file exceeds the maximum allowed size.")

        data = os.read(fd, MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise Refused("The bindings file exceeds the maximum allowed size.")
        mode = stat.S_IMODE(st.st_mode)
    finally:
        os.close(fd)

    try:
        return data.decode("utf-8"), mode
    except UnicodeDecodeError:
        raise Refused("The bindings file is not valid UTF-8.")
