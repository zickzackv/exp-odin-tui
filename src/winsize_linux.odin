package ocurses

import "core:sys/linux"

TIOCGWINSZ :: 0x5413

get_terminal_winsize :: proc() -> (rows: u16, cols: u16, ok: bool) {
    ws: winsize
    fd := 1 // STDOUT_FILENO
    // Linux syscall
    result := linux.syscall(
        16, // SYS_ioctl on Linux
        uintptr(fd),
        uintptr(TIOCGWINSZ),
        uintptr(&ws),
    )

    if result == 0 {
        return ws.ws_row, ws.ws_col, true
    }
    return 0, 0, false
}
