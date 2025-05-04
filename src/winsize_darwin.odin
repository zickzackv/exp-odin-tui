package ocurses

import "base:intrinsics"

TIOCGWINSZ :: 0x40087468 // macOS value

get_terminal_winsize :: proc() -> (rows: u16, cols: u16, ok: bool) {
    ws: winsize
    fd := 1 // STDOUT_FILENO
    // macOS syscall
    result := intrinsics.syscall(
        116, // SYS_ioctl on macOS
        uintptr(fd),
        uintptr(TIOCGWINSZ),
        uintptr(&ws),
    )

    if result == 0 {
        return ws.ws_row, ws.ws_col, true
    }
    return 0, 0, false
}
