from memory import memcpy, Span

struct LogLevel():
    alias FATAL = 0
    alias ERROR = 1
    alias WARN = 2
    alias INFO = 3
    alias DEBUG = 4


@value
struct Logger():
    var level: Int

    fn __init__(out self, level: Int = LogLevel.INFO):
        self.level = level

    fn _log_message(self, message: String, level: Int):
        if self.level >= level:
            if level < LogLevel.WARN:
                print(message, file=2)
            else:
                print(message)

    fn info[*Ts: Writable](self, *messages: *Ts):
        var msg = String.write("\033[36mINFO\033[0m  - ")
        @parameter
        fn write_message[T: Writable](message: T):
            msg.write(message, " ")
        messages.each[write_message]()
        self._log_message(msg, LogLevel.INFO)

    fn warn[*Ts: Writable](self, *messages: *Ts):
        var msg = String.write("\033[33mWARN\033[0m  - ")
        @parameter
        fn write_message[T: Writable](message: T):
            msg.write(message, " ")
        messages.each[write_message]()
        self._log_message(msg, LogLevel.WARN)

    fn error[*Ts: Writable](self, *messages: *Ts):
        var msg = String.write("\033[31mERROR\033[0m - ")
        @parameter
        fn write_message[T: Writable](message: T):
            msg.write(message, " ")
        messages.each[write_message]()
        self._log_message(msg, LogLevel.ERROR)

    fn debug[*Ts: Writable](self, *messages: *Ts):
        var msg = String.write("\033[34mDEBUG\033[0m - ")
        @parameter
        fn write_message[T: Writable](message: T):
            msg.write(message, " ")
        messages.each[write_message]()
        self._log_message(msg, LogLevel.DEBUG)

    fn fatal[*Ts: Writable](self, *messages: *Ts):
        var msg = String.write("\033[35mFATAL\033[0m - ")
        @parameter
        fn write_message[T: Writable](message: T):
            msg.write(message, " ")
        messages.each[write_message]()
        self._log_message(msg, LogLevel.FATAL)


alias logger = Logger()
