package ocurses

import "core:os"
import "core:sys/posix"
import "core:sys/linux"


TerminalError :: enum {
    None,
    AllreadyRaw,
    AlreadyCooked,
    SetTerminalMode,
    TcsetattrFailed,
    WinSizeFailed,
}

TerminalMode :: enum {
    Raw,
    Cooked,
}

Terminal :: struct {
    mode:     TerminalMode,
    tty:      os.Handle,
    settings: posix.termios,
    rows:     u16, // Terminal height in rows
    cols:     u16, // Terminal width in columns
}

// Add these if not defined in your posix package
winsize :: struct {
    ws_row:    u16, // rows, in characters
    ws_col:    u16, // columns, in characters
    ws_xpixel: u16, // horizontal size, pixels
    ws_ypixel: u16, // vertical size, pixels
}

TIOCGWINSZ :: 0x5413 // This value might be different on your system

init_terminal :: proc() -> (Terminal, TerminalError) {

    handle, error := os.open("/dev/tty", os.O_RDWR, 0o000)
    if error != os.ERROR_NONE {
        return {}, .TcsetattrFailed
    }

    term_inital_settings : posix.termios

    // Get current terminal settings
    if posix.tcgetattr(posix.FD(handle), &term_inital_settings) == .FAIL {
        os.close(handle)
        return {}, .TcsetattrFailed
    }
    // Get terminal size
    winsize: winsize
    if linux.ioctl(linux.Fd(handle), TIOCGWINSZ, uintptr(&winsize)) < 0 {
        os.close(handle)
        return {}, .WinSizeFailed
    }

    term := Terminal {
        mode = TerminalMode.Cooked,
        tty  = handle,
        settings = term_inital_settings,
        rows = winsize.ws_row,
        cols = winsize.ws_col,
    }

    return term, .None
}

uncook :: proc(term: ^Terminal) -> TerminalError {
    // return an error if mode is raw
    if term.mode == .Raw {
        return .AllreadyRaw
    }

    // Get a copy of the current settings
    raw := term.settings

    // Modify flag bit sets
    // Remove specific flags from the input mode
    raw.c_iflag -= {.BRKINT, .ICRNL, .INPCK, .ISTRIP, .IXON}

    // Remove the post-processing flag from output mode
    raw.c_oflag -= {.OPOST}

    // Remove specific flags from the local mode
    raw.c_lflag -= {.ECHO, .ICANON, .ISIG, .IEXTEN}

    // Modify control flags - remove character size and parity settings, then set 8-bit chars
    raw.c_cflag -= {.PARENB}
    raw.c_cflag += {.CS8}

    // Set control characters
    raw.c_cc[.VMIN] = 0
    raw.c_cc[.VTIME] = 0

    // Apply the settings
    if posix.tcsetattr(posix.FD(term.tty), .TCSAFLUSH, &raw) == .FAIL {
        return .TcsetattrFailed // You'll need to add this error type
    }

    term.mode = .Raw
    return .None
}

cook :: proc(term: ^Terminal) -> TerminalError {
    // Return an error if terminal is already in cooked mode
    if term.mode == .Cooked {
        return .AlreadyCooked
    }

    // Restore the original settings saved during initialization
    if posix.tcsetattr(posix.FD(term.tty), .TCSAFLUSH, &term.settings) == .FAIL {
        return .TcsetattrFailed
    }

    term.mode = .Cooked
    return .None
}
