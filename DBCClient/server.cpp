/**
 * @file server.cpp - for Linux
 * @brief A multi-threaded server for handling CAN bus message scheduling and client commands over TCP sockets.
 *
 * This server application reads configuration from a file (port and log level), sets up a TCP listener,
 * and accepts client connections. Each client connection is handled in a separate thread, where commands
 * are processed to schedule recurring CAN message sends using a thread pool with deadline-based priority queuing.
 * Supported commands include SHUTDOWN, KILL_ALL, LIST_THREADS, RESTART, KILL_THREAD, SET_LOG_LEVEL,
 * PAUSE, RESUME, LIST_TASKS, KILL_TASK, KILL_ALL_TASKS, and cansend for scheduling CAN messages.
 *
 * The server uses a custom ThreadPool for task management, a ThreadRegistry for tracking active threads,
 * and logs events to a file based on configurable log levels.
 *
 * @note This is part of the DBCFileViewer_Client project by Team Qt (cute) Devs.
 * @todo Add license information, improve logging levels, implement candump-like features,
 *       verify thread registration, update frontend info messages, enhance config file error handling,
 *       add server restart from client, implement client window for server log viewing,
 *       and improve timer accuracy for sending.
 *
 * @param argc Number of command-line arguments (expected: 2, including program name and config file).
 * @param argv Command-line arguments: argv[1] should be the path to the configuration file.
 * @return 0 on successful execution, non-zero on error.
 *
 * Configuration file format:
 * - PORT=<port_number> : Sets the listening port.
 * - LOG_LEVEL=<level> : Sets log level (DEBUG, INFO, WARNING, ERROR).
 *
 * Client commands:
 * - SHUTDOWN : Gracefully shuts down the client connection.
 * - KILL_ALL : Terminates all processes spawned by the client.
 * - LIST_THREADS : Lists active threads.
 * - RESTART : Placeholder for server restart (not implemented).
 * - KILL_THREAD <thread_id> : Removes a thread from the registry.
 * - SET_LOG_LEVEL <level> : Changes the global log level.
 * - PAUSE <task_id> : Pauses a scheduled task.
 * - RESUME <task_id> : Resumes a paused task.
 * - LIST_TASKS : Lists active tasks with status.
 * - KILL_TASK <task_id> : Stops and removes a task.
 * - KILL_ALL_TASKS : Stops all tasks.
 * - cansend <interface> <id#data> <time_ms> [priority] : Schedules recurring CAN message sends.
 *
 * Dependencies: Requires CAN utilities (e.g., cansend command), POSIX threads, sockets.
 * Thread safety: Uses mutexes for shared data structures like ThreadRegistry and ThreadPool.
 */
/*

Todo: add license stuff, maybe add candump-like features to ui
add resource monitoring to send to client ui
//update frontend info "message" <- forgot what I meant here
maybe add (automatic and manual) check for all busses available to system and send message to client

deadline doesn't seem to work with precision. effectively just sleep

bus goes in config file
status at the end
if checking for dead task (LIST_TASKS/UPDATE), return something useful
if trying to pause/resume/kill a non-existent task, return something useful

//add feature to restart server from client
add client window for server log viewing
handle cansend errors
add error handling for wrong port used when connecting client in ui

polish:
make sending timer more accurate
*/


#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <string>
#include <cstring>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#include <signal.h>
#include <cerrno>
#include <system_error>
#include <fstream>
#include <algorithm>
#include <array>
#include <optional>
#include <filesystem>
#include <format>
#include <thread>
#include <chrono>
#include <mutex>
#include <vector>
#include <queue>
#include <functional>
#include <condition_variable>
#include <atomic>
#include <sstream>
#include <unordered_map>

#define BACKLOG 10
#define MAXDATASIZE 10000

// config file variables. parsed in main
int port = 0;
std::string log_level_str = "ERROR"; // ERROR by default but overwritten by config file
int log_level = 30; //INFO == 10, WARNING == 20, ERROR == 30, DEBUG == 5
const int INFO = 10;
const int WARNING = 20;
const int ERROR = 30;
const int DEBUG = 5;

// Helper function to trim whitespace and invisible characters from string
std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n\f\v");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\r\n\f\v");
    return str.substr(first, last - first + 1);
}

struct ThreadInfo {
    std::thread::id id;
    std::string name;
    std::string status;
    std::chrono::high_resolution_clock::time_point start_time;  // Changed from steady_clock
};

/**
 * @brief A thread-safe registry for managing active threads.
 *
 * The ThreadRegistry class provides a mechanism to track and manage information
 * about active threads in a multi-threaded application. It stores details such as
 * thread ID, name, status, and start time for each registered thread. All operations
 * are protected by a mutex to ensure thread safety.
 *
 * Key features:
 * - Add a new thread to the registry with its ID and name.
 * - Remove a thread from the registry by its ID.
 * - Print the list of active threads to standard output.
 * - Generate a string representation of the active threads.
 *
 * @note This class uses std::vector to store ThreadInfo objects and std::mutex for synchronization.
 *       It relies on std::chrono for timing and std::thread for thread IDs.
 */
class ThreadRegistry {
private:
    std::vector<ThreadInfo> threads;
    std::mutex mtx;

public:
    void add(const std::thread::id& id, const std::string& name) {
        std::lock_guard<std::mutex> lock(mtx);
        ThreadInfo info;
        info.id = id;
        info.name = name;
        info.status = "running";
        info.start_time = std::chrono::high_resolution_clock::now();  // Changed from steady_clock
        threads.push_back(info);
    }

    void remove(const std::thread::id& id) {
        std::lock_guard<std::mutex> lock(mtx);
        threads.erase(
            std::remove_if(threads.begin(), threads.end(),
                           [&id](const ThreadInfo& t) { return t.id == id; }),
            threads.end()
        );
    }

    void print() {
        std::lock_guard<std::mutex> lock(mtx);
        std::cout << "Active threads:\n";
        for (const auto& t : threads)
            std::cout << "  " << t.id << " (" << t.name << ")\n";
    }

    std::string toString() {
        std::lock_guard<std::mutex> lock(mtx);
        std::ostringstream oss;
        oss << "Active threads:\n";
        for (const auto& t : threads)
            oss << "  " << t.id << " (" << t.name << ")\n";
        return oss.str();
    }
};

// Global registry
ThreadRegistry registry;

// Global map to track PIDs to task IDs for error handling
std::unordered_map<pid_t, std::string> globalPidToTaskId;
std::mutex globalPidMutex;  // Protect the global map

// Add a new global map for task error messages
std::unordered_map<std::string, std::string> globalTaskErrors;
std::mutex globalErrorMutex;

// Signal handler for SIGCHLD - now only for logging, reaping handled in client threads
void sigchld_handler(int s) {
    (void)s;
    /* // Removed waitpid loop to avoid conflicts
    int saved_errno = errno;
    int status;
    pid_t pid;
    while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
        if (WIFEXITED(status)) {
            int exit_code = WEXITSTATUS(status);
            if (exit_code != 0) {
                logEvent(ERROR, "Child process " + std::to_string(pid) + " exited with error code " + std::to_string(exit_code));
            } else {
                logEvent(DEBUG, "Child process " + std::to_string(pid) + " exited successfully");
            }
        } else if (WIFSIGNALED(status)) {
            int signal_num = WTERMSIG(status);
            logEvent(ERROR, "Child process " + std::to_string(pid) + " terminated by signal " + std::to_string(signal_num));
        }
        // Optionally, remove PID from clientPids if tracked globally (but it's per-client)
    }
    errno = saved_errno;
    */
}

// Get sockaddr, IPv4 or IPv6
void* get_in_addr(struct sockaddr* sa) {
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }
    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

// Log events with timestamp
void logEvent(int level, const std::string& message) { //logging with hierarchy
    if (level < log_level) {
        return; // Skip logging if message severity is below configured log_level
    }
    std::ofstream log("server.log", std::ios::app);
    auto now = std::chrono::system_clock::now();  // Unchanged (system_clock for timestamps)
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    log << "[" << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d %H:%M:%S") << "] [" << level << "] " << message << std::endl;
}

/**
 * @class ThreadPool
 * @brief A thread pool implementation that manages a fixed number of worker threads to execute tasks asynchronously.
 *
 * The ThreadPool uses a priority queue to schedule tasks based on deadlines and a priority number for FIFO ordering.
 * Tasks can be enqueued with or without priorities. Deadlines are like timers. If a task has a deadline, it will be executed as soon as possible after the deadline,
 * or can be discarded if the deadline is missed and drop_if_missed is true. Priorities determine execution order when deadlines are equal
 * (higher priority runs first). For tasks with the same deadline and priority, FIFO order is preserved.
 * 
 * The thread pool automatically registers worker threads with a Thread registry for identification.
 * 
 * @note The number of threads defaults to std::thread::hardware_concurrency(), but is clamped to at least 1.
 * @note Tasks are executed in worker threads, and exceptions in task functions are caught and ignored.
 * @note The destructor ensures all threads are joined after signaling them to stop.
 */
class ThreadPool {
public:
    explicit ThreadPool(size_t n = std::thread::hardware_concurrency()) : stop(false), seq(0) {
        if (n == 0) n = 1;
        for (size_t i = 0; i < n; ++i) {
            threads.emplace_back([this] {
                registry.add(std::this_thread::get_id(), "thread pool worker");  // Add to registry
                for (;;) {
                    Task task;
                    {
                        std::unique_lock<std::mutex> lock(this->mtx);
                        while (!stop) {
                            if (!pq.empty()) {
                                auto next_deadline = pq.top().deadline;
                                auto now = std::chrono::high_resolution_clock::now();  // Changed from steady_clock
                                if (next_deadline <= now) {
                                    // Execute task immediately
                                    task = std::move(pq.top());
                                    pq.pop();
                                    lock.unlock();
                                    try { task.func(); } catch (...) { /* handle */ }
                                    lock.lock();
                                } else {
                                    // Wait until deadline or new task
                                    cv.wait_until(lock, next_deadline);
                                    // Loop again to recheck
                                }
                            } else {
                                cv.wait(lock);  // Wait for new tasks
                            }
                        }
                    }
                }
            });
        }
    }

    // Enqueue a normal (no-deadline) task with optional priority (higher = run earlier when deadlines tie)
    template <class F>
    void enqueue(int priority, F&& f) {
        enqueue_impl(std::chrono::high_resolution_clock::time_point::max(), priority, false, std::forward<F>(f));
    }

    // Enqueue with an absolute deadline (high_resolution_clock::time_point). If drop_if_missed==true the task
    // will be discarded if the worker picks it up after the deadline has passed.
    template <class F>
    void enqueue_deadline(std::chrono::high_resolution_clock::time_point deadline,  // Changed from steady_clock
                          int priority,
                          bool drop_if_missed,
                          F&& f) {
        enqueue_impl(deadline, priority, drop_if_missed, std::forward<F>(f));
    }

    ~ThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mtx);
            stop = true;
        }
        cv.notify_all();
        for (auto &t : threads) if (t.joinable()) t.join();
    }

private:
    struct Task {
        std::chrono::high_resolution_clock::time_point deadline;  // Changed from steady_clock
        int priority;
        std::size_t seq;
        std::function<void()> func;
        bool drop_if_missed;
    };

    struct Cmp {
        bool operator()(Task const& a, Task const& b) const {
            // earlier deadline should come first
            if (a.deadline != b.deadline) return a.deadline > b.deadline;
            // higher priority should come first
            if (a.priority != b.priority) return a.priority < b.priority;
            // preserve FIFO for equal deadline+priority
            return a.seq > b.seq;
        }
    };

    template <class F>
    void enqueue_impl(std::chrono::high_resolution_clock::time_point deadline,  // Changed from steady_clock
                      int priority,
                      bool drop_if_missed,
                      F&& f) {
        std::function<void()> fn(std::forward<F>(f));
        {
            std::lock_guard<std::mutex> lock(mtx);
            pq.push(Task{deadline, priority, seq++, std::move(fn), drop_if_missed});
        }
        cv.notify_one();
    }

    std::vector<std::thread> threads;
    std::priority_queue<Task, std::vector<Task>, Cmp> pq;
    std::mutex mtx;
    std::condition_variable cv;
    bool stop;
    std::atomic<std::size_t> seq;
};

std::vector<std::string> availableCanInterfaces;
std::mutex canInterfacesMutex;

// helper function to discover CAN interfaces
std::vector<std::string> discoverCanInterfaces() {
    std::vector<std::string> interfaces;
    std::string netPath = "/sys/class/net";
    
    try {
        for (const auto& entry : std::filesystem::directory_iterator(netPath)) {
            if (entry.is_directory()) {
                std::string ifaceName = entry.path().filename().string();
                // Check if it's a CAN device by looking for can_bittiming
                std::string canPath = entry.path().string() + "/can_bittiming";
                if (std::filesystem::exists(canPath)) {
                    interfaces.push_back(ifaceName);
                    logEvent(DEBUG, "Discovered CAN interface: " + ifaceName);
                }
            }
        }
    } catch (const std::exception& e) {
        logEvent(ERROR, "Error discovering CAN interfaces: " + std::string(e.what()));
    }
    
    return interfaces;
}

// Add helper function to validate CAN interface
bool isValidCanInterface(const std::string& interface) {
    std::lock_guard<std::mutex> lock(canInterfacesMutex);
    return std::find(availableCanInterfaces.begin(), 
                     availableCanInterfaces.end(), 
                     interface) != availableCanInterfaces.end();
}

int main(int argc, char* argv[]) {
    int sockfd, new_fd;
    struct addrinfo hints, *servinfo, *p;
    struct sockaddr_storage their_addr;
    socklen_t sin_size;
    struct sigaction sa;
    int yes = 1;
    char s[INET6_ADDRSTRLEN];
    int rv;
 

    std::memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    if (argc != 2) {
        std::cerr << std::format("Error: incorrect number of arguments. Usage: {} <config_file>\n", *argv);
        logEvent(DEBUG, "server <config_file> has incorrect number of arguments");
        return 1;
    }

    std::string configFileName = argv[1];
    std::optional<std::string> port;

    std::filesystem::path configFilePath(configFileName);
    if (!std::filesystem::is_regular_file(configFilePath)) {
        std::cerr << std::format("Error opening configuration file: {}\n", configFileName);
        logEvent(ERROR, "Error opening configuration file: " + configFileName);
        return 1;
    }

    std::ifstream configFile(configFileName);
    std::string line;
    while (std::getline(configFile, line)) {
        std::string_view lineView(line);
        if (lineView.substr(0, 5) == "PORT=") {
            std::string portStr = trim(std::string(lineView.substr(5)));
            port = portStr;
            logEvent(DEBUG, "Port set to " + *port);
        } else if (lineView.substr(0, 10) == "LOG_LEVEL=") {
            std::string logLevelStr = trim(std::string(lineView.substr(10)));
            log_level_str = logLevelStr;
            if (logLevelStr == "DEBUG") {
                log_level = DEBUG;
            } else if (logLevelStr == "INFO") {
                log_level = INFO;
            } else if (logLevelStr == "WARNING") {
                log_level = WARNING;
            } else if (logLevelStr == "ERROR") {
                log_level = ERROR;
            } else {
                logEvent(WARNING, "Unknown log level '" + logLevelStr + "', using ERROR");
                log_level = ERROR;
                log_level_str = "ERROR";
            }
            logEvent(DEBUG, "Log level set to " + log_level_str);
        }
    }
    configFile.close();

    if (!port.has_value()) {
        std::cerr << "Port number not found in configuration file!\n";
        logEvent(ERROR, "Port number not found in configuration file!");
        return 1;
    }

    // Convert port string to int
    try {
        ::port = std::stoi(*port);
    } catch (const std::exception& e) {
        std::cerr << "Invalid port number in configuration file!\n";
        logEvent(ERROR, "Invalid port number in configuration file!");
        return 1;
    }

    if ((rv = getaddrinfo(nullptr, std::to_string(::port).c_str(), &hints, &servinfo))!= 0) {
        std::cerr << std::format("getaddrinfo: {}\n", gai_strerror(rv));
        logEvent(ERROR, std::string("getaddrinfo: ") + gai_strerror(rv));
        return 1;
    }

    // Loop through all the results and bind to the first we can
    for (p = servinfo; p!= NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
            std::perror("server: socket");
            logEvent(ERROR, "server: socket");
            continue;
        }

        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
            logEvent(ERROR, "setsockopt");
            throw std::system_error(errno, std::generic_category(), "setsockopt");
        }

        if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            std::perror("server: bind");
            logEvent(ERROR, "server: bind");
            continue;
        }

        break;
    }

    freeaddrinfo(servinfo);

    if (p == NULL) {
        std::cerr << "server: failed to bind\n";
        logEvent(ERROR, "server: failed to bind");
        return 2;
    }

    if (listen(sockfd, BACKLOG) == -1) {
        logEvent(ERROR, "server: listen");
        throw std::system_error(errno, std::generic_category(), "listen");
    }

    sa.sa_handler = sigchld_handler; // Reap all dead processes
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        logEvent(ERROR, "server: sigaction");
        throw std::system_error(errno, std::generic_category(), "sigaction");
    }

    logEvent(INFO, "server: waiting for connections...");
    std::cout << "server: waiting for connections...\n";

    ThreadPool pool(std::max<size_t>(1, std::min<size_t>(2, std::thread::hardware_concurrency()))); // prefer 2 threads, but at least 1

    // Discover available CAN interfaces
    availableCanInterfaces = discoverCanInterfaces();
    if (availableCanInterfaces.empty()) {
        logEvent(WARNING, "No CAN interfaces found on system");
    } else {
        std::string ifaceList;
        for (const auto& iface : availableCanInterfaces) {
            ifaceList += iface + " ";
        }
        logEvent(INFO, "Available CAN interfaces: " + ifaceList);
    }

    while (true) {
        sin_size = sizeof their_addr;
        new_fd = accept(sockfd, (struct sockaddr*)&their_addr, &sin_size);
        if (new_fd == -1) {
            logEvent(ERROR, "server: accept");
            std::perror("accept");
            continue;
        }

        inet_ntop(their_addr.ss_family, get_in_addr((struct sockaddr*)&their_addr), s, sizeof s);
        std::cout << "Connection from: " << s << std::endl;
        /* // todo add this only for potential ssh client. if client is not gui
        if (send (new_fd, "Hello, you are connected to the server!\n", 39, 0) == -1) { 
            logEvent(ERROR, "send");
            std::perror("send");
        }
            */
        logEvent(INFO, "Connection from: " + std::string(s));

        // Create a new thread to handle the client communication
        std::thread clientThread([new_fd, s, &pool]() {
            registry.add(std::this_thread::get_id(), "client handler for " + std::string(s));  // Add to registry
            ThreadInfo info;
            info.id = std::this_thread::get_id();
            info.name = "client handler for " + std::string(s);
            info.status = "running";
            info.start_time = std::chrono::high_resolution_clock::now();  // Changed from steady_clock but might change back
            std::array<char, MAXDATASIZE> buf;
            int numbytes;
            bool niceShutdown = false;
            int priority = 5; //needs to be implemented in the ui
            int canTime; //time in ms between CAN messages sending
            std::string canInterface; //can0, vcan1, etc.
            std::string canIdStr; //CAN ID and data in hex
            std::vector<pid_t> clientPids;  // Track PIDs of spawned processes
            std::unordered_map<std::string, std::shared_ptr<bool>> taskPauses;  // Paused tasks are kept but don't run
            std::unordered_map<std::string, std::shared_ptr<bool>> taskActive;  // Active tasks get rescheduled
            std::unordered_map<std::string, std::string> taskDetails;  // Task details for status
            std::atomic<int> taskCounter{0};  // For unique task IDs
            std::unordered_map<std::string, std::function<void(const std::string& receivedMsg)>> commandMap;

            commandMap["SHUTDOWN"] = [&](const std::string&) {
                logEvent(INFO, "Received SHUTDOWN command from " + std::string(s));
                niceShutdown = true;
            };

            commandMap["KILL_ALL"] = [&](const std::string&) { // kills all processes started by this client. not sure of usefulness yet. doesn't seem to work right
                logEvent(INFO, "Received KILL_ALL command from " + std::string(s));
                for (auto pid : clientPids) {
                    if (kill(pid, SIGTERM) == -1) {
                        logEvent(WARNING, "Failed to kill PID " + std::to_string(pid) + ": " + std::string(strerror(errno)));
                    }
                }
                clientPids.clear();
                send(new_fd, "All processes killed.\n", 48, 0);
            };

            commandMap["LIST_THREADS"] = [&](const std::string&) { //also called UPDATE
                logEvent(INFO, "Received LIST_THREADS command from " + std::string(s));
                send(new_fd, registry.toString().c_str(), registry.toString().size(), 0);
            };

            commandMap["RESTART"] = [&](const std::string&) {
                logEvent(INFO, "Received RESTART command from " + std::string(s));
                send(new_fd, "Server restart not implemented yet.\n", 36, 0);
            };

            commandMap["KILL_THREAD "] = [&](const std::string& msg) { // kills threads but that's not so useful with a pool
                std::string threadIdStr = msg.substr(12);
                try {
                    std::thread::id threadId = std::thread::id(std::stoull(threadIdStr));
                    registry.remove(threadId);
                    logEvent(INFO, "Removed thread " + threadIdStr + " as per request from " + std::string(s));
                    send(new_fd, "Thread removed\n", 16, 0);
                } catch (const std::exception& e) {
                    logEvent(ERROR, "Invalid thread ID in KILL_THREAD command from " + std::string(s));
                    send(new_fd, "Invalid thread ID\n", 18, 0);
                }
            };

            commandMap["SET_LOG_LEVEL "] = [&](const std::string& msg) {
                std::string levelStr = msg.substr(14);
                if (levelStr == "DEBUG") {
                    log_level = DEBUG;
                    log_level_str = "DEBUG";
                } else if (levelStr == "INFO") {
                    log_level = INFO;
                    log_level_str = "INFO";
                } else if (levelStr == "WARNING") {
                    log_level = WARNING;
                    log_level_str = "WARNING";
                } else if (levelStr == "ERROR") {
                    log_level = ERROR;
                    log_level_str = "ERROR";
                } else {
                    logEvent(ERROR, "Invalid log level in SET_LOG_LEVEL command from " + std::string(s));
                    send(new_fd, "Invalid log level\n", 18, 0);
                    return;
                }
                logEvent(INFO, "Log level set to " + log_level_str + " as per request from " + std::string(s));
                send(new_fd, ("Log level set to " + log_level_str + "\n").c_str(), log_level_str.size() + 16, 0);
            };

            commandMap["PAUSE "] = [&](const std::string& msg) {
                std::string taskId = msg.substr(6);
                if (taskPauses.count(taskId)) {
                    *taskPauses[taskId] = true;
                    send(new_fd, ("Paused " + taskId + "\n").c_str(), ("Paused " + taskId + "\n").size(), 0);
                    // maybe send msg and log if already paused
                } else {
                    send(new_fd, "Task not found\n", 15, 0);
                }
            };

            commandMap["RESUME "] = [&](const std::string& msg) {
                std::string taskId = msg.substr(7);
                if (taskPauses.count(taskId)) {
                    *taskPauses[taskId] = false;
                    send(new_fd, ("Resumed " + taskId + "\n").c_str(), ("Resumed " + taskId + "\n").size(), 0);
                    //maybe send msg and log if already running
                } else {
                    send(new_fd, "Task not found\n", 15, 0);
                }
            };

            commandMap["LIST_TASKS"] = [&](const std::string&) {
                std::string response = "Active tasks:\n";
                for (const auto& [id, detail] : taskDetails) {
                    std::string status;
                    if (!*taskActive[id]) {
                        std::lock_guard<std::mutex> lock(globalErrorMutex);
                        if (globalTaskErrors.count(id)) {
                            status = "stopped (error)";
                        } else {
                            status = "stopped";
                        }
                    } else if (*taskPauses[id]) {
                        status = "paused";
                    } else {
                        status = "running";
                    }
                    response += id + ": " + detail + " (" + status + ")\n";
                    
                    // Include error message if available
                    if (!*taskActive[id]) {
                        std::lock_guard<std::mutex> lock(globalErrorMutex);
                        if (globalTaskErrors.count(id)) {
                            response += "  Error: " + globalTaskErrors[id] + "\n";
                        }
                    }
                }
                send(new_fd, response.c_str(), response.size(), 0);
            };

            commandMap["KILL_TASK "] = [&](const std::string& msg) { //AKA STOP
                std::string taskId = msg.substr(10);  // "KILL_TASK " is 10 chars
                if (taskActive.count(taskId)) {
                    *taskActive[taskId] = false;  // Stop rescheduling
                    taskPauses.erase(taskId);
                    taskDetails.erase(taskId);
                    taskActive.erase(taskId);
                    {
                        std::lock_guard<std::mutex> lock(globalErrorMutex);
                        globalTaskErrors.erase(taskId);  // Clean up error message
                    }
                    logEvent(INFO, "Killed task " + taskId + " from " + std::string(s));
                    send(new_fd, ("Task " + taskId + " killed\n").c_str(), ("Task " + taskId + " killed\n").size(), 0);
                } else {
                    send(new_fd, "Task not found\n", 15, 0);
                }
            };

            commandMap["KILL_ALL_TASKS"] = [&](const std::string&) {
                logEvent(INFO, "Received KILL_ALL_TASKS command from " + std::string(s));
                for (auto& [id, active] : taskActive) {
                    *active = false;  // Stop all rescheduling
                }
                taskPauses.clear();
                taskDetails.clear();
                taskActive.clear();
                {
                    std::lock_guard<std::mutex> lock(globalErrorMutex);
                    globalTaskErrors.clear();  // Clean up all error messages
                }
                send(new_fd, "All tasks killed\n", 17, 0);
            };

            commandMap["LIST_CAN_INTERFACES"] = [&](const std::string&) {
                logEvent(INFO, "Received LIST_CAN_INTERFACES command from " + std::string(s));
                std::string response;
                {
                    std::lock_guard<std::mutex> lock(canInterfacesMutex);
                    if (availableCanInterfaces.empty()) {
                        response = "No CAN interfaces available\n";
                    } else {
                        response = "Available CAN interfaces:\n";
                        for (const auto& iface : availableCanInterfaces) {
                            response += "  " + iface + "\n";
                        }
                    }
                }
                send(new_fd, response.c_str(), response.size(), 0);
            };

            commandMap["REFRESH_CAN_INTERFACES"] = [&](const std::string&) {
                logEvent(INFO, "Received REFRESH_CAN_INTERFACES command from " + std::string(s));
                {
                    std::lock_guard<std::mutex> lock(canInterfacesMutex);
                    availableCanInterfaces = discoverCanInterfaces();
                }
                std::string response = "CAN interfaces refreshed. Found " + 
                                      std::to_string(availableCanInterfaces.size()) + 
                                      " interface(s)\n";
                send(new_fd, response.c_str(), response.size(), 0);
            };

            auto setupRecurringCansend = [&](const std::string& cmd, int ct, int priority, ThreadPool& pool, std::vector<pid_t>& clientPids, std::unordered_map<std::string, std::shared_ptr<bool>>& taskPauses, std::unordered_map<std::string, std::shared_ptr<bool>>& taskActive, std::unordered_map<std::string, std::string>& taskDetails, std::atomic<int>& taskCounter) -> std::string {
                std::string taskId = "task_" + std::to_string(taskCounter++);
                auto pauseFlag = std::make_shared<bool>(false);
                auto activeFlag = std::make_shared<bool>(true);
                
                taskPauses[taskId] = pauseFlag;
                taskActive[taskId] = activeFlag;
                taskDetails[taskId] = cmd + " every " + std::to_string(ct) + "ms priority " + std::to_string(priority);
                
                // Capture shared_ptrs directly instead of accessing via maps
                auto recurring = std::make_shared<std::function<void()>>();
                std::string m = cmd; // snapshot the command
                int interval = ct; // snapshot the interval

                auto enqueueRecurring = [&pool, interval, priority, recurring]() {
                    pool.enqueue_deadline(std::chrono::high_resolution_clock::now() + std::chrono::milliseconds(interval),
                                          priority,
                                          false,
                                          [recurring]() {
                                              try {
                                                  (*recurring)();
                                              } catch (...) {
                                                  logEvent(ERROR, "Unhandled exception in recurring cansend task");
                                              }
                                          });
                };

                // Capture the shared_ptrs by value, not by accessing maps
                *recurring = [recurring, m, interval, &pool, priority, &clientPids, taskId, pauseFlag, activeFlag, enqueueRecurring]() mutable {
                    if (!*activeFlag) return;  // Use captured shared_ptr directly
                    
                    if (!*pauseFlag) {  // Use captured shared_ptr directly
                        pid_t pid = fork();
                        if (pid == 0) {
                            execl("/bin/sh", "sh", "-c", m.c_str(), NULL);
                            _exit(1);
                        } else if (pid > 0) {
                            {
                                std::lock_guard<std::mutex> lock(globalPidMutex);
                                globalPidToTaskId[pid] = taskId;
                            }
                            // Note: Don't add to clientPids here as it's accessed from different thread
                        } else {
                            logEvent(ERROR, "fork() failed for task " + taskId + ": " + std::string(strerror(errno)));
                        }
                    }
                    
                    if (*activeFlag) {
                        enqueueRecurring();
                    }
                };

                enqueueRecurring();
                return taskId;
            };

            while (!niceShutdown) {
                // Check for exited child processes and stop tasks on errors
                {
                    int status;
                    pid_t pid;
                    while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
                        std::string taskId;
                        {
                            std::lock_guard<std::mutex> lock(globalPidMutex);
                            auto it = globalPidToTaskId.find(pid);
                            if (it != globalPidToTaskId.end()) {
                                taskId = it->second;
                                globalPidToTaskId.erase(it);
                            }
                        }
                        if (!taskId.empty() && taskActive.count(taskId)) {
                            std::string errorMsg;
                            bool hasError = false;
                            
                            if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
                                int exitCode = WEXITSTATUS(status);
                                errorMsg = "cansend failed with exit code " + std::to_string(exitCode);
                                hasError = true;
                            } else if (WIFSIGNALED(status)) {
                                int signal = WTERMSIG(status);
                                errorMsg = "cansend terminated by signal " + std::to_string(signal);
                                hasError = true;
                            }
                            
                            if (hasError) {
                                // Get task details before cleanup
                                std::string taskDetail = taskDetails[taskId];
                                
                                // Stop the task and clean up
                                *taskActive[taskId] = false;
                                taskPauses.erase(taskId);
                                taskDetails.erase(taskId);
                                taskActive.erase(taskId);
                                
                                // Log the error
                                std::string fullError = "Task " + taskId + " stopped: " + errorMsg + " (" + taskDetail + ")";
                                logEvent(ERROR, fullError);
                                
                                // Send notification to client
                                std::string notification = "ERROR: Task " + taskId + " stopped - " + errorMsg + "\n";
                                ssize_t sent = send(new_fd, notification.c_str(), notification.size(), MSG_NOSIGNAL);
                                if (sent == -1) {
                                    logEvent(WARNING, "Failed to send error notification to client: " + std::string(strerror(errno)));
                                }
                            }
                        }
                    }
                }

                if ((numbytes = recv(new_fd, buf.data(), MAXDATASIZE - 1, 0)) == -1) {
                    logEvent(ERROR, "recv");
                    perror("recv");
                    exit(1);
                } else if (numbytes == 0) {
                    logEvent(INFO, "Client disconnected: " + std::string(s));
                    break;
                }

                buf[numbytes] = '\0';
                std::string receivedMsg(buf.data(), static_cast<size_t>(numbytes));
                logEvent(DEBUG, "Received from " + std::string(s) + ": " + receivedMsg);

                bool handled = false;
                for (const auto& pair : commandMap) {
                    if (receivedMsg.rfind(pair.first, 0) == 0) {
                        pair.second(receivedMsg);
                        handled = true;
                        break;
                    }
                }
                if (!handled) {
                    if (receivedMsg.rfind("CANSEND#", 0) == 0) {
                        std::string payload = receivedMsg.substr(8);  // "CANSEND#" is 8 chars
                        payload = trim(payload);

                        // Parse format: CANSEND#ID#PAYLOAD#TIME#BUS
                        std::vector<std::string> parts;
                        std::stringstream ss(payload);
                        std::string part;
                        while (std::getline(ss, part, '#')) {
                            parts.push_back(trim(part));
                        }

                        if (parts.size() < 4) {
                            logEvent(ERROR, "Invalid CANSEND syntax from " + std::string(s));
                            send(new_fd, "ERROR: Invalid CANSEND syntax. Usage: CANSEND#<id>#<payload>#<time_ms>#<bus> [priority 0-9]\n", 93, 0);
                        } else {
                            std::string canId = parts[0];
                            std::string canPayload = parts[1];
                            std::string timeStr = parts[2];
                            std::string canBus = parts[3];

                            // Validate CAN interface
                            if (!isValidCanInterface(canBus)) {
                                std::string errorMsg = "ERROR: CAN interface '" + canBus + 
                                                      "' is not available. Use LIST_CAN_INTERFACES to see available interfaces.\n";
                                logEvent(ERROR, "Invalid CAN interface '" + canBus + "' requested by " + std::string(s));
                                send(new_fd, errorMsg.c_str(), errorMsg.size(), 0);
                                continue;
                            }

                            if (canId.starts_with("0x") || canId.starts_with("0X")) {
                                canId = canId.substr(2);
                            }

                            if (timeStr.ends_with("ms")) {
                                timeStr = timeStr.substr(0, timeStr.size() - 2);
                            }

                            // Optional priority (default to 5)
                            int parsedPriority = priority;
                            if (parts.size() >= 5 && !parts[4].empty()) {
                                std::string priorityStr = trim(parts[4]);
                                if (priorityStr.size() == 1 && priorityStr[0] >= '0' && priorityStr[0] <= '9') {
                                    parsedPriority = priorityStr[0] - '0';
                                }
                            }

                            try {
                                canTime = std::stoi(timeStr);
                                std::string canIdData = canId + "#" + canPayload;
                                logEvent(INFO, "Parsed CANSEND: " + canBus + " " + canIdData + " every " + std::to_string(canTime) + "ms priority " + std::to_string(parsedPriority) + " from " + std::string(s));
                                
                                // Build cansend command
                                std::string cmd = "cansend " + canBus + " " + canIdData;
                                std::string taskId = setupRecurringCansend(cmd, canTime, parsedPriority, pool, clientPids, taskPauses, taskActive, taskDetails, taskCounter);
                                std::string response = "OK: CANSEND scheduled with task ID: " + taskId + "\n";
                                send(new_fd, response.c_str(), response.size(), 0);
                            }
                            catch (...) {
                                logEvent(ERROR, "Invalid CANSEND time from " + std::string(s));
                                send(new_fd, "ERROR: Invalid time value\n", 26, 0);
                            }
                        }
                    } else {
                        logEvent(WARNING, "Unknown command from " + std::string(s) + ": " + receivedMsg);
                        std::string response = "Unknown command: " + receivedMsg;
                        send(new_fd, response.c_str(), response.size(), 0);
                    }
                }
            }

            // Clean up any remaining PIDs on disconnect
            for (auto pid : clientPids) {
                kill(pid, SIGTERM);
                {
                    std::lock_guard<std::mutex> lock(globalPidMutex);
                    globalPidToTaskId.erase(pid);
                }
            }
            clientPids.clear();

            close(new_fd);
            registry.remove(std::this_thread::get_id());  // Remove from registry
        });

        clientThread.detach();
    }

    return 0;
}
