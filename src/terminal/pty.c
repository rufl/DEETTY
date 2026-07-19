#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

void noctty_pty_sleep_ms(unsigned int milliseconds);

static int noctty_pty_environment_key_valid(const char *key) {
    if (key == NULL || key[0] == '\0' ||
        !((key[0] >= 'A' && key[0] <= 'Z') ||
          (key[0] >= 'a' && key[0] <= 'z') || key[0] == '_'))
        return 0;
    for (size_t index = 1; key[index] != '\0'; index++) {
        char byte = key[index];
        if (!((byte >= 'A' && byte <= 'Z') ||
              (byte >= 'a' && byte <= 'z') ||
              (byte >= '0' && byte <= '9') || byte == '_'))
            return 0;
    }
    return 1;
}

static int noctty_pty_apply_environment(const char *environment) {
    if (environment == NULL || environment[0] == '\0') return 0;
    char *copy = strdup(environment);
    if (copy == NULL) return -1;
    char *cursor = copy;
    char *entry = NULL;
    while ((entry = strsep(&cursor, ";")) != NULL) {
        char *equals = strchr(entry, '=');
        if (equals == NULL) {
            free(copy);
            return -1;
        }
        *equals = '\0';
        if (!noctty_pty_environment_key_valid(entry) ||
            setenv(entry, equals + 1, 1) != 0) {
            free(copy);
            return -1;
        }
    }
    free(copy);
    return 0;
}

int noctty_pty_spawn_profile(const char *cwd, const char *program, int kind,
                             const char *argument,
                             const char *environment, int *master_fd,
                             int *child_pid) {
    if (program == NULL || program[0] == '\0' || kind < 0 || kind > 4)
        return -1;
    if (kind != 0 &&
        (argument == NULL || argument[0] == '\0'))
        return -1;
    int master = posix_openpt(O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (master < 0) return -1;
    if (grantpt(master) != 0 || unlockpt(master) != 0) {
        close(master);
        return -1;
    }

    char *slave_name = ptsname(master);
    if (slave_name == NULL) {
        close(master);
        return -1;
    }
    int slave = open(slave_name, O_RDWR | O_NOCTTY);
    if (slave < 0) {
        close(master);
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(slave);
        close(master);
        return -1;
    }
    if (pid == 0) {
        if (setsid() < 0) _exit(127);
        if (ioctl(slave, TIOCSCTTY, 0) < 0) _exit(127);
        if (dup2(slave, STDIN_FILENO) < 0 || dup2(slave, STDOUT_FILENO) < 0 ||
            dup2(slave, STDERR_FILENO) < 0)
            _exit(127);
        if (slave > STDERR_FILENO) close(slave);
        close(master);
        if (cwd != NULL && cwd[0] != '\0' && chdir(cwd) != 0) _exit(127);
        if (noctty_pty_apply_environment(environment) != 0 ||
            setenv("TERM", "xterm-256color", 1) != 0 ||
            setenv("COLORTERM", "truecolor", 1) != 0)
            _exit(127);
        if (kind == 0)
            execl(program, program, "-i", (char *)NULL);
        else if (kind == 1)
            execl(program, program, "-lc", argument, (char *)NULL);
        else if (kind == 2)
            execlp("ssh", "ssh", argument, (char *)NULL);
        else if (kind == 3)
            execlp("tmux", "tmux", "new-session", "-A", "-s", argument,
                   (char *)NULL);
        else
            execlp("zellij", "zellij", "attach", "--create", argument,
                   (char *)NULL);
        _exit(127);
    }

    close(slave);
    *master_fd = master;
    *child_pid = (int)pid;
    return 0;
}

int noctty_pty_spawn(const char *cwd, const char *shell, int *master_fd,
                     int *child_pid) {
    return noctty_pty_spawn_profile(cwd, shell, 0, "", "", master_fd,
                                    child_pid);
}

ssize_t noctty_pty_read(int fd, void *buffer, size_t length) {
    ssize_t result = read(fd, buffer, length);
    if (result < 0 && errno == EIO) return 0;
    if (result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) return -2;
    return result;
}

ssize_t noctty_pty_write(int fd, const void *buffer, size_t length) {
    ssize_t result = write(fd, buffer, length);
    if (result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) return -2;
    return result;
}

int noctty_pty_resize(int fd, unsigned short rows, unsigned short columns,
                      unsigned int width_px, unsigned int height_px) {
    struct winsize size = {
        .ws_row = rows,
        .ws_col = columns,
        .ws_xpixel = width_px,
        .ws_ypixel = height_px,
    };
    return ioctl(fd, TIOCSWINSZ, &size);
}

int noctty_pty_poll_exit(int child_pid, int *exit_code) {
    int status = 0;
    pid_t result = waitpid((pid_t)child_pid, &status, WNOHANG);
    if (result == 0) return 0;
    if (result < 0) return -1;
    if (WIFEXITED(status)) {
        *exit_code = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        *exit_code = 128 + WTERMSIG(status);
    } else {
        *exit_code = 255;
    }
    return 1;
}

int noctty_pty_has_foreground_process(int fd, int child_pid) {
    if (fd < 0 || child_pid <= 0) return 0;
    pid_t foreground = tcgetpgrp(fd);
    if (foreground <= 0) return 0;
    return foreground != (pid_t)child_pid;
}

static ssize_t noctty_pty_read_proc_link(pid_t pid, const char *leaf,
                                         char *output, size_t capacity) {
    if (pid <= 0 || output == NULL || capacity == 0) return -1;
    char path[64];
    int length = snprintf(path, sizeof(path), "/proc/%ld/%s", (long)pid,
                          leaf);
    if (length <= 0 || (size_t)length >= sizeof(path)) return -1;
    return readlink(path, output, capacity);
}

static ssize_t noctty_pty_read_proc_file(pid_t pid, const char *leaf,
                                         char *output, size_t capacity) {
    if (pid <= 0 || output == NULL || capacity == 0) return -1;
    char path[64];
    int length = snprintf(path, sizeof(path), "/proc/%ld/%s", (long)pid,
                          leaf);
    if (length <= 0 || (size_t)length >= sizeof(path)) return -1;
    int proc_fd = open(path, O_RDONLY | O_CLOEXEC);
    if (proc_fd < 0) return -1;
    ssize_t result = read(proc_fd, output, capacity);
    close(proc_fd);
    while (result > 0 &&
           (output[result - 1] == '\n' || output[result - 1] == '\r'))
        result--;
    return result;
}

static int noctty_pty_process_group_alive(pid_t process_group,
                                           pid_t own_group) {
    if (process_group <= 1 || process_group == own_group) return 0;
    if (kill(-process_group, 0) == 0) return 1;
    return errno == EPERM;
}

int noctty_pty_process_info(int fd, int child_pid, char *cwd,
                            size_t cwd_capacity, size_t *cwd_length,
                            char *name, size_t name_capacity,
                            size_t *name_length, int *process_pid) {
    if (cwd_length == NULL || name_length == NULL || process_pid == NULL)
        return 0;
    *cwd_length = 0;
    *name_length = 0;
    *process_pid = child_pid;
    if (fd < 0 || child_pid <= 0) return 0;

    pid_t foreground = tcgetpgrp(fd);
    if (foreground <= 0) foreground = (pid_t)child_pid;
    *process_pid = (int)foreground;

    ssize_t cwd_result = noctty_pty_read_proc_link(
        foreground, "cwd", cwd, cwd_capacity);
    if (cwd_result < 0 && foreground != (pid_t)child_pid)
        cwd_result = noctty_pty_read_proc_link(
            (pid_t)child_pid, "cwd", cwd, cwd_capacity);
    if (cwd_result > 0) *cwd_length = (size_t)cwd_result;

    ssize_t name_result = noctty_pty_read_proc_file(
        foreground, "comm", name, name_capacity);
    if (name_result <= 0 && foreground != (pid_t)child_pid)
        name_result = noctty_pty_read_proc_file(
            (pid_t)child_pid, "comm", name, name_capacity);
    if (name_result > 0) *name_length = (size_t)name_result;

    return (*cwd_length > 0 ? 1 : 0) | (*name_length > 0 ? 2 : 0);
}

static int noctty_process_stat(pid_t pid, unsigned long long *ticks,
                               unsigned long long *rss_kib) {
    char stat[4096];
    ssize_t stat_length = noctty_pty_read_proc_file(
        pid, "stat", stat, sizeof(stat) - 1);
    if (stat_length <= 0) return 0;
    stat[stat_length] = '\0';
    char *fields = strrchr(stat, ')');
    if (fields == NULL || fields[1] != ' ') return 0;
    fields += 2;
    char *save = NULL;
    char *field = strtok_r(fields, " ", &save);
    unsigned int number = 3;
    unsigned long long user_ticks = 0;
    unsigned long long system_ticks = 0;
    while (field != NULL && number <= 15) {
        if (number == 14) user_ticks = strtoull(field, NULL, 10);
        if (number == 15) system_ticks = strtoull(field, NULL, 10);
        field = strtok_r(NULL, " ", &save);
        number++;
    }

    char statm[256];
    ssize_t statm_length = noctty_pty_read_proc_file(
        pid, "statm", statm, sizeof(statm) - 1);
    if (statm_length <= 0) return 0;
    statm[statm_length] = '\0';
    unsigned long long ignored_pages = 0;
    unsigned long long resident_pages = 0;
    if (sscanf(statm, "%llu %llu", &ignored_pages, &resident_pages) != 2)
        return 0;
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) return 0;
    *ticks = user_ticks + system_ticks;
    *rss_kib = resident_pages * (unsigned long long)page_size / 1024ULL;
    return 1;
}

int noctty_process_resource_sample(
    int root_pid, unsigned long long *ticks, unsigned long long *rss_kib,
    unsigned int *processes, unsigned long long *machine_ticks,
    unsigned int *cpu_count) {
    if (ticks == NULL || rss_kib == NULL || processes == NULL ||
        machine_ticks == NULL || cpu_count == NULL)
        return 0;
    pid_t root = root_pid > 0 ? (pid_t)root_pid : getpid();
    pid_t queue[4096]; /* ponytail: bounded /proc walk; raise if 4096 descendants becomes real. */
    size_t head = 0;
    size_t tail = 1;
    queue[0] = root;
    *ticks = 0;
    *rss_kib = 0;
    *processes = 0;

    while (head < tail) {
        pid_t pid = queue[head++];
        unsigned long long process_ticks = 0;
        unsigned long long process_rss_kib = 0;
        if (!noctty_process_stat(pid, &process_ticks, &process_rss_kib))
            continue;
        *ticks += process_ticks;
        *rss_kib += process_rss_kib;
        (*processes)++;

        char children[8192];
        char path[96];
        int path_length = snprintf(path, sizeof(path),
            "/proc/%ld/task/%ld/children", (long)pid, (long)pid);
        if (path_length <= 0 || (size_t)path_length >= sizeof(path)) continue;
        int fd = open(path, O_RDONLY | O_CLOEXEC);
        if (fd < 0) continue;
        ssize_t length = read(fd, children, sizeof(children) - 1);
        close(fd);
        if (length <= 0) continue;
        children[length] = '\0';
        char *cursor = children;
        while (*cursor != '\0' && tail < sizeof(queue) / sizeof(queue[0])) {
            while (*cursor == ' ' || *cursor == '\n') cursor++;
            if (*cursor == '\0') break;
            char *end = NULL;
            long child = strtol(cursor, &end, 10);
            if (end == cursor) break;
            if (child > 0) queue[tail++] = (pid_t)child;
            cursor = end;
        }
    }

    char machine[4096];
    int machine_fd = open("/proc/stat", O_RDONLY | O_CLOEXEC);
    if (machine_fd < 0) return 0;
    ssize_t machine_length = read(machine_fd, machine, sizeof(machine) - 1);
    close(machine_fd);
    if (machine_length <= 0) return 0;
    machine[machine_length] = '\0';
    unsigned long long values[10] = {0};
    int parsed = sscanf(machine,
        "cpu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu",
        &values[0], &values[1], &values[2], &values[3], &values[4],
        &values[5], &values[6], &values[7], &values[8], &values[9]);
    if (parsed < 4) return 0;
    *machine_ticks = 0;
    for (int index = 0; index < parsed; index++) *machine_ticks += values[index];
    long online_cpus = sysconf(_SC_NPROCESSORS_ONLN);
    *cpu_count = online_cpus > 0 ? (unsigned int)online_cpus : 1U;
    return *processes > 0;
}

void noctty_pty_close(int fd, int child_pid) {
    pid_t foreground = fd >= 0 ? tcgetpgrp(fd) : -1;
    pid_t own_group = getpgrp();
    int foreground_alive = noctty_pty_process_group_alive(foreground,
                                                           own_group);
    if (foreground_alive)
        (void)kill(-foreground, SIGHUP);
    if (fd >= 0) close(fd);
    if (child_pid > 0) {
        int status = 0;
        pid_t result = waitpid((pid_t)child_pid, &status, WNOHANG);
        int child_running = result == 0;
        int shell_group_alive = noctty_pty_process_group_alive(
            (pid_t)child_pid, own_group);
        if (child_running || shell_group_alive) {
            (void)kill(-(pid_t)child_pid, SIGHUP);
        }
        if (child_running) {
            (void)kill((pid_t)child_pid, SIGHUP);
        }
        for (int attempt = 0; attempt < 50; attempt++) {
            foreground_alive = noctty_pty_process_group_alive(foreground,
                                                               own_group);
            shell_group_alive = noctty_pty_process_group_alive(
                (pid_t)child_pid, own_group);
            if (!child_running && !foreground_alive && !shell_group_alive)
                break;
            noctty_pty_sleep_ms(10);
            if (child_running) {
                result = waitpid((pid_t)child_pid, &status, WNOHANG);
                child_running = result == 0;
            }
        }
        foreground_alive = noctty_pty_process_group_alive(foreground,
                                                           own_group);
        shell_group_alive = noctty_pty_process_group_alive(
            (pid_t)child_pid, own_group);
        if (child_running || foreground_alive || shell_group_alive) {
            if (foreground_alive) (void)kill(-foreground, SIGKILL);
            if (shell_group_alive)
                (void)kill(-(pid_t)child_pid, SIGKILL);
            if (child_running) (void)kill((pid_t)child_pid, SIGKILL);
        }
        if (child_running) {
            (void)waitpid((pid_t)child_pid, &status, 0);
        }
    }
}

void noctty_pty_sleep_ms(unsigned int milliseconds) {
    struct timespec duration = {
        .tv_sec = (time_t)(milliseconds / 1000),
        .tv_nsec = (long)((milliseconds % 1000) * 1000000U),
    };
    nanosleep(&duration, NULL);
}
