package ocurses

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:time"
import "core:unicode/utf8"

ScreenError :: enum {
    NONE,
    INVALID_PARAMETER,
}

Screen :: struct {
    term:            ^Terminal,
    using_alternate: bool,
}

// Initialize a new screen using the provided terminal
init_screen :: proc(term: ^Terminal) -> Screen {
    screen := Screen {
        term            = term,
        using_alternate = false,
    }

    return screen
}

// Switch to the alternate screen buffer
enter_alternate_screen :: proc(screen: ^Screen) -> os.Errno {
    if screen.using_alternate {
        return os.ERROR_NONE
    }

    // ANSI escape sequence to enter alternate screen
    alt_screen_cmd := "\x1b[?1049h"
    _, err := os.write(screen.term.tty, transmute([]u8)alt_screen_cmd)
    if err != os.ERROR_NONE {
        return err
    }

    screen.using_alternate = true
    return os.ERROR_NONE
}

// Return to the main screen buffer
exit_alternate_screen :: proc(screen: ^Screen) -> os.Errno {
    if !screen.using_alternate {
        return os.ERROR_NONE
    }

    // ANSI escape sequence to exit alternate screen
    main_screen_cmd := "\x1b[?1049l"
    _, err := os.write(screen.term.tty, transmute([]u8)main_screen_cmd)
    if err != os.ERROR_NONE {
        return err
    }

    screen.using_alternate = false
    return os.ERROR_NONE
}

// Clear the current screen
clear_screen :: proc(screen: ^Screen) -> os.Errno {
    // ANSI escape sequence to clear screen and reset cursor
    clear_cmd := "\x1b[2J\x1b[H"
    _, err := os.write(screen.term.tty, transmute([]u8)clear_cmd)
    return err
}

// Move cursor to a specific position (1-based coordinates)
move_cursor :: proc(screen: ^Screen, row, col: int) -> os.Errno {
    // Ensure coordinates are within bounds
    row_val := max(1, min(row, int(screen.term.rows)))
    col_val := max(1, min(col, int(screen.term.cols)))

    // ANSI escape sequence to move cursor
    cursor_cmd := fmt.tprintf("\x1b[%d;%dH", row_val, col_val)
    _, err := os.write(screen.term.tty, transmute([]u8)cursor_cmd)
    return err
}

// Print text at current cursor position
print :: proc(screen: ^Screen, text: string) -> os.Errno {
    _, err := os.write(screen.term.tty, transmute([]u8)text)
    return err
}

// Print text at specified position
print_at :: proc(screen: ^Screen, row, col: int, text: string) -> os.Errno {
    if err := move_cursor(screen, row, col); err != os.ERROR_NONE {
        return err
    }

    return print(screen, text)
}

// Display terminal information at the top of the screen
display_term_info :: proc(screen: ^Screen) -> os.Errno {
    if err := clear_screen(screen); err != os.ERROR_NONE {
        return err
    }

    info_text := fmt.tprintf(
        "Terminal Size: %d rows x %d columns | Mode: %s | Alternate Screen: %t",
        screen.term.rows,
        screen.term.cols,
        screen.term.mode == .Raw ? "Raw" : "Cooked",
        screen.using_alternate,
    )

    return print_at(screen, 1, 1, info_text)
}

// Set text attributes using ANSI escape sequences
TextAttribute :: enum {
    Reset     = 0,
    Bold      = 1,
    Dim       = 2,
    Italic    = 3,
    Underline = 4,
    Blink     = 5,
    Reverse   = 7,
    Hidden    = 8,
}

TextColor :: enum {
    Black         = 30,
    Red           = 31,
    Green         = 32,
    Yellow        = 33,
    Blue          = 34,
    Magenta       = 35,
    Cyan          = 36,
    White         = 37,
    Default       = 39,
    BrightBlack   = 90,
    BrightRed     = 91,
    BrightGreen   = 92,
    BrightYellow  = 93,
    BrightBlue    = 94,
    BrightMagenta = 95,
    BrightCyan    = 96,
    BrightWhite   = 97,
}

BackgroundColor :: enum {
    Black         = 40,
    Red           = 41,
    Green         = 42,
    Yellow        = 43,
    Blue          = 44,
    Magenta       = 45,
    Cyan          = 46,
    White         = 47,
    Default       = 49,
    BrightBlack   = 100,
    BrightRed     = 101,
    BrightGreen   = 102,
    BrightYellow  = 103,
    BrightBlue    = 104,
    BrightMagenta = 105,
    BrightCyan    = 106,
    BrightWhite   = 107,
}

// Set text attributes
set_attr :: proc(screen: ^Screen, attr: TextAttribute) -> os.Errno {
    cmd := fmt.tprintf("\x1b[%dm", int(attr))
    _, err := os.write(screen.term.tty, transmute([]u8)cmd)
    return err
}

// Set text foreground color
set_fg_color :: proc(screen: ^Screen, color: TextColor) -> os.Errno {
    cmd := fmt.tprintf("\x1b[%dm", int(color))
    _, err := os.write(screen.term.tty, transmute([]u8)cmd)
    return err
}

// Set text background color
set_bg_color :: proc(screen: ^Screen, color: BackgroundColor) -> os.Errno {
    cmd := fmt.tprintf("\x1b[%dm", int(color))
    _, err := os.write(screen.term.tty, transmute([]u8)cmd)
    return err
}

// For the horizontal and vertical line drawing functions:
draw_horizontal_line :: proc(screen: ^Screen, row, start_col, end_col: int, char: rune = '─') -> os.Errno {
    if end_col <= start_col || start_col < 1 || end_col > int(screen.term.cols) {
        return os.EINVAL
    }

    // Convert rune to string properly
    char_str := utf8.runes_to_string([]rune{char})
    defer delete(char_str)

    // Create the line by repeating the character
    line := strings.repeat(char_str, end_col - start_col + 1)
    defer delete(line)

    return print_at(screen, row, start_col, line)
}

// Similarly for draw_vertical_line:
draw_vertical_line :: proc(screen: ^Screen, col, start_row, end_row: int, char: rune = '│') -> os.Errno {
    if end_row <= start_row || start_row < 1 || end_row > int(screen.term.rows) {
        return os.EINVAL
    }

    // Convert rune to string properly
    char_str := utf8.runes_to_string([]rune{char})
    defer delete(char_str)

    for row := start_row; row <= end_row; row += 1 {
        if err := print_at(screen, row, col, char_str); err != os.ERROR_NONE {
            return err
        }
    }

    return os.ERROR_NONE
} // Draw a box with borders
draw_box :: proc(screen: ^Screen, top_row, left_col, bottom_row, right_col: int, title: string = "") -> os.Errno {
    if err := draw_horizontal_line(screen, top_row, left_col + 1, right_col - 1); err != os.ERROR_NONE {
        return err
    }

    if err := draw_horizontal_line(screen, bottom_row, left_col + 1, right_col - 1); err != os.ERROR_NONE {
        return err
    }

    if err := draw_vertical_line(screen, left_col, top_row + 1, bottom_row - 1); err != os.ERROR_NONE {
        return err
    }

    if err := draw_vertical_line(screen, right_col, top_row + 1, bottom_row - 1); err != os.ERROR_NONE {
        return err
    }

    // Draw corners
    if err := print_at(screen, top_row, left_col, "┌"); err != os.ERROR_NONE {
        return err
    }
    if err := print_at(screen, top_row, right_col, "┐"); err != os.ERROR_NONE {
        return err
    }
    if err := print_at(screen, bottom_row, left_col, "└"); err != os.ERROR_NONE {
        return err
    }
    if err := print_at(screen, bottom_row, right_col, "┘"); err != os.ERROR_NONE {
        return err
    }

    // Add title if provided
    if len(title) > 0 {
        title_pos := left_col + 2
        title_display := fmt.tprintf(" %s ", title)
        if title_pos + len(title_display) < right_col {
            print_at(screen, top_row, title_pos, title_display)
        }
    }

    return os.ERROR_NONE
}

// Initialize screen and terminal
create_screen :: proc() -> (Screen, TerminalError) {
    term, err := init_terminal()
    if err != .None {
        return {}, err
    }

    screen := init_screen(&term)

    // Set terminal to raw mode
    if err_raw := uncook(&term); err_raw != .None {
        return {}, err_raw
    }

    return screen, .None
}

// Clean up and exit
destroy_screen :: proc(screen: ^Screen) {
    if screen.using_alternate {
        exit_alternate_screen(screen)
    }

    // Restore terminal to cooked mode
    if screen.term.mode == .Raw {
        cook(screen.term)
    }

    // Close TTY
    os.close(screen.term.tty)
}

// Key event structure
KeyEvent :: struct {
    key:        rune,
    is_special: bool, // True for special keys like arrows, function keys, etc.
    ctrl:       bool, // True if Ctrl modifier was pressed
    alt:        bool, // True if Alt modifier was pressed
}

// Process input in a loop with optional timeout
read_input_loop :: proc(
    screen: ^Screen,
    process_key: proc(event: KeyEvent) -> bool,
    timeout_ms: int = -1,
) -> os.Errno {
    should_continue := true
    buffer: [32]u8

    // Setup for timeout if needed
    start_time := time.now()

    for should_continue {
        // Try to read available input
        bytes_read, err := os.read(screen.term.tty, buffer[:])

        if err != os.ERROR_NONE && err != os.EAGAIN && err != os.EWOULDBLOCK {
            // Real error occurred
            return err
        }

        // Process any input we received
        if bytes_read > 0 {
            // Simple single-character processing
            // For complex escape sequences, you would need more sophisticated parsing
            event: KeyEvent

            // Very simple handling of special keys and modifiers
            if bytes_read == 1 {
                // Single byte - regular character or control character
                if buffer[0] < 32 {
                    // Control character
                    event = KeyEvent {
                        key        = rune(buffer[0] + 64), // Convert to readable letter
                        is_special = false,
                        ctrl       = true,
                        alt        = false,
                    }
                } else {
                    // Regular character
                    event = KeyEvent {
                        key        = rune(buffer[0]),
                        is_special = false,
                        ctrl       = false,
                        alt        = false,
                    }
                }
            } else if bytes_read >= 3 && buffer[0] == 0x1b && buffer[1] == 0x5b {
                // Very simple escape sequence handling (arrow keys, etc.)
                // This is a simplified approach and doesn't handle all cases
                event = KeyEvent {
                    key        = rune(buffer[2]),
                    is_special = true,
                    ctrl       = false,
                    alt        = false,
                }
            } else if bytes_read >= 2 && buffer[0] == 0x1b {
                // Alt + character
                event = KeyEvent {
                    key        = rune(buffer[1]),
                    is_special = false,
                    ctrl       = false,
                    alt        = true,
                }
            }

            // Process the key and check if we should continue
            should_continue = process_key(event)
        } else {
            // No input available, check timeout
            if timeout_ms >= 0 {
                elapsed := time.diff(start_time, time.now())
                if elapsed >= time.Duration(timeout_ms) * time.Millisecond {
                    break
                }
            }

            // Sleep a tiny bit to avoid hogging CPU
            time.sleep(10 * time.Millisecond)
        }
    }

    return os.ERROR_NONE
}

example_input_loop :: proc() -> TerminalError {
    screen, err := create_screen()
    if err != .None {
        return err
    }
    defer destroy_screen(&screen)

    // Enter alternate screen and clear it
    // enter_alternate_screen(&screen)
    // clear_screen(&screen)

    // Draw a simple UI
    draw_box(&screen, 1, 1, int(screen.term.rows), int(screen.term.cols), "Input Test")
    print_at(&screen, 3, 3, "Press keys (ESC to quit, arrows and other special keys are supported)")
    print_at(&screen, 5, 3, "Last key: ")

    // Define key processing function
    process_key :: proc(event: KeyEvent) -> bool {
        // Get access to screen
        screen := cast(^Screen)context.user_ptr

        // Clear the key display area
        print_at(screen, 5, 13, "                                        ")

        // Display information about the pressed key
        if event.is_special {
            print_at(screen, 5, 13, fmt.tprintf("Special: %d", int(event.key)))
        } else {
            key_info := fmt.tprintf("'%c' (%d)", event.key, int(event.key))
            if event.ctrl {
                key_info = fmt.tprintf("Ctrl+%s", key_info)
            }
            if event.alt {
                key_info = fmt.tprintf("Alt+%s", key_info)
            }
            print_at(screen, 5, 13, key_info)
        }

        // Quit on ESC
        return event.key != 27 || event.is_special
    }

    // Set up context for the callback
    context.user_ptr = &screen

    // Run the input loop until ESC is pressed
    read_input_loop(&screen, process_key)

    return .None
}
